`timescale 1ns/1ps
module graphics_core_tb;
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
    logic [31:0] checksum;
    logic [1:0] prior_front_pix;
    logic prior_safe;
    string vec_dir, path;

    graphics_core dut (
        .clk_sys(clk_sys), .clk_pix(clk_pix), .arst(arst),
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
        begin
            while (!cmd_ready) @(negedge clk_sys);
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
                if (guard > 200000) $fatal(1,"renderer quiescent timeout");
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
        integer scan_errors, output_addr;
        begin
            active_pixels=0; scan_errors=0;
            while(active_pixels<640*480) begin
                @(negedge clk_pix);
                if(active_video) begin
                    output_addr=(dut.pixel_y/2)*320+(dut.pixel_x/2);
                    if(dut.pixel_x<0 || dut.pixel_x>639 || dut.pixel_y<0 || dut.pixel_y>479 ||
                       red!==exp_r(exp_fb[output_addr][7:0]) ||
                       green!==exp_g(exp_fb[output_addr][7:0]) ||
                       blue!==exp_b(exp_fb[output_addr][7:0])) begin
                        if(scan_errors==0) $display("scan mismatch frame=%0d x/y=%0d/%0d addr=%0d rgb=%h%h%h expected=%h",
                            frame,dut.pixel_x,dut.pixel_y,output_addr,red,green,blue,exp_fb[output_addr]);
                        scan_errors=scan_errors+1;
                    end
                    active_pixels=active_pixels+1;
                end
            end
            if(scan_errors) $fatal(1,"full scanout errors=%0d",scan_errors);
            $display("GFX017 complete scanout frame=%0d active_pixels=%0d mismatches=0",frame,active_pixels);
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
    always @(posedge clk_pix) if(!dut.rst_pix) begin
        if(dut.scan_frame_start && dut.raster_x==-160 && dut.raster_y==-45) safe_count=safe_count+1;
        if(front_pix!=prior_front_pix && !prior_safe && !(dut.scan_frame_start && dut.raster_x==-160 && dut.raster_y==-45))
            switch_count=switch_count+1;
        prior_front_pix<=front_pix;
        prior_safe<=dut.scan_frame_start && dut.raster_x==-160 && dut.raster_y==-45;
    end

    initial begin
        cmd_valid=0; cmd='0; present_valid=0; present_sobel=0; sobel_threshold=8'd128;
        sobel_bypass=0; present_tag=0; rb_start_valid=0; rb_tag=0;
        rb_rsp_ready=0; frame_done_count=0; switch_count=0; active_pixels=0;
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
        for(frame=0;frame<3;frame=frame+1) begin
            path=$sformatf("%s/frame_%0d.cmd",vec_dir,frame); fd=$fopen(path,"r");
            if(!fd) $fatal(1,"cannot open vector command file");
            while(!$feof(fd)) begin
                rc=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
                    values[0],values[1],values[2],values[3],values[4],values[5],values[6],values[7],values[8],
                    values[9],values[10],values[11],values[12],values[13],values[14],values[15],values[16],
                    values[17],values[18],values[19],values[20]);
                if(rc==21) send_vector_command();
            end
            $fclose(fd); wait_quiescent(); compare_render_buffer(render_id);
            if(frame==0) begin
                send_present(16'h7100+frame); wait_frame_done(1,16'h7100+frame);
                readback_front();
                compare_scanout_frame();
            end else if(frame==1) begin
                send_present(16'h7100+frame); wait_frame_done(0,16'h7100+frame);
                path=$sformatf("%s/frame_%0d_fb.hex",vec_dir,frame); $readmemh(path,exp_fb);
                compare_scanout_frame();
            end else begin
                send_present(16'h7100+frame); wait_frame_done(1,16'h7100+frame);
                path=$sformatf("%s/frame_%0d_fb.hex",vec_dir,frame); $readmemh(path,exp_fb);
                compare_scanout_frame();
            end
            if(spare_id!=2 || frame_done_count!=frame+1) $fatal(1,"role/spare or completion count mismatch");
        end
        if(switch_count!=0) $fatal(1,"mid-frame front changes=%0d",switch_count);
        $display("GFX017 NORMAL integration PASS frames=3 frame_done=%0d spare=2 switches_outside_safe=%0d",frame_done_count,switch_count);
        $finish;
    end
endmodule
