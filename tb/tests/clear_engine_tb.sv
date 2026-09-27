module clear_engine_tb;
    localparam int unsigned PIXELS = gfx_pkg::PIXEL_COUNT;
    localparam int unsigned ADDR_WIDTH = gfx_pkg::FRAMEBUFFER_ADDR_WIDTH;

    logic clk = 0, rst = 1;
    logic start_valid, start_ready;
    logic [7:0] clear_rgb332;
    logic busy, done, fb_we, z_we;
    logic [ADDR_WIDTH-1:0] fb_addr, z_addr;
    logic [7:0] fb_wdata, z_wdata;
    integer checks = 0;
    integer fb_count, z_count, duplicate_count, skipped_count, range_count;
    integer seed = 32'h7007;
    logic [PIXELS-1:0] seen;

    always #5 clk = ~clk;

    clear_engine dut (
        .clk_sys(clk), .rst(rst), .start_valid(start_valid), .start_ready(start_ready),
        .clear_rgb332(clear_rgb332), .busy(busy), .done(done),
        .fb_we(fb_we), .fb_addr(fb_addr), .fb_wdata(fb_wdata),
        .z_we(z_we), .z_addr(z_addr), .z_wdata(z_wdata)
    );

    task automatic reset_dut;
        begin
            rst = 1'b1;
            repeat (2) @(posedge clk);
            #1;
            rst = 1'b0;
            start_valid = 1'b0;
            clear_rgb332 = 8'h00;
        end
    endtask

    task automatic check_idle;
        begin
            @(negedge clk);
            if (busy || done || fb_we || z_we || !start_ready)
                $fatal(1, "idle state invalid busy=%b done=%b fb_we=%b z_we=%b ready=%b",
                    busy, done, fb_we, z_we, start_ready);
            checks = checks + 1;
        end
    endtask

    task automatic run_clear(input logic [7:0] expected_colour);
        begin
            while (!start_ready) @(posedge clk);
            @(negedge clk);
            clear_rgb332 = expected_colour;
            start_valid = 1'b1;
            @(posedge clk);
            #1;
            if (!busy || start_ready) $fatal(1, "start handshake did not enter busy");
            start_valid = 1'b0;
            seen = '0;
            fb_count = 0; z_count = 0; duplicate_count = 0;
            skipped_count = 0; range_count = 0;

            while (fb_count < PIXELS) begin
                @(negedge clk);
                if (!fb_we || !z_we) $fatal(1, "missing parallel write at count %0d", fb_count);
                if (fb_addr !== z_addr) $fatal(1, "address mismatch");
                if (fb_wdata !== expected_colour) $fatal(1, "clear colour changed");
                if (z_wdata !== 8'hFF) $fatal(1, "Z clear changed");
                if (fb_addr >= PIXELS) range_count = range_count + 1;
                if (seen[fb_addr]) duplicate_count = duplicate_count + 1;
                seen[fb_addr] = 1'b1;
                fb_count = fb_count + 1;
                z_count = z_count + 1;
            end
            @(posedge clk);
            #1;
            if (!done || busy || !start_ready || fb_we || z_we)
                $fatal(1, "completion timing invalid done=%b busy=%b ready=%b", done, busy, start_ready);
            if (fb_count !== PIXELS || z_count !== PIXELS || duplicate_count != 0 ||
                range_count != 0 || fb_addr !== PIXELS-1 || z_addr !== PIXELS-1)
                $fatal(1, "clear scoreboard mismatch fb=%0d z=%0d dup=%0d range=%0d last=%0d",
                    fb_count, z_count, duplicate_count, range_count, fb_addr);
            for (integer i = 0; i < PIXELS; i = i + 1)
                if (!seen[i]) skipped_count = skipped_count + 1;
            if (skipped_count != 0) $fatal(1, "skipped addresses=%0d", skipped_count);
            checks = checks + 29;
            @(posedge clk);
            #1;
            if (done || fb_we || z_we) $fatal(1, "done/write pulse lasted too long");
        end
    endtask

    task automatic abort_clear(input integer writes_before_reset);
        begin
            while (!start_ready) @(posedge clk);
            @(negedge clk);
            clear_rgb332 = 8'h5A;
            start_valid = 1'b1;
            @(posedge clk);
            #1;
            start_valid = 1'b0;
            for (integer i = 0; i < writes_before_reset; i = i + 1) begin
                @(negedge clk);
                if (!fb_we || fb_addr !== i) $fatal(1, "abort sequence address mismatch");
            end
            @(negedge clk);
            rst = 1'b1;
            @(posedge clk);
            #1;
            if (busy || done || fb_we || z_we || !start_ready)
                $fatal(1, "reset did not abort clear");
            rst = 1'b0;
            checks = checks + 2;
        end
    endtask

    initial begin
        start_valid = 0;
        clear_rgb332 = 0;
        reset_dut();
        check_idle();

        run_clear(8'h00);
        run_clear(8'hFF);
        run_clear(8'hA5);
        run_clear($urandom(seed));

        abort_clear(1);
        run_clear(8'h3C);
        abort_clear(1234);
        run_clear(8'hC3);
        abort_clear(PIXELS-1);
        run_clear(8'h5E);

        $display("clear_engine_tb: PASS checks=%0d seed=0x%0x", checks, seed);
        $finish;
    end
endmodule
