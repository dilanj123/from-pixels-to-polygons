module sobel_writer_bounds_formal;
    (* gclk *) logic clk;
    logic rst, start_valid, start_ready, busy, done, error;
    logic [7:0] data;
    logic valid, ready, user, last, wr_en;
    logic [16:0] wr_addr;
    logic [7:0] wr_data;
    logic past_valid;
    logic [16:0] expected_addr;

    sobel_fb_writer dut (
        .clk_sys(clk), .rst(rst), .start_valid(start_valid), .start_ready(start_ready),
        .busy(busy), .done(done), .error(error), .s_tdata(data), .s_tvalid(valid),
        .s_tready(ready), .s_tuser(user), .s_tlast(last), .fb_wr_en(wr_en),
        .fb_wr_addr(wr_addr), .fb_wr_data(wr_data)
    );

    initial begin past_valid=0; expected_addr=0; assume(rst); end
    always_ff @(posedge clk) begin
        if (!past_valid) begin past_valid<=1; assume(rst); end
        else assume(!rst);
        if (rst) expected_addr <= 0;
        else if (start_valid && start_ready) expected_addr <= 0;
        else if (wr_en) begin
            assert(wr_addr < 17'd76800);
            assert(wr_addr == expected_addr);
            expected_addr <= expected_addr + 1'b1;
        end
        assert(ready == (busy && !error && !rst));
        if (wr_en) assert(valid && ready);
    end
endmodule
