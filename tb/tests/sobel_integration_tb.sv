`timescale 1ns/1ps
module sobel_integration_tb;
    localparam integer PIXELS = 76800;
    logic clk_sys = 0, clk_pix = 0, arst = 1;
    always #5 clk_sys = ~clk_sys;
    initial begin #2; forever #3 clk_pix = ~clk_pix; end

    logic cmd_valid, cmd_ready, present_valid, present_ready, present_sobel;
    logic [7:0] sobel_threshold;
    logic sobel_bypass, sobel_busy, sobel_error;
    gfx_pkg::decoded_command_t cmd;
    logic [15:0] present_tag, done_tag;
    logic frame_done, rb_start_valid, rb_start_ready;
    logic [15:0] rb_tag;
    logic rb_rsp_valid, rb_rsp_ready, rb_active, rb_complete;
    logic [31:0] rb_rsp_data;
    logic [7:0] red, green, blue;
    logic hsync, vsync, active_video;
    logic [1:0] front_sys, render_id, spare_id, front_pix;
    logic front_valid_sys, front_valid_pix, quiescent, pending;
    gfx_pkg::performance_counters_t perf;
    integer exp_fb [0:PIXELS-1], exp_z [0:PIXELS-1], previous_fb [0:PIXELS-1], values [0:20];
    integer fd, rc, frame, cmd_count, i, addr, errors, accepted, data_words;
    integer frame_done_count, switch_count, active_pixels, first_buf, safe_count;
    integer guard, rb_word, byte_errors, word_errors, exp_word, n;
    logic [7:0] sobel_source [0:PIXELS-1];
    logic [7:0] sobel_expected [0:PIXELS-1];
    integer monitor_sobel, monitor_reads, monitor_inputs, monitor_outputs, monitor_writes;
    integer monitor_in_sof, monitor_out_sof, monitor_in_eol, monitor_out_eol;
    integer expected_read_addr, expected_write_addr, done_before;
    integer cycle_count, sequence_step;
    logic [31:0] checksum;
    logic [1:0] prior_front_pix;
    logic prior_safe;
    string vec_dir, path;

    always @(posedge clk_sys) cycle_count=cycle_count+1;

    task automatic diag(input string waiting_for);
        begin
            $display("MODE_STALL step=%0d wait=%s cycle=%0d cmd_ready=%b renderer_state=%0d quiescent=%b present=%b/%b sobel_busy/error=%b/%b ctrl_state=%0d reader=%b/%b writer=%b/%b counts=%0d/%0d manager_state=%0d pending=%b req_pending=%b req=%b ack_sync=%b roles=%0d/%0d/%0d frame_done=%b tag=%h rb_active=%b",
                sequence_step,waiting_for,cycle_count,cmd_ready,dut.renderer_i.state_q,quiescent,
                present_valid,present_ready,sobel_busy,sobel_error,dut.sobel_control_i.state_q,
                dut.sobel_control_i.reader_busy,dut.sobel_control_i.reader_done,
                dut.sobel_control_i.writer_busy,dut.sobel_control_i.writer_done,
                dut.sobel_control_i.input_count_q,dut.sobel_control_i.output_count_q,
                dut.roles_i.state_q,pending,dut.roles_i.mailbox_i.request_pending_sys,
                dut.roles_i.mailbox_i.request_toggle_sys,dut.roles_i.mailbox_i.acknowledge_sync_sys,
                front_sys,render_id,spare_id,frame_done,done_tag,rb_active);
        end
    endtask

    graphics_core dut (
        .clk_sys(clk_sys), .clk_pix(clk_pix), .arst(arst),
        .fatal_recover(1'b0), .command_fifo_level(11'd0),
        .render_cmd_valid(cmd_valid), .render_cmd_ready(cmd_ready), .render_cmd(cmd),
        .present_valid(present_valid), .present_ready(present_ready), .present_tag(present_tag),
        .present_sobel(present_sobel), .sobel_threshold(sobel_threshold),
        .sobel_bypass(sobel_bypass), .sobel_busy(sobel_busy), .sobel_error(sobel_error),
        .frame_done(frame_done), .frame_done_tag(done_tag),
        .readback_start_valid(rb_start_valid), .readback_start_ready(rb_start_ready),
        .readback_start_tag(rb_tag), .readback_rsp_valid(rb_rsp_valid),
        .readback_rsp_ready(rb_rsp_ready), .readback_rsp_data(rb_rsp_data),
        .readback_active(rb_active), .readback_complete(rb_complete),
        .red(red), .green(green), .blue(blue), .hsync(hsync), .vsync(vsync),
        .active_video(active_video), .front_id_sys(front_sys), .render_id(render_id),
        .spare_id(spare_id), .front_id_pix(front_pix), .front_valid_sys(front_valid_sys),
        .front_valid_pix(front_valid_pix), .renderer_quiescent(quiescent),
        .presentation_pending(pending), .perf_counters(perf)
    );

    function automatic [7:0] exp_r(input [7:0] p); exp_r={p[7:5],p[7:5],p[7:6]}; endfunction
    function automatic [7:0] exp_g(input [7:0] p); exp_g={p[4:2],p[4:2],p[4:3]}; endfunction
    function automatic [7:0] exp_b(input [7:0] p); exp_b={p[1:0],p[1:0],p[1:0],p[1:0]}; endfunction

    task automatic send_vector_command;
        integer ready_guard;
        begin
            ready_guard=0;
            while (!cmd_ready) begin
                @(negedge clk_sys); ready_guard=ready_guard+1;
                if(ready_guard>500000) begin diag("render command ready"); $fatal(1,"render command ready timeout"); end
            end
            @(negedge clk_sys);
            cmd.opcode=values[0][3:0]; cmd.tag=values[1][15:0]; cmd.clear_rgb332=values[2][7:0];
            cmd.v0_x=values[3][12:0]; cmd.v0_y=values[4][12:0];
            cmd.v1_x=values[5][12:0]; cmd.v1_y=values[6][12:0];
            cmd.v2_x=values[7][12:0]; cmd.v2_y=values[8][12:0];
            cmd.r_start=values[9]; cmd.g_start=values[10]; cmd.b_start=values[11]; cmd.z_start=values[12];
            cmd.r_dx=values[13]; cmd.g_dx=values[14]; cmd.b_dx=values[15]; cmd.z_dx=values[16];
            cmd.r_dy=values[17]; cmd.g_dy=values[18]; cmd.b_dy=values[19]; cmd.z_dy=values[20];
            cmd_valid=1;
            @(posedge clk_sys); #1;
            @(negedge clk_sys); cmd_valid=0;
        end
    endtask

    task automatic wait_quiescent;
        begin
            guard=0;
            while (!quiescent) begin
                @(posedge clk_sys); guard=guard+1;
                if (guard > 500000) begin diag("renderer quiescent"); $fatal(1,"renderer quiescent timeout"); end
            end
        end
    endtask

    task automatic compare_render_buffer(input integer expected_render);
        begin
            path=$sformatf("%s/frame_%0d_fb.hex",vec_dir,frame); $readmemh(path,exp_fb);
            path=$sformatf("%s/frame_%0d_z.hex",vec_dir,frame); $readmemh(path,exp_z);
            errors=0;
            for (i=0;i<PIXELS;i=i+1) begin
                case(expected_render)
                    0: if(dut.fb0.mem[i] !== exp_fb[i][7:0]) errors=errors+1;
                    1: if(dut.fb1.mem[i] !== exp_fb[i][7:0]) errors=errors+1;
                    2: if(dut.fb2.mem[i] !== exp_fb[i][7:0]) errors=errors+1;
                endcase
                if(dut.renderer_i.zbuffer_i.mem[i] !== exp_z[i][7:0]) errors=errors+1;
                if(frame==0 && (dut.fb0.mem[i]!==8'h11 || dut.fb2.mem[i]!==8'h33))
                    errors=errors+1;
                if(frame>0) begin
                    if(front_sys==2'd0 && dut.fb0.mem[i]!==previous_fb[i][7:0]) errors=errors+1;
                    if(front_sys==2'd1 && dut.fb1.mem[i]!==previous_fb[i][7:0]) errors=errors+1;
                    if(dut.fb2.mem[i]!==8'h33) errors=errors+1;
                end
            end
            if(errors) $fatal(1,"frame %0d full render compare errors=%0d",frame,errors);
            for(i=0;i<PIXELS;i=i+1) previous_fb[i]=exp_fb[i];
            $display("GFX017 render frame=%0d buffer=%0d pixels=%0d mismatches=0",frame,expected_render,PIXELS);
        end
    endtask

    task automatic send_present(input logic [15:0] tag_value);
        begin
            @(negedge clk_sys); present_tag=tag_value; present_valid=1;
            while(!present_ready) @(negedge clk_sys);
            @(posedge clk_sys); #1;
            @(negedge clk_sys); present_valid=0;
        end
    endtask

    task automatic send_sobel_present(input logic [15:0] tag_value,
                                      input logic [7:0] threshold_value,
                                      input logic bypass_value);
        integer guard_ready;
        begin
            @(negedge clk_sys);
            present_tag=tag_value;
            sobel_threshold=threshold_value;
            sobel_bypass=bypass_value;
            present_sobel=1;
            present_valid=1;
            guard_ready=0;
            while(!present_ready) begin
                @(negedge clk_sys); guard_ready=guard_ready+1;
                if(guard_ready>500000) $fatal(1,"Sobel start-ready timeout quiescent=%b pending=%b busy=%b error=%b",
                    quiescent,pending,sobel_busy,sobel_error);
            end
            @(posedge clk_sys); #1;
            @(negedge clk_sys); present_valid=0; present_sobel=0;
        end
    endtask

    task automatic present_normal(input logic [15:0] tag_value);
        integer old_front, old_render, old_spare, before_done, ready_guard, done_guard;
        begin
            old_front=front_sys; old_render=render_id; old_spare=spare_id;
            before_done=frame_done_count;
            @(negedge clk_sys); present_tag=tag_value; present_sobel=0; present_valid=1;
            ready_guard=0;
            while(!present_ready) begin
                @(negedge clk_sys); ready_guard=ready_guard+1;
                if(ready_guard>500000) begin diag("NORMAL present ready"); $fatal(1,"NORMAL present-ready timeout"); end
            end
            @(posedge clk_sys); #1;
            @(negedge clk_sys); present_valid=0;
            done_guard=0;
            while(frame_done_count==before_done) begin
                @(posedge clk_sys); #1; done_guard=done_guard+1;
                if(done_guard>500000) begin diag("NORMAL FRAME_DONE"); $fatal(1,"NORMAL FRAME_DONE timeout"); end
            end
            if(front_sys!==old_render || front_pix!==old_render || render_id!==old_front ||
               spare_id!==old_spare || done_tag!==tag_value)
                $fatal(1,"NORMAL transition mismatch tag=%h F/R/S=%0d/%0d/%0d",tag_value,front_sys,render_id,spare_id);
            $display("GFX017 NORMAL present tag=%h roles=%0d/%0d/%0d FRAME_DONE=1",tag_value,front_sys,render_id,spare_id);
        end
    endtask

    task automatic begin_empty_render_frame;
        integer guard_ready;
        begin
            guard_ready=0;
            while(!cmd_ready) begin
                @(negedge clk_sys); guard_ready=guard_ready+1;
                if(guard_ready>500000) begin diag("BEGIN_FRAME ready"); $fatal(1,"BEGIN_FRAME ready timeout"); end
            end
            @(negedge clk_sys);
            cmd='0;
            cmd.opcode=gfx_pkg::CMD_BEGIN_FRAME;
            cmd.tag=16'h6b00;
            cmd.clear_rgb332=8'h00;
            cmd_valid=1;
            @(posedge clk_sys); #1;
            @(negedge clk_sys); cmd_valid=0;
            wait_quiescent();
        end
    endtask

    task automatic load_render_source(input integer vector_id);
        integer k;
        begin
            path=$sformatf("%s/sobel_source_%0d.hex", "/tmp/gfx021_vectors", vector_id);
            $readmemh(path, sobel_source);
            for(k=0;k<PIXELS;k=k+1) begin
                case(render_id)
                    0: dut.fb0.mem[k]=sobel_source[k];
                    1: dut.fb1.mem[k]=sobel_source[k];
                    2: dut.fb2.mem[k]=sobel_source[k];
                endcase
            end
        end
    endtask

    task automatic readback_expected_front(input integer vector_id);
        integer word_index, byte_index, expected_word, start_guard, response_guard;
        reg [31:0] expected_sum;
        begin
            $readmemh($sformatf("%s/sobel_expected_%0d.hex", "/tmp/gfx021_vectors", vector_id), sobel_expected);
            @(negedge clk_sys); rb_rsp_ready=0; rb_tag=16'h6a00+vector_id; rb_start_valid=1;
            start_guard=0;
            while(!rb_start_ready) begin
                @(negedge clk_sys); start_guard=start_guard+1;
                if(start_guard>100000) begin diag("readback start ready"); $fatal(1,"readback start-ready timeout"); end
            end
            @(posedge clk_sys); #1;
            @(negedge clk_sys); rb_start_valid=0;
            word_index=0; byte_errors=0; word_errors=0; expected_sum=0;
            while(word_index<19206) begin
                response_guard=0;
                @(negedge clk_sys);
                while(!rb_rsp_valid) begin
                    @(negedge clk_sys); response_guard=response_guard+1;
                    if(response_guard>100000) begin diag("readback response valid"); $fatal(1,"readback response timeout word=%0d",word_index); end
                end
                rb_word=word_index;
                case(word_index)
                    0: expected_word=32'hc0000000 | (16'h6a00+vector_id);
                    1: expected_word=19200;
                    2: expected_word={3'b000,8'd1,front_sys,9'd240,10'd320};
                    default: begin
                        if(word_index<19203) begin
                            n=(word_index-3)*4;
                            expected_word={sobel_expected[n+3],sobel_expected[n+2],sobel_expected[n+1],sobel_expected[n]};
                            expected_sum=expected_sum+expected_word;
                            for(byte_index=0;byte_index<4;byte_index=byte_index+1)
                                if(rb_rsp_data[byte_index*8 +: 8]!==sobel_expected[n+byte_index]) byte_errors=byte_errors+1;
                        end else if(word_index==19203) expected_word=32'hd0000000 | (16'h6a00+vector_id);
                        else if(word_index==19204) expected_word=0;
                        else expected_word=expected_sum;
                    end
                endcase
                if(rb_rsp_data!==expected_word[31:0]) word_errors=word_errors+1;
                rb_rsp_ready=1;
                @(posedge clk_sys); #1; rb_rsp_ready=0; word_index=word_index+1;
            end
            if(byte_errors || word_errors || !rb_complete || rb_active)
                $fatal(1,"Sobel FRONT readback mismatch vector=%0d bytes=%0d words=%0d",vector_id,byte_errors,word_errors);
            $display("GFX021 Sobel readback vector=%0d words=19206 bytes=76800 byte_mismatches=0 word_mismatches=0",vector_id);
        end
    endtask

    task automatic run_sobel_case(input integer vector_id,
                                  input logic [7:0] threshold_value,
                                  input logic bypass_value,
                                  input logic load_memory);
        integer k, old_front, old_render, old_spare, mismatch_count;
        begin
            if(load_memory) begin
                begin_empty_render_frame();
                load_render_source(vector_id);
            end
            $readmemh($sformatf("%s/sobel_expected_%0d.hex", "/tmp/gfx021_vectors", vector_id), sobel_expected);
            old_front=front_sys; old_render=render_id; old_spare=spare_id;
            monitor_reads=0; monitor_inputs=0; monitor_outputs=0; monitor_writes=0;
            monitor_in_sof=0; monitor_out_sof=0; monitor_in_eol=0; monitor_out_eol=0;
            expected_read_addr=0; expected_write_addr=0; monitor_sobel=1;
            done_before=frame_done_count;
            send_sobel_present(16'h7200+vector_id,threshold_value,bypass_value);
            guard=0;
            while(frame_done_count==done_before) begin
                @(posedge clk_sys); #1; guard=guard+1;
                if(sobel_error) $fatal(1,"Sobel controller error vector=%0d",vector_id);
                if(guard>500000) begin diag("Sobel FRAME_DONE"); $fatal(1,"Sobel frame timeout vector=%0d",vector_id); end
            end
            monitor_sobel=0;
            if(monitor_reads!=PIXELS || monitor_inputs!=PIXELS || monitor_outputs!=PIXELS || monitor_writes!=PIXELS ||
               monitor_in_sof!=1 || monitor_out_sof!=1 || monitor_in_eol!=240 || monitor_out_eol!=240 ||
               expected_read_addr!=PIXELS || expected_write_addr!=PIXELS)
                $fatal(1,"Sobel transfer scoreboard vector=%0d rd=%0d in=%0d out=%0d wr=%0d sof=%0d/%0d eol=%0d/%0d",
                       vector_id,monitor_reads,monitor_inputs,monitor_outputs,monitor_writes,
                       monitor_in_sof,monitor_out_sof,monitor_in_eol,monitor_out_eol);
            if(front_sys!=old_spare || front_pix!=old_spare || render_id!=old_front || spare_id!=old_render ||
               done_tag!=(16'h7200+vector_id) || !front_valid_sys || sobel_error)
                $fatal(1,"Sobel role/tag transition failed vector=%0d F/R/S=%0d/%0d/%0d",vector_id,front_sys,render_id,spare_id);
            $display("GFX021 Sobel present tag=%h roles=%0d/%0d/%0d FRAME_DONE=1",16'h7200+vector_id,front_sys,render_id,spare_id);
            mismatch_count=0;
            for(k=0;k<PIXELS;k=k+1) begin
                case(old_spare)
                    0: if(dut.fb0.mem[k]!==sobel_expected[k]) mismatch_count=mismatch_count+1;
                    1: if(dut.fb1.mem[k]!==sobel_expected[k]) mismatch_count=mismatch_count+1;
                    2: if(dut.fb2.mem[k]!==sobel_expected[k]) mismatch_count=mismatch_count+1;
                endcase
            end
            if(mismatch_count) $fatal(1,"Sobel framebuffer first full compare vector=%0d mismatches=%0d",vector_id,mismatch_count);
            repeat(12) @(posedge clk_sys);
            readback_expected_front(vector_id);
            $display("GFX021 Sobel frame=%0d input=%0d output=%0d writes=%0d ref_mismatches=0 readback=76800",
                     vector_id,monitor_inputs,monitor_outputs,monitor_writes);
        end
    endtask

    task automatic render_vector(input integer vector_id);
        integer k, mismatch_count;
        begin
            path=$sformatf("%s/frame_%0d.cmd",vec_dir,vector_id); fd=$fopen(path,"r");
            if(!fd) $fatal(1,"cannot open renderer vector %0d",vector_id);
            while(!$feof(fd)) begin
                rc=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
                    values[0],values[1],values[2],values[3],values[4],values[5],values[6],values[7],values[8],
                    values[9],values[10],values[11],values[12],values[13],values[14],values[15],values[16],
                    values[17],values[18],values[19],values[20]);
                if(rc==21) send_vector_command();
            end
            $fclose(fd); wait_quiescent();
            $readmemh($sformatf("%s/frame_%0d_fb.hex",vec_dir,vector_id),exp_fb);
            $readmemh($sformatf("%s/frame_%0d_z.hex",vec_dir,vector_id),exp_z);
            mismatch_count=0;
            for(k=0;k<PIXELS;k=k+1) begin
                case(render_id)
                    0: if(dut.fb0.mem[k]!==exp_fb[k][7:0]) mismatch_count=mismatch_count+1;
                    1: if(dut.fb1.mem[k]!==exp_fb[k][7:0]) mismatch_count=mismatch_count+1;
                    2: if(dut.fb2.mem[k]!==exp_fb[k][7:0]) mismatch_count=mismatch_count+1;
                endcase
                if(dut.renderer_i.zbuffer_i.mem[k]!==exp_z[k][7:0]) mismatch_count=mismatch_count+1;
            end
            if(mismatch_count) $fatal(1,"renderer-produced Sobel source mismatch vector=%0d count=%0d",vector_id,mismatch_count);
        end
    endtask

    task automatic wait_frame_done(input logic [1:0] expect_front, input logic [15:0] tag_value);
        begin
            guard=0;
            while(frame_done_count==frame) begin
                @(posedge clk_sys); #1; guard=guard+1;
                if(guard>500000) $fatal(1,"FRAME_DONE timeout safe_events=%0d req_pending=%b mgr_state=%0d req=%b ack=%b",
                    safe_count,dut.roles_i.mailbox_i.request_pending_sys,dut.roles_i.state_q,
                    dut.roles_i.mailbox_i.request_toggle_sys,dut.roles_i.mailbox_i.acknowledge_sync_sys[1]);
            end
            if(front_sys!=expect_front || front_pix!=expect_front || done_tag!=tag_value)
                $fatal(1,"presentation result frame=%0d front sys/pix=%0d/%0d expected=%0d tag=%h",frame,front_sys,front_pix,expect_front,done_tag);
        end
    endtask

    task automatic compare_scanout_frame;
        integer scan_errors, output_addr, scan_cycles;
        begin
            active_pixels=0; scan_errors=0; scan_cycles=0;
            while(active_pixels<640*480 && scan_cycles<2*800*525) begin
                @(negedge clk_pix);
                scan_cycles=scan_cycles+1;
                if(active_video) begin
                    output_addr=(dut.pixel_y/2)*320+(dut.pixel_x/2);
                    if(dut.pixel_x<0 || dut.pixel_x>639 || dut.pixel_y<0 || dut.pixel_y>479 ||
                       red!==exp_r(exp_fb[output_addr][7:0]) ||
                       green!==exp_g(exp_fb[output_addr][7:0]) ||
                       blue!==exp_b(exp_fb[output_addr][7:0])) begin
                        if(scan_errors==0) $display("scan mismatch step=%0d x/y=%0d/%0d addr=%0d rgb=%h%h%h expected=%h",
                            sequence_step,dut.pixel_x,dut.pixel_y,output_addr,red,green,blue,exp_fb[output_addr]);
                        scan_errors=scan_errors+1;
                    end
                    active_pixels=active_pixels+1;
                end
            end
            if(active_pixels!=640*480) begin diag("complete scanout frame"); $fatal(1,"scanout watchdog active=%0d cycles=%0d",active_pixels,scan_cycles); end
            if(scan_errors) $fatal(1,"full scanout errors=%0d",scan_errors);
            $display("GFX017 complete scanout step=%0d active_pixels=%0d mismatches=0",sequence_step,active_pixels);
        end
    endtask

    task automatic readback_front;
        begin
            path=$sformatf("%s/frame_%0d_fb.hex",vec_dir,frame); $readmemh(path,exp_fb);
            @(negedge clk_sys); rb_tag=16'h5a00+frame; rb_start_valid=1;
            while(!rb_start_ready) @(negedge clk_sys);
            @(posedge clk_sys); #1;
            @(negedge clk_sys); rb_start_valid=0;
            present_tag=16'h7f00; present_valid=1;
            repeat(5) @(posedge clk_sys);
            if(!rb_active || present_ready || dut.rb_buffer_id!==front_sys ||
               front_sys!==1 || render_id!==0)
                $fatal(1,"readback did not lock selected FRONT against presentation");
            @(negedge clk_sys); present_valid=0;
            accepted=0; data_words=0; byte_errors=0; word_errors=0; checksum=0;
            rb_word=0;
            while(rb_word<19206) begin
                @(negedge clk_sys);
                rb_rsp_ready=((rb_word%17)!=4);
                while(!rb_rsp_valid) @(negedge clk_sys);
                if(!rb_rsp_ready) begin
                    exp_word=rb_rsp_data;
                    repeat(3) begin
                        @(negedge clk_sys);
                        if(!rb_rsp_valid || rb_rsp_data!==exp_word[31:0]) $fatal(1,"readback response unstable");
                    end
                    rb_rsp_ready=1;
                end
                case(rb_word)
                    0: exp_word=32'hc0000000 | (16'h5a00+frame);
                    1: exp_word=19200;
                    2: exp_word={3'b0,8'd1,front_sys,9'd240,10'd320};
                    default: begin
                        if(rb_word<19203) begin
                            n=(rb_word-3)*4;
                            exp_word={exp_fb[n+3][7:0],exp_fb[n+2][7:0],exp_fb[n+1][7:0],exp_fb[n][7:0]};
                            checksum=checksum+exp_word[31:0]; data_words=data_words+1;
                            for(integer b=0;b<4;b=b+1)
                                if(rb_rsp_data[b*8 +: 8]!==exp_fb[n+b][7:0]) byte_errors=byte_errors+1;
                        end else if(rb_word==19203) exp_word=32'hd0000000 | (16'h5a00+frame);
                        else if(rb_word==19204) exp_word=0;
                        else exp_word=checksum;
                    end
                endcase
                if(rb_rsp_data!==exp_word[31:0]) begin
                    if(word_errors<4) $display("readback word mismatch idx=%0d exp=%08x act=%08x",rb_word,exp_word[31:0],rb_rsp_data);
                    word_errors=word_errors+1;
                end
                @(posedge clk_sys); #1; accepted=accepted+1; rb_word=rb_word+1;
            end
            if(accepted!=19206 || data_words!=19200 || byte_errors || word_errors || !rb_complete || rb_active)
                $fatal(1,"integrated readback failed words=%0d data=%0d byte=%0d word=%0d",accepted,data_words,byte_errors,word_errors);
            $display("GFX017 FRONT readback frame=%0d bytes=76800 byte_mismatches=0 word_mismatches=0",frame);
        end
    endtask

    always @(posedge clk_sys) if(!arst && frame_done) frame_done_count=frame_done_count+1;
    always @(posedge clk_sys) if(!arst && monitor_sobel) begin
        if(dut.sobel_rd_en) begin
            if(dut.sobel_rd_addr!==expected_read_addr[16:0]) $fatal(1,"Sobel source address mismatch got=%0d exp=%0d",dut.sobel_rd_addr,expected_read_addr);
            expected_read_addr=expected_read_addr+1; monitor_reads=monitor_reads+1;
        end
        if(dut.sobel_control_i.parent_s_valid && dut.sobel_control_i.parent_s_ready) begin
            if(dut.sobel_control_i.parent_s_user) monitor_in_sof=monitor_in_sof+1;
            if(dut.sobel_control_i.parent_s_last) monitor_in_eol=monitor_in_eol+1;
            monitor_inputs=monitor_inputs+1;
        end
        if(dut.sobel_control_i.parent_m_valid && dut.sobel_control_i.parent_m_ready) begin
            if(dut.sobel_control_i.parent_m_user) monitor_out_sof=monitor_out_sof+1;
            if(dut.sobel_control_i.parent_m_last) monitor_out_eol=monitor_out_eol+1;
            monitor_outputs=monitor_outputs+1;
        end
        if(dut.sobel_wr_en) begin
            if(dut.sobel_wr_addr!==expected_write_addr[16:0] || dut.sobel_destination_id==front_sys || dut.sobel_destination_id!=spare_id)
                $fatal(1,"Sobel write ownership/address violation addr=%0d exp=%0d dest=%0d F=%0d S=%0d",
                       dut.sobel_wr_addr,expected_write_addr,dut.sobel_destination_id,front_sys,spare_id);
            expected_write_addr=expected_write_addr+1; monitor_writes=monitor_writes+1;
        end
    end
    always @(posedge clk_pix) if(!dut.rst_pix) begin
        if(dut.scan_frame_start && dut.raster_x==-160 && dut.raster_y==-45) safe_count=safe_count+1;
        if(front_pix!=prior_front_pix && !prior_safe && !(dut.scan_frame_start && dut.raster_x==-160 && dut.raster_y==-45))
            switch_count=switch_count+1;
        prior_front_pix<=front_pix;
        prior_safe<=dut.scan_frame_start && dut.raster_x==-160 && dut.raster_y==-45;
    end

    initial begin
        cycle_count=0; sequence_step=0;
        cmd_valid=0; cmd='0; present_valid=0; present_sobel=0; sobel_threshold=8'd128;
        sobel_bypass=0; present_tag=0; rb_start_valid=0; rb_tag=0;
        rb_rsp_ready=0; frame_done_count=0; switch_count=0; active_pixels=0;
        monitor_sobel=0; monitor_reads=0; monitor_inputs=0; monitor_outputs=0; monitor_writes=0;
        monitor_in_sof=0; monitor_out_sof=0; monitor_in_eol=0; monitor_out_eol=0;
        prior_front_pix=0; prior_safe=0; errors=0; accepted=0; data_words=0; safe_count=0;
        if(!$value$plusargs("VEC_DIR=%s",vec_dir)) vec_dir="/tmp/gfx012_vectors";
        repeat(5) @(posedge clk_sys); arst=0;
        for(i=0;i<PIXELS;i=i+1) begin
            dut.fb0.mem[i]=8'h11;
            dut.fb1.mem[i]=8'h22;
            dut.fb2.mem[i]=8'h33;
        end
        repeat(5) @(posedge clk_sys);
        if(front_sys!=0 || render_id!=1 || spare_id!=2 || front_valid_pix) $fatal(1,"initial role state");
        sequence_step=1;
        render_vector(0);
        present_normal(16'h7100);
        compare_scanout_frame();

        sequence_step=2;
        render_vector(0);
        run_sobel_case(4,8'd96,1'b0,1'b0);

        sequence_step=3;
        run_sobel_case(1,8'd72,1'b0,1'b1);

        sequence_step=4;
        render_vector(0);
        present_normal(16'h7101);
        compare_scanout_frame();
        if(front_sys!==2 || render_id!==0 || spare_id!==1 || frame_done_count!=4)
            $fatal(1,"NORMAL->SOBEL->SOBEL->NORMAL final state F/R/S=%0d/%0d/%0d done=%0d",
                   front_sys,render_id,spare_id,frame_done_count);
        if(switch_count!=0) $fatal(1,"mid-frame front changes=%0d",switch_count);
        $display("GFX021 NORMAL->SOBEL->SOBEL->NORMAL PASS frame_done=%0d safe_switches=%0d",
                 frame_done_count,safe_count);

        sequence_step=5;
        begin_empty_render_frame();
        load_render_source(0);
        monitor_reads=0; monitor_inputs=0; monitor_outputs=0; monitor_writes=0;
        monitor_in_sof=0; monitor_out_sof=0; monitor_in_eol=0; monitor_out_eol=0;
        expected_read_addr=0; expected_write_addr=0;
        done_before=frame_done_count;
        monitor_sobel=1;
        send_sobel_present(16'h72f0,8'd128,1'b0);
        guard=0;
        while(monitor_reads<10) begin
            @(posedge clk_sys); #1; guard=guard+1;
            if(guard>1000) $fatal(1,"reset test did not enter Sobel reads");
        end
        arst=1;
        repeat(4) @(posedge clk_sys);
        arst=0; monitor_sobel=0;
        repeat(12) @(posedge clk_sys);
        if(front_sys!=0 || render_id!=1 || spare_id!=2 || front_valid_sys ||
           sobel_busy || frame_done_count!=done_before)
            $fatal(1,"reset during Sobel left stale state or completion");
        $display("GFX021 active reset abort PASS source_reads=%0d no_FRAME_DONE=1",monitor_reads);
        $finish;
    end
endmodule
