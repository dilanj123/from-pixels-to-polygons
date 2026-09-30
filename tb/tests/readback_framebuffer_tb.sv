`timescale 1ns/1ps
module readback_framebuffer_tb;
    localparam integer PIXELS = 76800;
    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    logic start_valid = 0, start_ready;
    logic [15:0] start_tag = 16'h3141;
    logic [1:0] start_front_id = 2'd2;
    logic fb_rd_en;
    logic [16:0] fb_rd_addr, sys_addr;
    logic [1:0] fb_rd_buffer_id;
    logic [7:0] fb_rd_data, sys_rdata, sys_wdata;
    logic sys_we = 0;
    logic rsp_valid, rsp_ready = 1;
    logic [31:0] rsp_data;
    logic active, complete;
    logic [7:0] expected [0:PIXELS-1];
    logic [31:0] checksum;
    integer i, word_index, reads, mismatches, expected_word;
    logic begin_data_phase = 0;

    readback_engine dut (
        .clk_sys(clk), .rst(rst), .start_valid(start_valid), .start_ready(start_ready),
        .start_tag(start_tag), .start_front_id(start_front_id),
        .fb_rd_en(fb_rd_en), .fb_rd_addr(fb_rd_addr), .fb_rd_buffer_id(fb_rd_buffer_id),
        .fb_rd_data(fb_rd_data), .rsp_valid(rsp_valid), .rsp_ready(rsp_ready),
        .rsp_data(rsp_data), .readback_active(active), .readback_complete(complete)
    );

    // Real production dual-port wrapper.  Its sys_rdata is registered at the
    // rising edge; fb_rd_en is ownership/valid bookkeeping, not a RAM enable.
    framebuffer_dp fb (
        .clk_pix(clk), .pix_addr(17'd0), .pix_rdata(),
        .clk_sys(clk), .sys_addr(fb_rd_addr), .sys_we(sys_we),
        .sys_wdata(sys_wdata), .sys_rdata(sys_rdata)
    );
    assign fb_rd_data = sys_rdata;

    always @(posedge clk) begin
        if (rst) reads = 0;
        else if (fb_rd_en) begin
            if (!begin_data_phase) $fatal(1, "source read issued before BEGIN W2 transfer");
            if (fb_rd_addr !== reads[16:0]) $fatal(1, "production source address expected=%0d actual=%0d", reads, fb_rd_addr);
            if (fb_rd_buffer_id !== 2'd2) $fatal(1, "captured buffer ID changed");
            if (fb_rd_addr >= PIXELS) $fatal(1, "source address out of range");
            reads = reads + 1;
        end
    end

    initial begin
        reads = 0;
        mismatches = 0;
        checksum = 0;
        for (i = 0; i < PIXELS; i = i + 1) begin
            expected[i] = (i * 8'h35 + (i >> 7) * 8'h19 + 8'hc3) & 8'hff;
            // Verification-only initialization; production wrapper has no reset.
            fb.mem[i] = expected[i];
        end
        repeat (3) @(posedge clk);
        @(negedge clk); rst = 0; start_valid = 1;
        @(posedge clk); #1;
        if (!active) $fatal(1, "production framebuffer readback did not start");
        @(negedge clk); start_valid = 0; start_front_id = 0; start_tag = 16'h9999;

        for (word_index = 0; word_index < 19206; word_index = word_index + 1) begin
            if (word_index != 0) @(negedge clk);
            while (!rsp_valid) @(negedge clk);
            case (word_index)
                0: expected_word = {4'hc,12'h000,16'h3141};
                1: expected_word = 19200;
                2: expected_word = {3'b000,8'd1,2'd2,9'd240,10'd320};
                default: begin
                    if (word_index < 19203) begin
                        i = (word_index - 3) * 4;
                        expected_word = {expected[i+3],expected[i+2],expected[i+1],expected[i]};
                        checksum = checksum + expected_word;
                    end else if (word_index == 19203)
                        expected_word = {4'hd,12'h000,16'h3141};
                    else if (word_index == 19204)
                        expected_word = 0;
                    else expected_word = checksum;
                end
            endcase
            if (rsp_data !== expected_word[31:0]) begin
                mismatches = mismatches + 1;
                if (mismatches == 1) $display("production readback mismatch word=%0d exp=%08x got=%08x", word_index, expected_word, rsp_data);
            end
            if (word_index == 2) begin_data_phase = 1;
            @(posedge clk);
        end
        #1;
        if (mismatches || reads != PIXELS || active || !complete)
            $fatal(1, "production readback result mismatch=%0d reads=%0d active=%b complete=%b", mismatches, reads, active, complete);
        $display("READBACK FRAMEBUFFER_DP PASS bytes=%0d mismatches=%0d checksum=%08x", reads, mismatches, checksum);
        $finish;
    end
endmodule
