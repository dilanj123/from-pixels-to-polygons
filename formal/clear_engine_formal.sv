module clear_engine_formal;
    localparam int unsigned PIXELS = 8;
    localparam int unsigned AW = 4;
    logic clk, rst, start_valid, start_ready, busy, done, fb_we, z_we;
    logic [7:0] clear_rgb332, fb_wdata, z_wdata;
    logic [AW-1:0] fb_addr, z_addr;
    logic past_valid;
    logic [7:0] tracked_colour;

    clear_engine #(.PIXEL_COUNT_PARAM(PIXELS), .ADDR_WIDTH_PARAM(AW)) dut (
        .clk_sys(clk), .rst(rst), .start_valid(start_valid), .start_ready(start_ready),
        .clear_rgb332(clear_rgb332), .busy(busy), .done(done),
        .fb_we(fb_we), .fb_addr(fb_addr), .fb_wdata(fb_wdata),
        .z_we(z_we), .z_addr(z_addr), .z_wdata(z_wdata)
    );

    initial begin
        past_valid = 1'b0;
        assume (rst);
    end

    always_ff @(posedge clk) begin
        if (!past_valid) begin
            past_valid <= 1'b1;
            assume (rst);
        end else begin
            assume (!rst);
        end

        if (rst) begin
            tracked_colour <= '0;
            assert (!busy && !done && start_ready);
            assert (!fb_we && !z_we);
        end else begin
            if (start_valid && start_ready)
                tracked_colour <= clear_rgb332;
            assert (fb_we == busy);
            assert (z_we == busy);
            assert (fb_addr == z_addr);
            assert (fb_addr < PIXELS);
            assert (z_addr < PIXELS);
            if (busy) begin
                assert (z_wdata == 8'hFF);
                assert (fb_wdata == tracked_colour);
            end
            if (past_valid && $past(busy && (fb_addr != PIXELS-1))) begin
                assert (busy);
                assert (fb_addr == $past(fb_addr) + 1'b1);
            end
            if (done) assert ($past(busy && fb_addr == PIXELS-1));
            if (done) assert (!busy && start_ready && !fb_we && !z_we);
        end
    end
endmodule
