module cmd_fifo_formal;
    (* gclk *) logic clk;
    logic rst, in_valid, in_ready, out_valid, out_ready;
    logic [31:0] in_data, out_data;
    logic [2:0] level;
    logic past_valid;

    // The formal harness uses depth 4 to keep the symbolic memory tractable.
    // The production default remains DEPTH=1024 and LEVEL_WIDTH=11.
    cmd_fifo #(.DEPTH(4), .PTR_WIDTH(2), .LEVEL_WIDTH(3)) dut (
        .clk_sys(clk), .rst(rst), .in_valid(in_valid), .in_ready(in_ready),
        .in_data(in_data), .out_valid(out_valid), .out_ready(out_ready),
        .out_data(out_data), .level(level)
    );

    initial begin
        past_valid = 1'b0;
        assume (rst);
    end

    always_ff @(posedge clk) begin
        if (!past_valid)
            past_valid <= 1'b1;
        else
            assume (!rst);
        if (rst) begin
            assert (level == 0);
            assert (!out_valid);
        end
        if (past_valid && !$past(rst)) begin
            assert (level <= 4);
            assert (level == $past(level) +
                (($past(in_valid && in_ready) ? 1 : 0) -
                 ($past(out_valid && out_ready) ? 1 : 0)));
        end
        if (out_valid && !out_ready && past_valid && $past(out_valid && !out_ready))
            assert (out_data == $past(out_data));
        if (level == 4)
            assert (in_ready == out_ready);
        if (level == 0)
            assert (!out_valid);
        if (past_valid && !$past(rst) && $past(in_valid && in_ready) &&
            !$past(out_valid && out_ready) && $past(level == 0))
            assert (out_valid && out_data == $past(in_data));
        assert (level <= 1024);
        cover (level == 4);
    end
endmodule
