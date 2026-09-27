module cmd_fifo_tb;
    localparam int DEPTH = 1024;
    logic clk = 0, rst = 1, in_valid, in_ready;
    logic [31:0] in_data;
    logic out_valid, out_ready;
    logic [31:0] out_data;
    logic [10:0] level;
    integer seed = 32'h005005, cycle = 0, pushes = 0, pops = 0;
    reg [31:0] expected [0:4095];
    integer head, tail, count;
    always #5 clk = ~clk;
    cmd_fifo dut (
        .clk_sys(clk), .rst(rst), .in_valid(in_valid), .in_ready(in_ready),
        .in_data(in_data), .out_valid(out_valid), .out_ready(out_ready),
        .out_data(out_data), .level(level)
    );

    task automatic check_state;
        begin
            if (level !== count[10:0]) $fatal(1, "level mismatch cycle=%0d", cycle);
            if ((count == 0) && out_valid) $fatal(1, "output valid while empty");
        end
    endtask

    task automatic drive_and_check(input logic iv, input logic [31:0] id, input logic ory);
        logic do_push, do_pop, seen_valid;
        logic [31:0] seen_data;
        begin
            @(negedge clk); in_valid = iv; in_data = id; out_ready = ory;
            seen_valid = out_valid; seen_data = out_data;
            @(posedge clk); #1;
            do_pop = (count != 0) && ory;
            do_push = iv && ((count < DEPTH) || do_pop);
            if (do_pop) begin
                if (!seen_valid || seen_data !== expected[head]) $fatal(1, "data mismatch cycle=%0d got=%h expected=%h count=%0d level=%0d", cycle, seen_data, expected[head], count, level);
                head = (head + 1) % 4096; count = count - 1; pops = pops + 1;
            end
            if (do_push) begin
                expected[tail] = id; tail = (tail + 1) % 4096; count = count + 1; pushes = pushes + 1;
            end
            cycle = cycle + 1; check_state();
        end
    endtask

    initial begin
        in_valid = 0; in_data = 0; out_ready = 0; head = 0; tail = 0; count = 0;
        repeat (3) @(posedge clk); #1; rst = 0; check_state();
        drive_and_check(1, 32'h1111, 0); drive_and_check(0, 0, 0); drive_and_check(0, 0, 1);
        for (integer i = 0; i < DEPTH; i = i + 1) drive_and_check(1, 32'h10000000 + i, 0);
        if (count != DEPTH || in_ready) $fatal(1, "exact-full condition failed");
        drive_and_check(1, 32'hdeadbeef, 0);
        drive_and_check(1, 32'hcafebabe, 1);
        while (count != 0) drive_and_check(0, 0, 1);
        for (integer round = 0; round < 4; round = round + 1) begin
            for (integer i = 0; i < 300; i = i + 1) drive_and_check(1, (round << 20) | i, 0);
            for (integer i = 0; i < 300; i = i + 1) drive_and_check(1, 32'h80000000 | (round << 12) | i, 1);
            while (count > 0) drive_and_check(0, 0, 1);
        end
        for (integer i = 0; i < 5000; i = i + 1) begin
            integer r; r = $urandom(seed);
            drive_and_check((r & 3) != 0, r, (r & 4) != 0);
        end
        while (count > 0) drive_and_check(0, 0, 1);
        $display("cmd_fifo_tb: PASS cycles=%0d pushes=%0d pops=%0d seed=0x%0x", cycle, pushes, pops, seed);
        $finish;
    end
endmodule
