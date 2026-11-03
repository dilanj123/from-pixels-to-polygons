`timescale 1ns/1ps
module sobel_modes_tb;
    logic clk_sys=0, clk_pix=0, rst=1;
    always #5 clk_sys=~clk_sys;
    initial begin #2; forever #7 clk_pix=~clk_pix; end

    logic present_valid, present_ready, present_sobel, renderer_quiescent, readback_active;
    logic [15:0] present_tag;
    logic safe_frame_start;
    logic [1:0] front_sys, render_id, spare_id, front_pix;
    logic front_valid_sys, front_valid_pix, pending, frame_done;
    logic [15:0] frame_done_tag;
    integer done_count=0, accepted_count=0, role_errors=0;

    buffer_manager dut (
        .clk_sys(clk_sys), .rst_sys(rst), .present_valid(present_valid),
        .present_ready(present_ready), .present_sobel(present_sobel),
        .present_tag(present_tag), .renderer_quiescent(renderer_quiescent),
        .readback_active(readback_active), .clk_pix(clk_pix), .rst_pix(rst),
        .safe_frame_start(safe_frame_start), .front_id_sys(front_sys),
        .render_id(render_id), .spare_id(spare_id), .front_id_pix(front_pix),
        .front_valid_sys(front_valid_sys), .front_valid_pix(front_valid_pix),
        .presentation_pending(pending), .frame_done(frame_done), .frame_done_tag(frame_done_tag)
    );

    always @(posedge clk_sys) if (!rst) begin
        if (front_sys>2 || render_id>2 || spare_id>2 ||
            front_sys==render_id || front_sys==spare_id || render_id==spare_id)
            role_errors=role_errors+1;
        if (frame_done) begin
            done_count=done_count+1;
            if (frame_done_tag != present_tag) role_errors=role_errors+1;
        end
    end

    task automatic boundary;
        begin
            repeat (3) @(negedge clk_pix);
            safe_frame_start=1;
            @(negedge clk_pix); safe_frame_start=0;
        end
    endtask

    task automatic present(input bit sobel, input logic [15:0] tag,
                           input logic [1:0] ef, input logic [1:0] er, input logic [1:0] es);
        integer old_done, guard;
        logic [1:0] old_front, old_render, old_spare;
        begin
            old_done=done_count;
            old_front=front_sys; old_render=render_id; old_spare=spare_id;
            @(negedge clk_sys); present_sobel=sobel; present_tag=tag; present_valid=1;
            while (!present_ready) @(negedge clk_sys);
            @(posedge clk_sys); accepted_count=accepted_count+1;
            @(negedge clk_sys); present_valid=0;
            repeat (8) @(posedge clk_sys);
            if (front_sys!==old_front || render_id!==old_render || spare_id!==old_spare)
                $fatal(1,"roles changed before safe boundary/ACK");
            boundary();
            guard=0;
            while(done_count==old_done) begin
                @(posedge clk_sys); guard=guard+1;
                if(guard>80) $fatal(1,"presentation timeout");
            end
            if(front_sys!==ef || render_id!==er || spare_id!==es ||
               front_pix!==ef || !front_valid_sys || !front_valid_pix || frame_done_tag!==tag)
                $fatal(1,"bad completed transition mode=%0d got %0d/%0d/%0d expected %0d/%0d/%0d",
                       sobel,front_sys,render_id,spare_id,ef,er,es);
        end
    endtask

    initial begin
        present_valid=0; present_sobel=0; present_tag=0; safe_frame_start=0;
        renderer_quiescent=1; readback_active=0;
        repeat(5) @(posedge clk_sys); rst=0;
        repeat(5) @(posedge clk_sys);
        if(front_sys!=0 || render_id!=1 || spare_id!=2 || front_valid_sys || front_valid_pix)
            $fatal(1,"initial roles incorrect");

        readback_active=1;
        @(negedge clk_sys); present_valid=1; present_sobel=1; present_tag=16'hdead;
        repeat(5) @(posedge clk_sys);
        if(present_ready || pending) $fatal(1,"readback lock did not block presentation");
        @(negedge clk_sys); present_valid=0; readback_active=0;

        present(0,16'h1001,1,0,2); // NORMAL: swap FRONT and RENDER
        present(1,16'h1002,2,1,0); // SOBEL: promote SPARE
        present(1,16'h1003,0,2,1); // SOBEL again
        present(0,16'h1004,2,0,1); // NORMAL again

        if(accepted_count!=4 || done_count!=4 || role_errors!=0)
            $fatal(1,"mode totals accept=%0d done=%0d role_errors=%0d",accepted_count,done_count,role_errors);
        $display("SOBEL MODE TRANSITIONS PASS normal/sobel/sobel/normal=4 readback_lock=1 role_errors=0");
        $finish;
    end
endmodule
