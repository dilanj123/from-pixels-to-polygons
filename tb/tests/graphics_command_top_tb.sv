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

    graphics_command_top dut (.*);

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

    task automatic get_response(input logic [3:0] expected_type,
                                input logic [15:0] expected_tag,
                                input integer words,
                                input logic [31:0] expected_second);
        logic [31:0] got;
        integer i;
        begin
            @(negedge clk_sys); rsp_ready = 1;
            for (i=0; i<words; i=i+1) begin
                do @(posedge clk_sys); while (!rsp_valid);
                got = rsp_data;
                if (i == 0 && got !== {expected_type,12'd0,expected_tag})
                    $fatal(1,"response header got=%08x expected_type=%x tag=%x",got,expected_type,expected_tag);
                if (i == 1 && got !== expected_second)
                    $fatal(1,"response W1 mismatch type=%x got=%08x expected=%08x",expected_type,got,expected_second);
                checks = checks + 1;
                @(negedge clk_sys);
            end
            rsp_ready = 0;
        end
    endtask

    task automatic check_readback(input logic [15:0] tag, input logic [7:0] expected_byte);
        logic [31:0] got;
        logic [31:0] checksum;
        integer i;
        begin
            send_word({4'h5,12'd0,tag});
            @(negedge clk_sys); rsp_ready=1;
            checksum=0;
            for(i=0;i<19206;i=i+1) begin
                do @(posedge clk_sys); while(!rsp_valid);
                got=rsp_data;
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
                @(negedge clk_sys);
            end
            rsp_ready=0;
            checks=checks+1;
        end
    endtask

    task automatic check_counters(input logic [15:0] tag);
        logic [31:0] got;
        integer i;
        begin
            send_word({4'h7,12'd0,tag});
            @(negedge clk_sys); rsp_ready=0;
            wait(rsp_valid);
            if(rsp_data !== {4'hb,12'd0,tag}) $fatal(1,"COUNTERS header mismatch");
            repeat(3) begin
                @(posedge clk_sys);
                if(!rsp_valid || rsp_data !== {4'hb,12'd0,tag}) $fatal(1,"COUNTERS header unstable during stall");
            end
            @(negedge clk_sys); rsp_ready=1;
            for(i=0;i<15;i=i+1) begin
                do @(posedge clk_sys); while(!rsp_valid);
                got=rsp_data;
                if(i==0 && got !== {4'hb,12'd0,tag}) $fatal(1,"COUNTERS W0 changed");
                if(i==1 && got !== 1) $fatal(1,"frames_completed=%0d expected=1",got);
                if(i==9 && got !== 76800) $fatal(1,"clear_cycles=%0d expected=76800",got);
                checks=checks+1;
                @(negedge clk_sys);
            end
            rsp_ready=0;
        end
    endtask

    task automatic check_reference_readback(input logic [15:0] tag);
        logic [31:0] got, expected_word, checksum;
        integer i, pixel;
        begin
            send_word({4'h5,12'd0,tag});
            @(negedge clk_sys); rsp_ready=1;
            checksum=0;
            for(i=0;i<19206;i=i+1) begin
                do @(posedge clk_sys); while(!rsp_valid);
                got=rsp_data;
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
                @(negedge clk_sys);
            end
            rsp_ready=0;
            checks=checks+1;
        end
    endtask

    initial begin
        $readmemh("/tmp/gfx_command_system_vectors/command_words.hex",command_vector);
        $readmemh("/tmp/gfx_command_system_vectors/framebuffer.hex",expected_framebuffer);
        repeat (4) @(posedge clk_sys);
        @(negedge clk_sys); arst = 0;
        repeat (5) @(posedge clk_sys);

        // A partial fixed-length command must not execute or respond.
        send_word({4'h1,12'd0,16'h1001});
        repeat (8) @(posedge clk_sys);
        if (rsp_valid) $fatal(1,"incomplete BEGIN_FRAME produced a response");
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
        @(negedge clk_sys); rsp_ready=0;
        wait (rsp_valid);
        if (rsp_data !== {4'ha,12'd0,16'h1003}) $fatal(1,"STATUS header mismatch %08x",rsp_data);
        repeat (4) begin
            @(posedge clk_sys);
            if (!rsp_valid || rsp_data !== {4'ha,12'd0,16'h1003}) $fatal(1,"stalled STATUS header changed");
        end
        @(negedge clk_sys); rsp_ready=1;
        repeat (3) begin @(posedge clk_sys); @(negedge clk_sys); end
        rsp_ready=0;

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

        // Repeat SOBEL then return to NORMAL through the same command path.
        send_word({4'h1,12'd0,16'h1020});
        send_word(32'h00000035);
        send_word({4'h4,12'd0,16'h1021});
        send_word(32'd1);
        get_response(4'h8,16'h1021,2,32'd0);
        if ({front_id,render_id,spare_id} !== {2'd0,2'd2,2'd1})
            $fatal(1,"second SOBEL role result wrong %0d/%0d/%0d",front_id,render_id,spare_id);
        check_readback(16'h1024,8'h00);

        for(integer w=0;w<20;w=w+1) send_word(command_vector[w]);
        get_response(4'h8,16'h1023,2,32'd0);
        if ({front_id,render_id,spare_id} !== {2'd2,2'd0,2'd1})
            $fatal(1,"final NORMAL role result wrong %0d/%0d/%0d",front_id,render_id,spare_id);
        check_reference_readback(16'h1025);

        // Unknown opcode must return the frozen two-word ERROR packet.
        send_word({4'hf,12'd0,16'h1004});
        get_response(4'h9,16'h1004,2,32'd1);

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

        $display("GRAPHICS COMMAND TOP PASS checks=%0d NORMAL/SOBEL/SOBEL/NORMAL=4 readback_bytes=%0d incomplete_atomic=1",
                 checks,4*76800);
        $finish;
    end
endmodule
