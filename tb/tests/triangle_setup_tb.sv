module triangle_setup_tb;
    import gfx_pkg::*;
    localparam integer VECTORS = 160;
    localparam integer WORDS_PER_VECTOR = 50;
    logic [31:0] vectors [0:VECTORS*WORDS_PER_VECTOR-1];
    logic clk = 0, rst = 1;
    logic in_valid, in_ready, out_valid, out_ready;
    decoded_command_t in_data;
    triangle_setup_result_t out_data, held;
    integer compared = 0;

    always #5 clk = ~clk;

    triangle_setup dut (
        .clk_sys(clk), .rst(rst), .in_valid(in_valid), .in_ready(in_ready),
        .in_data(in_data), .out_valid(out_valid), .out_ready(out_ready), .out_data(out_data)
    );

    task automatic reset_dut;
        begin
            @(negedge clk); rst = 1'b1; in_valid = 1'b0; out_ready = 1'b1;
            repeat (2) @(posedge clk);
            @(negedge clk); rst = 1'b0;
        end
    endtask

    task automatic load_input(input integer base);
        begin
            in_data = '0;
            in_data.tag = vectors[base][15:0];
            in_data.v0_x = vectors[base+1][12:0]; in_data.v0_y = vectors[base+1][25:13];
            in_data.v1_x = vectors[base+2][12:0]; in_data.v1_y = vectors[base+2][25:13];
            in_data.v2_x = vectors[base+3][12:0]; in_data.v2_y = vectors[base+3][25:13];
            in_data.r_start = vectors[base+4]; in_data.g_start = vectors[base+5];
            in_data.b_start = vectors[base+6]; in_data.z_start = vectors[base+7];
            in_data.r_dx = vectors[base+8]; in_data.g_dx = vectors[base+9];
            in_data.b_dx = vectors[base+10]; in_data.z_dx = vectors[base+11];
            in_data.r_dy = vectors[base+12]; in_data.g_dy = vectors[base+13];
            in_data.b_dy = vectors[base+14]; in_data.z_dy = vectors[base+15];
        end
    endtask

    task automatic compare_output(input integer base);
        begin
            if (out_data.classification !== vectors[base+16][1:0]) $fatal(1, "class mismatch vector %0d", base/WORDS_PER_VECTOR);
            if (out_data.tag !== vectors[base][15:0]) $fatal(1, "tag mismatch vector %0d", base/WORDS_PER_VECTOR);
            if (out_data.area !== vectors[base+17]) $fatal(1, "area mismatch vector %0d", base/WORDS_PER_VECTOR);
            if (out_data.edge0_dx !== vectors[base+18][15:0] || out_data.edge0_dy !== vectors[base+19][15:0] ||
                out_data.edge1_dx !== vectors[base+20][15:0] || out_data.edge1_dy !== vectors[base+21][15:0] ||
                out_data.edge2_dx !== vectors[base+22][15:0] || out_data.edge2_dy !== vectors[base+23][15:0]) $fatal(1, "delta mismatch vector %0d", base/WORDS_PER_VECTOR);
            if (out_data.top_left !== vectors[base+24][2:0]) $fatal(1, "top-left mismatch vector %0d", base/WORDS_PER_VECTOR);
            if (out_data.edge0_step_x !== vectors[base+25] || out_data.edge0_step_y !== vectors[base+26] ||
                out_data.edge1_step_x !== vectors[base+27] || out_data.edge1_step_y !== vectors[base+28] ||
                out_data.edge2_step_x !== vectors[base+29] || out_data.edge2_step_y !== vectors[base+30]) $fatal(1, "step mismatch vector %0d", base/WORDS_PER_VECTOR);
            if (out_data.xmin !== vectors[base+31][8:0] || out_data.xmax !== vectors[base+32][8:0] ||
                out_data.ymin !== vectors[base+33][7:0] || out_data.ymax !== vectors[base+34][7:0]) $fatal(1, "bbox mismatch vector %0d", base/WORDS_PER_VECTOR);
            if (out_data.e0_init !== vectors[base+35] || out_data.e1_init !== vectors[base+36] || out_data.e2_init !== vectors[base+37]) $fatal(1, "initial edge mismatch vector %0d", base/WORDS_PER_VECTOR);
            if (out_data.r_start !== vectors[base+38] || out_data.g_start !== vectors[base+39] ||
                out_data.b_start !== vectors[base+40] || out_data.z_start !== vectors[base+41] ||
                out_data.r_dx !== vectors[base+42] || out_data.g_dx !== vectors[base+43] ||
                out_data.b_dx !== vectors[base+44] || out_data.z_dx !== vectors[base+45] ||
                out_data.r_dy !== vectors[base+46] || out_data.g_dy !== vectors[base+47] ||
                out_data.b_dy !== vectors[base+48] || out_data.z_dy !== vectors[base+49]) $fatal(1, "attribute mismatch vector %0d", base/WORDS_PER_VECTOR);
            compared = compared + 34;
        end
    endtask

    task automatic send_and_check(input integer index);
        integer base, cycles;
        begin
            base = index * WORDS_PER_VECTOR;
            cycles = 0;
            while (!in_ready && cycles < 8) begin @(negedge clk); cycles = cycles + 1; end
            if (!in_ready) $fatal(1, "input-ready timeout vector %0d", index);
            @(negedge clk); load_input(base); in_valid = 1'b1;
            @(posedge clk); #1;
            if (out_valid) $fatal(1, "output asserted before third stage vector %0d", index);
            @(negedge clk); in_valid = 1'b0;
            cycles = 0;
            while (!out_valid && cycles < 5) begin @(posedge clk); #1; cycles = cycles + 1; end
            if (!out_valid) $fatal(1, "missing output vector %0d", index);
            compare_output(base);
            @(posedge clk); #1;
            if (out_valid) $fatal(1, "output did not transfer vector %0d", index);
        end
    endtask

    initial begin
        $readmemh("tb/tests/triangle_setup_vectors.mem", vectors);
        in_valid = 0; out_ready = 1; in_data = '0;
        reset_dut();
        for (integer i = 0; i < VECTORS; i = i + 1) send_and_check(i);

        // Acceptance enters Stage 1; live changes cannot affect the result.
        load_input(0);
        @(negedge clk); in_valid = 1;
        @(posedge clk); #1;
        if (out_valid) $fatal(1, "premature output after input acceptance");
        @(negedge clk); in_valid = 0; in_data = '1;
        @(posedge clk); #1;
        if (out_valid) $fatal(1, "output asserted before Stage 3");
        @(posedge clk); #1;
        if (!out_valid) $fatal(1, "three-stage result missing after live input changed");
        compare_output(0);
        @(posedge clk); #1;
        if (out_valid) $fatal(1, "result did not retire");

        // Consecutive accepted inputs produce one ordered output each cycle.
        for (integer i = 0; i < 6; i = i + 1) begin
            @(negedge clk); load_input(i*WORDS_PER_VECTOR); in_valid = 1;
            if (!in_ready) $fatal(1, "pipeline failed full-rate input at %0d", i);
            @(posedge clk); #1;
            if (i >= 2) begin
                if (!out_valid) $fatal(1, "full-rate output missing cycle=%0d", i);
                compare_output((i-2)*WORDS_PER_VECTOR);
            end else if (out_valid) begin
                $fatal(1, "full-rate output was early cycle=%0d", i);
            end
        end
        @(negedge clk); in_valid = 0;
        for (integer i = 4; i < 6; i = i + 1) begin
            @(posedge clk); #1;
            if (!out_valid) $fatal(1, "pipeline drain output missing index=%0d", i);
            compare_output(i*WORDS_PER_VECTOR);
        end
        @(posedge clk); #1;
        if (out_valid) $fatal(1, "duplicate output after full-rate drain");

        // Fill all stages during backpressure, then hold a fourth input until
        // space returns. The three queued outputs must stay ordered and unique.
        @(negedge clk); out_ready = 0; in_valid = 1;
        for (integer i = 0; i < 3; i = i + 1) begin
            load_input(i*WORDS_PER_VECTOR);
            if (!in_ready) $fatal(1, "unexpected input stall while filling stage %0d", i);
            @(posedge clk); #1;
            if (i < 2 && out_valid) $fatal(1, "backpressure output was early at fill %0d", i);
            if (i < 2) @(negedge clk);
        end
        if (!out_valid || out_data.tag !== vectors[0][15:0])
            $fatal(1, "first queued output missing under backpressure");
        held = out_data;
        @(negedge clk); load_input(3*WORDS_PER_VECTOR); in_valid = 1;
        if (in_ready) $fatal(1, "full pipeline accepted fourth input under backpressure");
        repeat (2) begin
            @(posedge clk); #1;
            if (!out_valid || out_data !== held || in_ready)
                $fatal(1, "full pipeline changed/stalled incorrectly");
        end
        @(negedge clk); out_ready = 1;
        @(posedge clk); #1;
        compare_output(WORDS_PER_VECTOR);
        @(negedge clk); in_valid = 0;
        @(posedge clk); #1;
        compare_output(2*WORDS_PER_VECTOR);
        @(posedge clk); #1;
        compare_output(3*WORDS_PER_VECTOR);
        @(posedge clk); #1;
        if (out_valid) $fatal(1, "backpressure drain produced duplicate output");

        // Reset while Stage 1 holds a valid transaction.
        load_input(0); @(negedge clk); in_valid = 1;
        @(posedge clk); #1;
        @(negedge clk); rst = 1; in_valid = 0;
        @(posedge clk); #1;
        @(negedge clk); rst = 0;
        repeat (3) begin @(posedge clk); #1; if (out_valid) $fatal(1, "stage-1 reset leaked result"); end

        // Reset while Stage 2 holds a valid transaction.
        load_input(0); @(negedge clk); in_valid = 1;
        @(posedge clk); #1;
        @(negedge clk); in_valid = 0;
        @(posedge clk); #1;
        @(negedge clk); rst = 1;
        @(posedge clk); #1;
        if (out_valid) $fatal(1, "Stage-2 reset left stale output");
        @(negedge clk); rst = 0;
        repeat (3) begin @(posedge clk); #1; if (out_valid) $fatal(1, "Stage-2 reset leaked result"); end

        // Reset while the Stage-3 output is stalled and stable.
        load_input(0); @(negedge clk); in_valid = 1; out_ready = 0;
        @(posedge clk); #1;
        @(negedge clk); in_valid = 0;
        repeat (2) @(posedge clk);
        #1;
        if (!out_valid) $fatal(1, "stalled result missing");
        held = out_data;
        repeat (3) begin @(posedge clk); #1; if (out_data !== held || !out_valid) $fatal(1, "stalled result changed"); end
        @(negedge clk); rst = 1;
        @(posedge clk); #1;
        if (out_valid) $fatal(1, "reset left stale setup output");
        @(negedge clk); rst = 0; out_ready = 1;
        send_and_check(1);

        $display("triangle_setup_tb: PASS vectors=%0d fields=%0d", VECTORS, compared);
        $finish;
    end
endmodule
