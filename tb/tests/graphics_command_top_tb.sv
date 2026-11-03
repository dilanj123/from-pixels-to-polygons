`timescale 1ns/1ps
module graphics_command_top_tb;
    logic clk_sys = 0, clk_pix = 0, arst = 1;
    always #10 clk_sys = ~clk_sys;
    always #5 clk_pix = ~clk_pix;
    logic cmd_valid = 0, cmd_ready;
    logic [31:0] cmd_data = 0;
    logic rsp_valid, rsp_ready = 0;
    logic [31:0] rsp_data;
    logic [31:0] command_vector [0:19];
    logic [7:0] expected_framebuffer [0:76799];
    logic [7:0] red, green, blue;
    logic hsync, vsync, active_video;
    logic [1:0] front_id, render_id, spare_id;
    logic front_valid, command_error;
    integer cycles = 0;
    integer checks = 0;
    integer sobel_write_count = 0;
    integer sobel_writes_at_error = 0;
    logic [31:0] expected_counter [0:13];
    logic [10:0] expected_fifo_peak = 0;
    integer ci;

    graphics_command_top dut (.*);

    // Independent public-testbench event model. It samples command handshakes
    // and renderer/fragment retirement events, never the DUT counter bank.
    always @(posedge clk_sys) begin
        if (dut.graphics_i.sobel_control_i.fb_wr_en) sobel_write_count=sobel_write_count+1;
        if (dut.rst_sys) begin
            for (ci=0;ci<14;ci=ci+1) expected_counter[ci]=0;
            expected_fifo_peak=0;
        end else begin
            if (dut.graphics_i.renderer_i.begin_frame_event) begin
                for (ci=1;ci<13;ci=ci+1) expected_counter[ci]=0;
            end else begin
                if (dut.graphics_i.renderer_i.triangle_submitted_event) expected_counter[1]=expected_counter[1]+1;
                if (dut.graphics_i.renderer_i.triangle_degenerate_event) expected_counter[2]=expected_counter[2]+1;
                if (dut.graphics_i.renderer_i.triangle_backface_event) expected_counter[3]=expected_counter[3]+1;
                if (dut.graphics_i.renderer_i.candidate_retired) expected_counter[4]=expected_counter[4]+1;
                if (dut.graphics_i.renderer_i.covered_fragment_event) expected_counter[5]=expected_counter[5]+1;
                if (dut.graphics_i.renderer_i.depth_result_valid && dut.graphics_i.renderer_i.depth_pass)
                    expected_counter[6]=expected_counter[6]+1;
                if (dut.graphics_i.renderer_i.depth_result_valid && !dut.graphics_i.renderer_i.depth_pass)
                    expected_counter[7]=expected_counter[7]+1;
                if (dut.graphics_i.renderer_i.clear_cycle) expected_counter[8]=expected_counter[8]+1;
                if (dut.graphics_i.renderer_i.render_cycle) expected_counter[9]=expected_counter[9]+1;
                if (dut.graphics_i.renderer_i.triangle_setup_cycle) expected_counter[10]=expected_counter[10]+1;
                if (dut.graphics_i.present_wait_cycle) expected_counter[11]=expected_counter[11]+1;
                if (dut.sobel_busy) expected_counter[12]=expected_counter[12]+1;
            end
            if (dut.frame_done) expected_counter[0]=expected_counter[0]+1;
            if (dut.fifo_level>expected_fifo_peak) expected_fifo_peak=dut.fifo_level;
        end
    end

    always @(posedge clk_sys) begin
        cycles <= cycles + 1;
        if (cycles > 15000000) begin
            $display("graphics_command_top_tb watchdog cycle=%0d state=%0d fifo=%0d decoder_valid=%b cmd_ready=%b rsp_valid=%b front=%0d render=%0d spare=%0d",
                     cycles, dut.state_q, dut.fifo_level, dut.dec_valid, cmd_ready,
                     rsp_valid, front_id, render_id, spare_id);
            $fatal(1, "watchdog");
        end
    end

    task automatic send_word(input logic [31:0] word);
        begin
            @(negedge clk_sys); cmd_data = word; cmd_valid = 1;
            do @(posedge clk_sys); while (!cmd_ready);
            @(negedge clk_sys); cmd_valid = 0;
        end
    endtask

    task automatic send_rejected_triangle(input logic [15:0] tag,
                                           input logic backface);
        logic [31:0] v0, v1, v2;
        integer k;
        begin
            send_word({4'h2,12'd0,tag});
            if(backface) begin
                v0=command_vector[3]; v1=command_vector[5]; v2=command_vector[4];
            end else begin
                v0=0; v1=0; v2=0;
            end
            send_word(v0); send_word(v1); send_word(v2);
            for(k=6;k<18;k=k+1) send_word(backface ? command_vector[k] : 32'd0);
        end
    endtask

    task automatic reset_and_check_idle(input logic [7:0] label_id);
        begin
            @(negedge clk_sys); arst=1;
            repeat(4) @(posedge clk_sys);
            @(negedge clk_sys); arst=0;
            repeat(8) @(posedge clk_sys);
            if(rsp_valid || front_valid || dut.readback_active || dut.sobel_busy ||
               {front_id,render_id,spare_id}!=={2'd0,2'd1,2'd2} ||
               dut.state_q!==dut.ST_IDLE || dut.perf_counters!=='0)
                $fatal(1,"reset matrix case=%0d failed state=%0d roles=%0d/%0d/%0d rsp=%b rb=%b sobel=%b",
                       label_id,dut.state_q,front_id,render_id,spare_id,rsp_valid,
                       dut.readback_active,dut.sobel_busy);
            checks=checks+1;
        end
    endtask

    task automatic get_response(input logic [3:0] expected_type,
                                input logic [15:0] expected_tag,
                                input integer words,
                                input logic [31:0] expected_second);
        logic [31:0] got;
        integer i, wait_cycles;
        begin
            @(negedge clk_sys); rsp_ready = 0;
            for (i=0; i<words; i=i+1) begin
                wait_cycles=0;
                while (!rsp_valid && wait_cycles<1000000) begin
                    @(posedge clk_sys); wait_cycles=wait_cycles+1;
                end
                if (!rsp_valid) $fatal(1,"response timeout type=%x index=%0d",expected_type,i);
                got=rsp_data;
                repeat (2) begin
                    @(posedge clk_sys);
                    if (!rsp_valid || rsp_data !== got)
                        $fatal(1,"response stall unstable type=%x index=%0d got=%08x expected=%08x",
                               expected_type,i,rsp_data,got);
                end
                @(negedge clk_sys); rsp_ready=1;
                @(posedge clk_sys);
                if (!rsp_valid || rsp_data !== got)
                    $fatal(1,"response transfer changed type=%x index=%0d",expected_type,i);
                if (i == 0 && got !== {expected_type,12'd0,expected_tag})
                    $fatal(1,"response header got=%08x expected_type=%x tag=%x",got,expected_type,expected_tag);
                if (i == 1 && got !== expected_second)
                    $fatal(1,"response W1 mismatch type=%x got=%08x expected=%08x",expected_type,got,expected_second);
                checks = checks + 1;
                @(negedge clk_sys); rsp_ready=0;
            end
        end
    endtask

    task automatic check_readback(input logic [15:0] tag, input logic [7:0] expected_byte);
        logic [31:0] got;
        logic [31:0] checksum;
        integer i;
        begin
            send_word({4'h5,12'd0,tag});
            @(negedge clk_sys); rsp_ready=0;
            checksum=0;
            for(i=0;i<19206;i=i+1) begin
                while(!rsp_valid) @(posedge clk_sys);
                got=rsp_data;
                if ((i==0)||(i==1)||(i==2)||(i==3)||(i==9603)||(i==19202)||
                    (i==19203)||(i==19204)||(i==19205)) begin
                    rsp_ready=0;
                    repeat(3) begin
                        @(posedge clk_sys);
                        if(!rsp_valid || rsp_data!==got)
                            $fatal(1,"READ_FRONT stalled word unstable index=%0d",i);
                    end
                end
                @(negedge clk_sys); rsp_ready=1;
                @(posedge clk_sys);
                if(!rsp_valid || rsp_data!==got)
                    $fatal(1,"READ_FRONT transfer changed index=%0d",i);
                case(i)
                    0: if(got !== {4'hc,12'd0,tag}) $fatal(1,"READBACK_BEGIN/tag mismatch %08x",got);
                    1: if(got !== 32'd19200) $fatal(1,"READBACK word count %0d",got);
                    2: if(got[20:19] !== front_id) $fatal(1,"READBACK descriptor front mismatch");
                    default: begin
                        if(i>=3 && i<19203) begin
                            if(got !== {4{expected_byte}}) $fatal(1,"readback data index=%0d got=%08x",i-3,got);
                            checksum=checksum+got;
                        end else if(i==19203 && got !== {4'hd,12'd0,tag}) $fatal(1,"READBACK_END/tag mismatch");
                        else if(i==19204 && got !== 0) $fatal(1,"READBACK status not success");
                        else if(i==19205 && got !== checksum) $fatal(1,"READBACK checksum got=%08x expected=%08x",got,checksum);
                    end
                endcase
                @(negedge clk_sys); rsp_ready=0;
            end
            rsp_ready=0;
            checks=checks+1;
        end
    endtask

    task automatic check_counters(input logic [15:0] tag);
        logic [31:0] got;
        logic [31:0] snapshot_expected [0:13];
        logic [10:0] snapshot_fifo_peak;
        integer i, n;
        begin
            send_word({4'h7,12'd0,tag});
            @(negedge clk_sys); rsp_ready=0;
            wait(rsp_valid);
            if(rsp_data !== {4'hb,12'd0,tag}) $fatal(1,"COUNTERS header mismatch");
            repeat(3) begin
                @(posedge clk_sys);
                if(!rsp_valid || rsp_data !== {4'hb,12'd0,tag}) $fatal(1,"COUNTERS header unstable during stall");
            end
            for(n=0;n<14;n=n+1) snapshot_expected[n]=expected_counter[n];
            snapshot_fifo_peak=expected_fifo_peak;
            // Raise live FIFO occupancy while the response snapshot is held.
            // The queued NOPs cannot dispatch until the COUNTERS packet drains.
            if(tag==16'h1028)
                for(n=0;n<64;n=n+1) send_word({4'h0,12'd0,n[15:0]});
            if(tag==16'h1028 && expected_fifo_peak<=snapshot_fifo_peak)
                $fatal(1,"COUNTERS snapshot test did not increase live FIFO watermark snapshot=%0d live=%0d",
                       snapshot_fifo_peak,expected_fifo_peak);
            for(i=0;i<15;i=i+1) begin
                while(!rsp_valid) @(posedge clk_sys);
                got=rsp_data;
                repeat(2) begin
                    @(posedge clk_sys);
                    if(!rsp_valid || rsp_data!==got)
                        $fatal(1,"COUNTERS stall unstable index=%0d got=%08x expected=%08x",i,rsp_data,got);
                end
                @(negedge clk_sys); rsp_ready=1;
                @(posedge clk_sys);
                if(!rsp_valid || rsp_data!==got) $fatal(1,"COUNTERS transfer changed index=%0d",i);
                if(i==0 && got !== {4'hb,12'd0,tag}) $fatal(1,"COUNTERS W0 changed");
                if(i>0 && i<14 && got !== snapshot_expected[i-1])
                    $fatal(1,"COUNTERS W%0d got=%0d expected=%0d",i,got,snapshot_expected[i-1]);
                if(i==14 && got !== {21'd0,snapshot_fifo_peak})
                    $fatal(1,"COUNTERS W14 got=%0d expected_fifo_peak=%0d",got,snapshot_fifo_peak);
                if(i>0) $display("COUNTERS tag=%04x W%0d actual=%0d expected=%0d",
                    tag,i,got,(i==14)?{21'd0,snapshot_fifo_peak}:snapshot_expected[i-1]);
                checks=checks+1;
                @(negedge clk_sys); rsp_ready=0;
            end
        end
    endtask

    task automatic check_reference_readback(input logic [15:0] tag);
        logic [31:0] got, expected_word, checksum;
        integer i, pixel;
        begin
            send_word({4'h5,12'd0,tag});
            @(negedge clk_sys); rsp_ready=0;
            checksum=0;
            for(i=0;i<19206;i=i+1) begin
                do @(posedge clk_sys); while(!rsp_valid);
                got=rsp_data;
                if ((i==0)||(i==1)||(i==2)||(i==3)||(i==9603)||(i==19202)||
                    (i==19203)||(i==19204)||(i==19205)) begin
                    rsp_ready=0;
                    repeat(3) begin
                        @(posedge clk_sys);
                        if(!rsp_valid || rsp_data!==got)
                            $fatal(1,"reference READ_FRONT stalled word unstable index=%0d",i);
                    end
                end
                @(negedge clk_sys); rsp_ready=1;
                @(posedge clk_sys);
                if(!rsp_valid || rsp_data!==got)
                    $fatal(1,"reference READ_FRONT transfer changed index=%0d",i);
                case(i)
                    0: if(got !== {4'hc,12'd0,tag}) $fatal(1,"reference READBACK header mismatch");
                    1: if(got !== 19200) $fatal(1,"reference READBACK length mismatch");
                    2: if(got[20:19] !== front_id) $fatal(1,"reference descriptor ID mismatch");
                    default: begin
                        if(i>=3 && i<19203) begin
                            pixel=(i-3)*4;
                            expected_word={expected_framebuffer[pixel+3],expected_framebuffer[pixel+2],
                                           expected_framebuffer[pixel+1],expected_framebuffer[pixel]};
                            if(got !== expected_word)
                                $fatal(1,"reference framebuffer mismatch byte=%0d got=%08x expected=%08x",
                                       pixel,got,expected_word);
                            checksum=checksum+got;
                        end else if(i==19203 && got !== {4'hd,12'd0,tag}) $fatal(1,"reference END header mismatch");
                        else if(i==19204 && got !== 0) $fatal(1,"reference END status mismatch");
                        else if(i==19205 && got !== checksum) $fatal(1,"reference checksum mismatch");
                    end
                endcase
                @(negedge clk_sys); rsp_ready=0;
            end
            rsp_ready=0;
            checks=checks+1;
        end
    endtask

    initial begin
        integer status_index, status_timeout;
        logic [31:0] status_expected_word;
        $readmemh("/tmp/gfx_command_system_vectors/command_words.hex",command_vector);
        $readmemh("/tmp/gfx_command_system_vectors/framebuffer.hex",expected_framebuffer);
        repeat (4) @(posedge clk_sys);
        @(negedge clk_sys); arst = 0;
        repeat (5) @(posedge clk_sys);

        // A partial fixed-length command must not execute or respond.
        send_word({4'h1,12'd0,16'h1001});
        repeat (8) @(posedge clk_sys);
        if (rsp_valid) $fatal(1,"incomplete BEGIN_FRAME produced a response");
        @(negedge clk_sys); arst=1;
        repeat(4) @(posedge clk_sys);
        @(negedge clk_sys); arst=0;
        repeat(6) @(posedge clk_sys);
        if(rsp_valid || front_valid || {front_id,render_id,spare_id}!=={2'd0,2'd1,2'd2})
            $fatal(1,"reset did not discard incomplete packet and restore initial roles");
        send_word({4'h1,12'd0,16'h1000});
        send_word(32'h0000005a);

        // An IDLE-only diagnostic submitted during FRAME_ACTIVE must be
        // consumed and rejected rather than blocking the queued PRESENT.
        send_word({4'h6,12'd0,16'h1007});
        get_response(4'h9,16'h1007,2,32'd3);

        // Clear runs to completion before the legal NORMAL presentation.
        send_word({4'h4,12'd0,16'h1002});
        send_word(32'd0);
        get_response(4'h8,16'h1002,2,32'd0);
        if ({front_id,render_id,spare_id} !== {2'd1,2'd0,2'd2} || !front_valid)
            $fatal(1,"NORMAL role result wrong %0d/%0d/%0d valid=%b",front_id,render_id,spare_id,front_valid);
        check_readback(16'h1005,8'h5a);

        send_word({4'h6,12'd0,16'h1003});
        // STATUS has a three-word packet. Stall and check each word so this
        // response type gets the same first/middle/final stability coverage.
        @(negedge clk_sys); rsp_ready=0;
        for (status_index=0;status_index<3;status_index=status_index+1) begin
            case (status_index)
                0: status_expected_word={4'ha,12'd0,16'h1003};
                1: status_expected_word=32'h00000022; // front_valid + sticky CMD_ERROR
                2: status_expected_word=32'h00000021; // FRONT=1, RENDER=0, SPARE=2
            endcase
            status_timeout=0;
            while (!rsp_valid && status_timeout<1000) begin @(negedge clk_sys); status_timeout=status_timeout+1; end
            if (status_timeout==1000) $fatal(1,"STATUS timeout at word %0d",status_index);
            if (rsp_data !== status_expected_word)
                $fatal(1,"STATUS word %0d got %08x expected %08x",status_index,rsp_data,status_expected_word);
            repeat (3) begin
                @(posedge clk_sys); #1;
                if (!rsp_valid || rsp_data !== status_expected_word)
                    $fatal(1,"STATUS stalled word %0d changed to %08x",status_index,rsp_data);
            end
            @(negedge clk_sys); rsp_ready=1;
            @(posedge clk_sys); @(negedge clk_sys); rsp_ready=0;
        end

        check_counters(16'h1006);

        // Exercise the complete public command path into the pinned Sobel
        // parent, with a constant source whose expected Sobel image is zero.
        send_word({4'h3,12'd0,16'h1010});
        send_word(32'h00000080);
        send_word({4'h1,12'd0,16'h1011});
        send_word(32'h0000005a);
        send_word({4'h4,12'd0,16'h1012});
        send_word(32'd1);
        get_response(4'h8,16'h1012,2,32'd0);
        if ({front_id,render_id,spare_id} !== {2'd2,2'd1,2'd0})
            $fatal(1,"SOBEL role result wrong %0d/%0d/%0d",front_id,render_id,spare_id);
        check_readback(16'h1013,8'h00);
        check_counters(16'h1015);

        // Repeat SOBEL then return to NORMAL through the same command path.
        send_word({4'h1,12'd0,16'h1020});
        send_word(32'h00000035);
        send_word({4'h4,12'd0,16'h1021});
        send_word(32'd1);
        get_response(4'h8,16'h1021,2,32'd0);
        if ({front_id,render_id,spare_id} !== {2'd0,2'd2,2'd1})
            $fatal(1,"second SOBEL role result wrong %0d/%0d/%0d",front_id,render_id,spare_id);
        check_readback(16'h1024,8'h00);

        send_word(command_vector[0]); send_word(command_vector[1]);
        for(integer draw=0;draw<2;draw=draw+1)
            for(integer w=2;w<18;w=w+1) send_word(command_vector[w]);
        send_rejected_triangle(16'h1026,1'b0);
        send_rejected_triangle(16'h1027,1'b1);
        send_word(command_vector[18]); send_word(command_vector[19]);
        get_response(4'h8,16'h1023,2,32'd0);
        if ({front_id,render_id,spare_id} !== {2'd2,2'd0,2'd1})
            $fatal(1,"final NORMAL role result wrong %0d/%0d/%0d",front_id,render_id,spare_id);
        check_reference_readback(16'h1025);
        check_counters(16'h1028);

        // Unknown opcode must return the frozen two-word ERROR packet.
        send_word({4'hf,12'd0,16'h1004});
        get_response(4'h9,16'h1004,2,32'd1);

        // Inject the documented local Sobel error at the graphics-core
        // boundary. Recovery must wait until the public ERROR packet drains.
        send_word({4'h1,12'd0,16'h1030});
        send_word(32'h00000044);
        send_word({4'h4,12'd0,16'h1031});
        send_word(32'd1);
        begin : inject_sobel_fault
            integer timeout;
            timeout=0;
            while(dut.state_q!=dut.ST_WAIT_PRESENT && timeout<100000) begin
                @(posedge clk_sys); timeout=timeout+1;
            end
            if(timeout==100000) $fatal(1,"Sobel fault setup timeout state=%0d dec_valid=%b opcode=%x present_valid=%b present_ready=%b sobel_busy=%b sobel_error=%b renderer_quiescent=%b cfg_valid=%b",
                dut.state_q,dut.dec_valid,dut.dec_data.opcode,dut.present_valid,dut.present_ready,
                dut.sobel_busy,dut.sobel_error,dut.renderer_quiescent,dut.sobel_config_valid_q);
            force dut.sobel_error=1'b1;
            timeout=0;
            while(!rsp_valid && timeout<100000) begin
                @(posedge clk_sys); timeout=timeout+1;
            end
            if(timeout==100000) $fatal(1,"fatal Sobel ERROR response timeout top_state=%0d sobel_state=%0d busy=%b error=%b writer_error=%b",
                dut.state_q,dut.graphics_i.sobel_control_i.state_q,dut.sobel_busy,dut.sobel_error,
                dut.graphics_i.sobel_control_i.writer_error);
            sobel_writes_at_error=sobel_write_count;
            if(!dut.sobel_error) $fatal(1,"injected Sobel fatal indication did not reach public controller");
            if({front_id,render_id,spare_id}!=={2'd2,2'd0,2'd1} || !front_valid)
                $fatal(1,"failed Sobel changed displayed ownership");
        end
        begin : verify_no_failed_sobel_writes
            get_response(4'h9,16'h1031,2,32'd8);
            release dut.sobel_error;
            repeat(4) @(posedge clk_sys);
            if(sobel_write_count!=sobel_writes_at_error)
                $fatal(1,"Sobel destination write after fatal error before=%0d after=%0d",
                       sobel_writes_at_error,sobel_write_count);
            if(dut.graphics_i.sobel_control_i.state_q!==4'd0)
                $fatal(1,"Sobel controller was not rearmed after ERROR transfer");
        end
        if({front_id,render_id,spare_id}!=={2'd2,2'd0,2'd1} || !front_valid)
            $fatal(1,"fatal Sobel recovery rotated roles");
        send_word({4'h1,12'd0,16'h1032});
        send_word(32'h00000033);
        send_word({4'h4,12'd0,16'h1033});
        send_word(32'd0);
        get_response(4'h8,16'h1033,2,32'd0);
        if({front_id,render_id,spare_id}!=={2'd0,2'd2,2'd1})
            $fatal(1,"post-fatal NORMAL recovery failed");
        send_word({4'h6,12'd0,16'h1034});
        begin : check_fatal_sticky_status
            integer si, wt;
            logic [31:0] sw;
            for(si=0;si<3;si=si+1) begin
                @(negedge clk_sys); rsp_ready=0;
                wt=0;
                while(!rsp_valid && wt<1000) begin @(negedge clk_sys); wt=wt+1; end
                if(wt==1000) $fatal(1,"post-fatal STATUS timeout word=%0d",si);
                sw=rsp_data;
                case(si)
                    0: if(sw!=={4'ha,12'd0,16'h1034}) $fatal(1,"post-fatal STATUS header %08x",sw);
                    1: if(!sw[5] || !sw[1] || !sw[6]) $fatal(1,"CMD_ERROR/front/config flags not sticky after fatal ERROR: %08x",sw);
                    2: if(sw!==32'h00000018) $fatal(1,"post-fatal role status %08x",sw);
                endcase
                repeat(2) begin @(posedge clk_sys); #1;
                    if(!rsp_valid || rsp_data!==sw) $fatal(1,"post-fatal STATUS stall changed word %0d",si);
                end
                @(negedge clk_sys); rsp_ready=1;
                @(posedge clk_sys);
            end
            @(negedge clk_sys); rsp_ready=0;
        end

        // Reset aborts a stalled complete READ_FRONT stream without a stale
        // response or retained role-valid state.
        send_word({4'h5,12'd0,16'h1014});
        @(negedge clk_sys); rsp_ready=0;
        wait(rsp_valid);
        repeat(4) @(posedge clk_sys);
        @(negedge clk_sys); arst=1;
        repeat(4) @(posedge clk_sys);
        @(negedge clk_sys); arst=0;
        repeat(6) @(posedge clk_sys);
        if(rsp_valid || dut.readback_active || front_valid ||
           {front_id,render_id,spare_id} !== {2'd0,2'd1,2'd2})
            $fatal(1,"reset did not abort readback/restore roles");
        checks=checks+1;

        // Reset during active clear, then with a NORMAL request held pending
        // before the display safe event, then during real Sobel processing.
        send_word({4'h1,12'd0,16'h1040}); send_word(32'h00000021);
        repeat(20) @(posedge clk_sys);
        if(!dut.graphics_i.renderer_i.clear_busy) $fatal(1,"reset-clear setup did not enter clear");
        reset_and_check_idle(1);

        send_word({4'h1,12'd0,16'h1041}); send_word(32'h00000022);
        begin : wait_for_clear_idle
            integer timeout;
            timeout=0;
            while(!dut.renderer_quiescent && timeout<100000) begin
                @(posedge clk_sys); timeout=timeout+1;
            end
            if(timeout==100000) $fatal(1,"reset-pending setup clear timeout");
        end
        force dut.graphics_i.roles_i.safe_frame_start=1'b0;
        send_word({4'h4,12'd0,16'h1042}); send_word(32'd0);
        repeat(4) @(posedge clk_sys);
        if(!dut.presentation_pending || dut.frame_done) $fatal(1,"NORMAL pending reset setup failed");
        reset_and_check_idle(2);
        release dut.graphics_i.roles_i.safe_frame_start;

        send_word({4'h3,12'd0,16'h1043}); send_word(32'h00000080);
        send_word({4'h1,12'd0,16'h1044}); send_word(32'h00000033);
        send_word({4'h4,12'd0,16'h1047}); send_word(32'd1);
        begin : wait_for_sobel_busy
            integer timeout;
            timeout=0;
            while(!dut.sobel_busy && timeout<100000) begin
                @(posedge clk_sys); timeout=timeout+1;
            end
            if(timeout==100000) $fatal(1,"reset-Sobel setup did not become busy");
        end
        reset_and_check_idle(3);

        // A new complete command transaction must work after the aborts.
        send_word({4'h1,12'd0,16'h1045}); send_word(32'h00000044);
        send_word({4'h4,12'd0,16'h1046}); send_word(32'd0);
        get_response(4'h8,16'h1046,2,32'd0);
        if({front_id,render_id,spare_id}!=={2'd1,2'd0,2'd2} || !front_valid)
            $fatal(1,"fresh NORMAL frame failed after reset matrix");

        $display("GRAPHICS COMMAND TOP PASS checks=%0d NORMAL/SOBEL/SOBEL/NORMAL=4 readback_bytes=%0d incomplete_atomic=1",
                 checks,4*76800);
        $finish;
    end
endmodule
