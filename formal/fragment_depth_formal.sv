module fragment_depth_formal;
    (* gclk *) logic clk;
    logic rst, frag_valid, frag_ready;
    logic [8:0] frag_x;
    logic [7:0] frag_y, z_rd_data, z_wr_data, fb_wr_data;
    logic signed [41:0] r_raw, g_raw, b_raw, z_raw;
    logic z_rd_en, z_wr_en, fb_wr_en, depth_valid, depth_pass, empty;
    logic [16:0] z_rd_addr, z_wr_addr, fb_wr_addr;

    fragment_z dut (
        .clk_sys(clk), .rst(rst), .frag_valid(frag_valid), .frag_ready(frag_ready),
        .frag_x(frag_x), .frag_y(frag_y), .frag_r_raw(r_raw), .frag_g_raw(g_raw),
        .frag_b_raw(b_raw), .frag_z_raw(z_raw), .z_rd_en(z_rd_en),
        .z_rd_addr(z_rd_addr), .z_rd_data(z_rd_data), .z_wr_en(z_wr_en),
        .z_wr_addr(z_wr_addr), .z_wr_data(z_wr_data), .fb_wr_en(fb_wr_en),
        .fb_wr_addr(fb_wr_addr), .fb_wr_data(fb_wr_data),
        .depth_result_valid(depth_valid), .depth_pass(depth_pass), .pipeline_empty(empty)
    );

    logic past_valid;
    initial begin past_valid=0; assume(rst); end
    always_ff @(posedge clk) begin
        if (!past_valid) begin past_valid<=1; assume(rst); end
        else assume(!rst);
        if (z_wr_en) begin
            assert(fb_wr_en);
            assert(depth_valid && depth_pass);
            assert(z_wr_addr == fb_wr_addr);
        end
        if (fb_wr_en) assert(z_wr_en);
        if (depth_valid && !depth_pass) assert(!z_wr_en && !fb_wr_en);
        if (depth_pass) assert(depth_valid);
        cover(z_wr_en);
    end
endmodule
