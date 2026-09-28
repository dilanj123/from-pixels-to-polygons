`timescale 1ns/1ps
module raster_walk_tb;
    logic clk_sys = 1'b0;
    logic rst = 1'b0;
    logic walk_in_valid;
    logic walk_in_ready;
    gfx_pkg::triangle_setup_result_t walk_in_payload;
    logic covered_valid;
    logic covered_ready;
    logic [8:0] covered_x;
    logic [7:0] covered_y;
    logic busy;
    logic walk_complete;

    integer expected_count;
    integer expected_candidates;
    integer expected_index;
    integer active_cycles;
    integer cycle_index;
    integer stall_cycles;
    integer errors;
    integer case_idx;
    integer expected_x [0:30000];
    integer expected_y [0:30000];

    raster_walk dut (
        .clk_sys(clk_sys), .rst(rst),
        .walk_in_valid(walk_in_valid), .walk_in_ready(walk_in_ready),
        .walk_in_payload(walk_in_payload),
        .covered_valid(covered_valid), .covered_ready(covered_ready),
        .covered_x(covered_x), .covered_y(covered_y),
        .busy(busy), .walk_complete(walk_complete)
    );

    always #5 clk_sys = ~clk_sys;

    `include "raster_walk_vectors.svh"

    task automatic fail(input [1023:0] message);
        begin
            $display("FAIL: %0s", message);
            errors = errors + 1;
        end
    endtask

    task automatic reset_dut;
        begin
            @(negedge clk_sys);
            rst = 1'b1;
            walk_in_valid = 1'b0;
            covered_ready = 1'b0;
            repeat (2) @(posedge clk_sys);
            @(negedge clk_sys);
            rst = 1'b0;
            covered_ready = 1'b1;
        end
    endtask

    task automatic run_case(input integer idx, input integer mode, input integer seed);
        integer previous_x;
        integer previous_y;
        integer was_stalled;
        begin
            reset_dut();
            load_raster_walk_case(idx);
            expected_index = 0;
            active_cycles = 0;
            cycle_index = 0;
            stall_cycles = 0;
            was_stalled = 0;
            walk_in_valid = 1'b1;
            covered_ready = 1'b1;
            @(negedge clk_sys);
            while (!walk_in_ready) @(negedge clk_sys);
            @(posedge clk_sys);
            @(negedge clk_sys);
            walk_in_valid = 1'b0;

            while (1) begin
                cycle_index = cycle_index + 1;
                if (mode == 1) begin
                    covered_ready = (((cycle_index + seed) % 7) != 0);
                end else if (mode == 2 && expected_count > 0 && covered_valid &&
                             covered_x == expected_x[expected_count-1] &&
                             covered_y == expected_y[expected_count-1] &&
                             stall_cycles < 3) begin
                    covered_ready = 1'b0;
                    stall_cycles = stall_cycles + 1;
                end else begin
                    covered_ready = 1'b1;
                end

                if (covered_valid && !covered_ready) begin
                    if (!was_stalled) begin
                        previous_x = covered_x;
                        previous_y = covered_y;
                    end else if (covered_x !== previous_x || covered_y !== previous_y) begin
                        fail("covered payload changed under stall");
                    end
                    was_stalled = 1;
                end else begin
                    was_stalled = 0;
                end

                if (covered_valid && covered_ready) begin
                    if (expected_index >= expected_count) begin
                        fail("unexpected covered transfer");
                    end else if (covered_x !== expected_x[expected_index] ||
                                 covered_y !== expected_y[expected_index]) begin
                        fail("covered coordinate mismatch");
                    end
                    expected_index = expected_index + 1;
                end

                if (busy) active_cycles = active_cycles + 1;
                if (walk_complete) break;
                if (cycle_index > expected_candidates + 100) begin
                    fail("walker did not complete");
                    break;
                end
                @(posedge clk_sys);
                #1;
            end

            if (expected_index != expected_count)
                fail("covered transfer count mismatch");
            if (mode == 0 && active_cycles != expected_candidates)
                fail("unstalled candidate-cycle count mismatch");
            if (mode == 2 && expected_count > 0 && stall_cycles != 3)
                fail("final covered candidate was not stalled");
            if (covered_valid || busy)
                fail("walker not idle after completion");
        end
    endtask

    task automatic reset_mid_walk;
        begin
            reset_dut();
            load_raster_walk_case(0);
            walk_in_valid = 1'b1;
            covered_ready = 1'b1;
            @(posedge clk_sys);
            @(negedge clk_sys);
            walk_in_valid = 1'b0;
            repeat (4) @(posedge clk_sys);
            @(negedge clk_sys);
            rst = 1'b1;
            covered_ready = 1'b0;
            @(posedge clk_sys);
            @(negedge clk_sys);
            rst = 1'b0;
            if (busy || covered_valid || walk_complete)
                fail("reset did not abort active walk");
            load_raster_walk_case(9);
            walk_in_valid = 1'b1;
            covered_ready = 1'b1;
            @(posedge clk_sys);
            @(negedge clk_sys);
            walk_in_valid = 1'b0;
            while (!walk_complete) begin
                @(posedge clk_sys);
                #1;
            end
            if (expected_count !== 0)
                fail("reset restart vector expected zero covered outputs");
        end
    endtask

    initial begin
        walk_in_valid = 1'b0;
        covered_ready = 1'b0;
        errors = 0;
        for (case_idx = 0; case_idx < RASTER_WALK_CASES; case_idx = case_idx + 1)
            run_case(case_idx, 0, 1);
        run_case(2, 1, 7);
        run_case(3, 1, 19);
        run_case(9, 0, 1);
        run_case(10, 2, 1);
        run_case(0, 1, 1);
        run_case(0, 1, 7);
        reset_mid_walk();
        if (errors == 0)
            $display("raster_walk_tb: PASS cases=%0d seed=0x9009", RASTER_WALK_CASES);
        else
            $display("raster_walk_tb: FAIL errors=%0d", errors);
        $finish;
    end
endmodule
