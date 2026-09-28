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
    logic signed [41:0] covered_r_raw;
    logic signed [41:0] covered_g_raw;
    logic signed [41:0] covered_b_raw;
    logic signed [41:0] covered_z_raw;
    logic busy;
    logic walk_complete;

    integer expected_count;
    integer expected_candidates;
    integer expected_index;
    integer active_cycles;
    integer cycle_index;
    integer stall_cycles;
    integer errors;
    integer coordinate_mismatches;
    integer r_mismatches;
    integer g_mismatches;
    integer b_mismatches;
    integer z_mismatches;
    integer raw_fields_compared;
    integer case_idx;
    integer expected_x [0:30000];
    integer expected_y [0:30000];
    logic signed [41:0] expected_r [0:30000];
    logic signed [41:0] expected_g [0:30000];
    logic signed [41:0] expected_b [0:30000];
    logic signed [41:0] expected_z [0:30000];
    integer shared_a_count;
    integer shared_b_count;
    integer shared_a_x [0:500];
    integer shared_a_y [0:500];
    integer shared_b_x [0:500];
    integer shared_b_y [0:500];
    integer shared_i;
    integer shared_j;
    integer shared_overlap;
    integer shared_missing;
    integer shared_found_a;
    integer shared_found_b;

    raster_walk dut (
        .clk_sys(clk_sys), .rst(rst),
        .walk_in_valid(walk_in_valid), .walk_in_ready(walk_in_ready),
        .walk_in_payload(walk_in_payload),
        .covered_valid(covered_valid), .covered_ready(covered_ready),
        .covered_x(covered_x), .covered_y(covered_y),
        .covered_r_raw(covered_r_raw), .covered_g_raw(covered_g_raw),
        .covered_b_raw(covered_b_raw), .covered_z_raw(covered_z_raw),
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
                        coordinate_mismatches = coordinate_mismatches + 1;
                    end
                    if (covered_r_raw !== expected_r[expected_index]) begin
                        fail("R raw attribute mismatch");
                        r_mismatches = r_mismatches + 1;
                    end
                    if (covered_g_raw !== expected_g[expected_index]) begin
                        fail("G raw attribute mismatch");
                        g_mismatches = g_mismatches + 1;
                    end
                    if (covered_b_raw !== expected_b[expected_index]) begin
                        fail("B raw attribute mismatch");
                        b_mismatches = b_mismatches + 1;
                    end
                    if (covered_z_raw !== expected_z[expected_index]) begin
                        fail("Z raw attribute mismatch");
                        z_mismatches = z_mismatches + 1;
                    end
                    raw_fields_compared = raw_fields_compared + 4;
                    if (idx == 11) begin
                        shared_a_x[expected_index] = covered_x;
                        shared_a_y[expected_index] = covered_y;
                    end
                    if (idx == 12) begin
                        shared_b_x[expected_index] = covered_x;
                        shared_b_y[expected_index] = covered_y;
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
            if (idx == 11) shared_a_count = expected_index;
            if (idx == 12) shared_b_count = expected_index;
            if (mode == 0 && active_cycles != expected_candidates)
                fail("unstalled candidate-cycle count mismatch");
            if (mode == 2 && expected_count > 0 && stall_cycles != 3)
                fail("final covered candidate was not stalled");
            if (covered_valid || busy)
                fail("walker not idle after completion");
        end
    endtask

    task automatic check_shared_edge;
        begin
            shared_overlap = 0;
            for (shared_i = 0; shared_i < shared_a_count; shared_i = shared_i + 1)
                for (shared_j = 0; shared_j < shared_b_count; shared_j = shared_j + 1)
                    if (shared_a_x[shared_i] == shared_b_x[shared_j] &&
                        shared_a_y[shared_i] == shared_b_y[shared_j])
                        shared_overlap = shared_overlap + 1;
            shared_missing = 0;
            for (shared_i = 8; shared_i <= 19; shared_i = shared_i + 1)
                for (shared_j = 8; shared_j <= 19; shared_j = shared_j + 1) begin
                    shared_found_a = 0;
                    shared_found_b = 0;
                    for (integer k = 0; k < shared_a_count; k = k + 1)
                        if (shared_a_x[k] == shared_i && shared_a_y[k] == shared_j)
                            shared_found_a = 1;
                    for (integer k = 0; k < shared_b_count; k = k + 1)
                        if (shared_b_x[k] == shared_i && shared_b_y[k] == shared_j)
                            shared_found_b = 1;
                    if (!shared_found_a && !shared_found_b)
                        shared_missing = shared_missing + 1;
                end
            if (shared_overlap != 0) fail("shared-edge overlap detected");
            if (shared_missing != 0) fail("shared-edge rectangle crack detected");
            if (shared_a_count + shared_b_count != 144)
                fail("shared-edge rectangle union count mismatch");
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

    task automatic reset_abort_scenario(input integer scenario);
        integer steps;
        integer width;
        begin
            reset_dut();
            load_raster_walk_case(0);
            walk_in_valid = 1'b1;
            covered_ready = 1'b1;
            @(posedge clk_sys);
            @(negedge clk_sys);
            walk_in_valid = 1'b0;
            steps = 0;
            width = 9;
            while (1) begin
                covered_ready = 1'b1;
                if ((scenario == 0 && steps == 0) ||
                    (scenario == 1 && steps == 4) ||
                    (scenario == 2 && steps == width) ||
                    (scenario == 3 && steps == expected_candidates - 1)) begin
                    rst = 1'b1;
                    break;
                end
                if (scenario == 4 && covered_valid) begin
                    covered_ready = 1'b0;
                    @(posedge clk_sys);
                    @(negedge clk_sys);
                    rst = 1'b1;
                    break;
                end
                @(posedge clk_sys);
                #1;
                steps = steps + 1;
                if (steps > expected_candidates + 2) begin
                    fail("reset scenario did not reach target");
                    rst = 1'b1;
                    break;
                end
                @(negedge clk_sys);
            end
            repeat (2) @(posedge clk_sys);
            @(negedge clk_sys);
            rst = 1'b0;
            covered_ready = 1'b1;
            if (busy || covered_valid || walk_complete)
                fail("reset scenario left stale walker state");
        end
    endtask

    initial begin
        walk_in_valid = 1'b0;
        covered_ready = 1'b0;
        errors = 0;
        coordinate_mismatches = 0;
        r_mismatches = 0;
        g_mismatches = 0;
        b_mismatches = 0;
        z_mismatches = 0;
        raw_fields_compared = 0;
        shared_a_count = 0;
        shared_b_count = 0;
        for (case_idx = 0; case_idx < RASTER_WALK_CASES; case_idx = case_idx + 1)
            run_case(case_idx, 0, 1);
        check_shared_edge();
        run_case(2, 1, 7);
        run_case(3, 1, 19);
        run_case(9, 0, 1);
        run_case(10, 2, 1);
        run_case(0, 1, 1);
        run_case(0, 1, 7);
        reset_mid_walk();
        reset_abort_scenario(0);
        reset_abort_scenario(1);
        reset_abort_scenario(2);
        reset_abort_scenario(3);
        reset_abort_scenario(4);
        if (errors == 0)
            $display("raster_walk_tb: PASS cases=%0d seed=0x9009 candidates=39207 raw_fields=%0d coord_mismatches=%0d R=%0d G=%0d B=%0d Z=%0d", RASTER_WALK_CASES, raw_fields_compared, coordinate_mismatches, r_mismatches, g_mismatches, b_mismatches, z_mismatches);
        else
            $display("raster_walk_tb: FAIL errors=%0d", errors);
        $finish;
    end
endmodule
