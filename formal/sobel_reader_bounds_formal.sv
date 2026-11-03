module sobel_reader_bounds_formal;
    (* gclk *) logic clk;
    logic rst, start_valid, start_ready, busy, done, rd_en, stream_ready;
    logic [16:0] rd_addr;
    logic [7:0] rd_data;
    logic [23:0] stream_data;
    logic stream_valid, stream_user, stream_last;
    logic past_valid;
    logic [16:0] expected_addr;

    sobel_fb_reader dut (
        .clk_sys(clk), .rst(rst), .start_valid(start_valid), .start_ready(start_ready),
        .busy(busy), .done(done), .fb_rd_en(rd_en), .fb_rd_addr(rd_addr),
        .fb_rd_data(rd_data), .m_tdata(stream_data), .m_tvalid(stream_valid),
        .m_tready(stream_ready), .m_tuser(stream_user), .m_tlast(stream_last)
    );

    initial begin past_valid=0; expected_addr=0; assume(rst); end
    always_ff @(posedge clk) begin
        if (!past_valid) begin past_valid<=1; assume(rst); end
        else assume(!rst);
        if (rst) expected_addr <= 0;
        else if (start_valid && start_ready) expected_addr <= 0;
        else if (rd_en) begin
            assert(rd_addr < 17'd76800);
            assert(rd_addr == expected_addr);
            expected_addr <= expected_addr + 1'b1;
        end
    end
endmodule
