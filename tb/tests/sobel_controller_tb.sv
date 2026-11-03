`timescale 1ns/1ps
module sobel_controller_tb;
    localparam integer PIXELS=76800;
    logic clk=0, rst=1;
    always #5 clk=~clk;
    logic start_valid=0, start_ready, renderer_quiescent=1, readback_active=0;
    logic [15:0] start_tag=0;
    logic [1:0] render_id=1, spare_id=2;
    logic [7:0] threshold=128;
    logic bypass=0, busy, done, error;
    logic [1:0] source_id, destination_id;
    logic fb_rd_en; logic [16:0] fb_rd_addr; logic [7:0] fb_rd_data;
    logic fb_wr_en; logic [16:0] fb_wr_addr; logic [7:0] fb_wr_data;
    logic present_valid, present_ready=1, present_done_event=0, present_sobel;
    logic [15:0] present_tag;
    logic [31:0] parent_frame_count=0;
    logic [7:0] src_mem[0:PIXELS-1], dst_mem[0:PIXELS-1], exp_mem[0:PIXELS-1];
    integer reads=0, writes=0, accepted=0, i, vector_id, fd, rc, guard, mismatches;
    integer expected_addr=0;
    bit done_pending=0;
    string vec_dir, path;

    sobel_controller dut (
        .clk_sys(clk),.rst(rst),.recover(1'b0),.start_valid(start_valid),.start_ready(start_ready),
        .start_tag(start_tag),.render_id(render_id),.spare_id(spare_id),
        .renderer_quiescent(renderer_quiescent),.readback_active(readback_active),
        .cfg_threshold(threshold),.cfg_bypass(bypass),.busy(busy),.done(done),.error(error),
        .source_id(source_id),.destination_id(destination_id),.fb_rd_en(fb_rd_en),
        .fb_rd_addr(fb_rd_addr),.fb_rd_data(fb_rd_data),.fb_wr_en(fb_wr_en),
        .fb_wr_addr(fb_wr_addr),.fb_wr_data(fb_wr_data),.present_valid(present_valid),
        .present_ready(present_ready),.present_done_event(present_done_event),
        .present_sobel(present_sobel),.present_tag(present_tag)
    );

    always @(posedge clk) begin
        if(fb_rd_en && !rst) begin
            if(fb_rd_addr!==reads[16:0]) $fatal(1,"read address %0d expected %0d",fb_rd_addr,reads);
            fb_rd_data<=src_mem[fb_rd_addr]; reads=reads+1;
        end
        if(fb_wr_en && !rst) begin
            if(fb_wr_addr!==expected_addr[16:0]) $fatal(1,"write address %0d expected %0d",fb_wr_addr,expected_addr);
            if(destination_id!=2 || destination_id==source_id) $fatal(1,"bad physical ownership");
            dst_mem[fb_wr_addr]<=fb_wr_data; expected_addr=expected_addr+1; writes=writes+1;
        end
        present_done_event<=0;
        if(present_valid && present_ready && !rst) begin
            if(!present_sobel || present_tag!==start_tag) $fatal(1,"bad presentation metadata");
            done_pending<=1;
        end else if(done_pending && !rst) begin
            present_done_event<=1; done_pending<=0;
        end
        if(present_valid && !present_ready && !rst) $fatal(1,"presentation unexpectedly stalled");
    end

    task automatic run_vector(input integer idx, input integer th, input bit bp);
        begin
            path=$sformatf("%s/sobel_source_%0d.hex",vec_dir,idx); $readmemh(path,src_mem);
            path=$sformatf("%s/sobel_expected_%0d.hex",vec_dir,idx); $readmemh(path,exp_mem);
            for(i=0;i<PIXELS;i=i+1) dst_mem[i]=8'hA5;
            reads=0; writes=0; accepted=0; expected_addr=0;
            threshold=th[7:0]; bypass=bp; start_tag=16'h6a00+idx;
            @(negedge clk); start_valid=1;
            while(!start_ready) @(negedge clk);
            @(posedge clk); #1; @(negedge clk); start_valid=0;
            guard=0;
            while(!done && !error) begin
                @(posedge clk); #1; guard=guard+1;
                if(guard>200000) $fatal(1,"vector %0d timeout",idx);
            end
            if(error || reads!=PIXELS || writes!=PIXELS || expected_addr!=PIXELS ||
               source_id!=1 || destination_id!=2)
                $fatal(1,"vector %0d ctrl failure err=%b reads=%0d writes=%0d",idx,error,reads,writes);
            mismatches=0;
            for(i=0;i<PIXELS;i=i+1) if(dst_mem[i]!==exp_mem[i]) mismatches=mismatches+1;
            if(mismatches) $fatal(1,"vector %0d mismatches=%0d",idx,mismatches);
            accepted=PIXELS;
            $display("SOBEL CTRL vector=%0d threshold=%0d bypass=%0d reads=%0d writes=%0d mismatches=%0d",idx,th,bp,reads,writes,mismatches);
            @(negedge clk);
        end
    endtask

    initial begin
        if(!$value$plusargs("VEC_DIR=%s",vec_dir)) vec_dir="/tmp/gfx021_vectors";
        fb_rd_data=0;
        repeat(5) @(posedge clk); rst=0;
        run_vector(0,128,0);
        run_vector(1,72,0);
        run_vector(2,128,1);
        run_vector(3,210,0);
        run_vector(4,96,0);
        $display("SOBEL CONTROLLER FULL-FRAME REGRESSION PASS frames=5 pixels/frame=76800");
        $finish;
    end
endmodule
