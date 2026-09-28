`timescale 1ns/1ps
module fragment_z_tb;
    localparam int unsigned PIXELS = 76800;
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic frag_valid;
    logic frag_ready;
    logic [8:0] frag_x;
    logic [7:0] frag_y;
    logic signed [41:0] frag_r_raw, frag_g_raw, frag_b_raw, frag_z_raw;
    logic z_rd_en;
    logic [16:0] z_rd_addr;
    logic [7:0] z_rd_data;
    logic z_wr_en;
    logic [16:0] z_wr_addr;
    logic [7:0] z_wr_data;
    logic fb_wr_en;
    logic [16:0] fb_wr_addr;
    logic [7:0] fb_wr_data;
    logic pipeline_empty;
    logic depth_result_valid;
    logic depth_pass;

    logic [7:0] z_mem [0:PIXELS-1];
    logic [7:0] expected_z_mem [0:PIXELS-1];

    logic exp_valid [0:3];
    logic exp_pass [0:3];
    integer exp_addr [0:3];
    integer exp_new_z [0:3];
    integer exp_colour [0:3];

    integer errors = 0;
    integer checks = 0;
    integer cycle_count = 0;
    integer accepted_count = 0;
    integer read_count = 0;
    integer decision_count = 0;
    integer depth_result_count = 0;
    integer depth_pass_event_count = 0;
    integer depth_fail_event_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    integer equal_fail_count = 0;
    integer fb_write_count = 0;
    integer z_write_count = 0;
    integer hazard_count = 0;
    integer stale_write_count = 0;
    integer read_address_mismatch_count = 0;
    integer write_address_mismatch_count = 0;
    integer write_data_mismatch_count = 0;
    integer z_memory_mismatch_count = 0;
    integer first_accept_cycle = -1;
    integer first_read_cycle = -1;
    integer first_write_cycle = -1;
    integer last_accept_cycle = -1;
    integer last_write_cycle = -1;
    localparam integer RANDOM_SEED = 32'h11011;
    integer seed = RANDOM_SEED;
    integer random_addr;
    integer random_gap;
    integer random_r;
    integer random_g;
    integer random_b;
    integer random_z;
    integer i;
    integer j;

    fragment_z dut (
        .clk_sys(clk), .rst(rst),
        .frag_valid(frag_valid), .frag_ready(frag_ready),
        .frag_x(frag_x), .frag_y(frag_y),
        .frag_r_raw(frag_r_raw), .frag_g_raw(frag_g_raw),
        .frag_b_raw(frag_b_raw), .frag_z_raw(frag_z_raw),
        .z_rd_en(z_rd_en), .z_rd_addr(z_rd_addr), .z_rd_data(z_rd_data),
        .z_wr_en(z_wr_en), .z_wr_addr(z_wr_addr), .z_wr_data(z_wr_data),
        .fb_wr_en(fb_wr_en), .fb_wr_addr(fb_wr_addr), .fb_wr_data(fb_wr_data),
        .pipeline_empty(pipeline_empty),
        .depth_result_valid(depth_result_valid), .depth_pass(depth_pass)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (z_rd_en)
            z_rd_data <= z_mem[z_rd_addr];
        if (z_wr_en)
            z_mem[z_wr_addr] <= z_wr_data;
    end

    function automatic integer addr_of(input integer x, input integer y);
        addr_of = y * 320 + x;
    endfunction

    function automatic integer q_rgb(input logic signed [41:0] raw);
        logic signed [41:0] shifted;
        begin
            shifted = raw >>> 8;
            if (shifted < 0) q_rgb = 0;
            else if (shifted > 255) q_rgb = 255;
            else q_rgb = shifted;
        end
    endfunction

    function automatic integer q_z(input logic signed [41:0] raw);
        logic signed [41:0] shifted;
        begin
            shifted = raw >>> 8;
            if (shifted < 0) q_z = 0;
            else if (shifted > 254) q_z = 254;
            else q_z = shifted;
        end
    endfunction

    function automatic integer rgb332_of(input logic signed [41:0] r,
                                         input logic signed [41:0] g,
                                         input logic signed [41:0] b);
        integer r8, g8, b8;
        begin
            r8 = q_rgb(r); g8 = q_rgb(g); b8 = q_rgb(b);
            rgb332_of = ((r8 >> 5) << 5) | ((g8 >> 5) << 2) | (b8 >> 6);
        end
    endfunction

    task automatic fail(input [1023:0] message);
        begin
            $display("FAIL cycle=%0d: %0s", cycle_count, message);
            errors = errors + 1;
        end
    endtask

    task automatic clear_models(input integer default_z);
        begin
            for (i = 0; i < PIXELS; i = i + 1) begin
                z_mem[i] = default_z[7:0];
                expected_z_mem[i] = default_z[7:0];
            end
            for (i = 0; i < 4; i = i + 1) begin
                exp_valid[i] = 1'b0;
                exp_pass[i] = 1'b0;
                exp_addr[i] = 0;
                exp_new_z[i] = 0;
                exp_colour[i] = 0;
            end
            z_rd_data = 8'hFF;
        end
    endtask

    task automatic pulse_reset;
        begin
            @(negedge clk);
            rst = 1'b1;
            frag_valid = 1'b0;
            repeat (2) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
            frag_valid = 1'b0;
        end
    endtask

    task automatic set_fragment(input integer x, input integer y,
                                input logic signed [41:0] r,
                                input logic signed [41:0] g,
                                input logic signed [41:0] b,
                                input logic signed [41:0] z);
        begin
            frag_x = x[8:0];
            frag_y = y[7:0];
            frag_r_raw = r;
            frag_g_raw = g;
            frag_b_raw = b;
            frag_z_raw = z;
            frag_valid = 1'b1;
        end
    endtask

    task automatic set_idle;
        begin
            frag_valid = 1'b0;
            frag_x = '0; frag_y = '0;
            frag_r_raw = '0; frag_g_raw = '0; frag_b_raw = '0; frag_z_raw = '0;
        end
    endtask

    task automatic wait_empty;
        begin
            while (!pipeline_empty) @(posedge clk);
            @(negedge clk);
        end
    endtask

    task automatic run_cycles(input integer count);
        begin
            for (integer n = 0; n < count; n = n + 1)
                @(posedge clk);
            @(negedge clk);
        end
    endtask

    task automatic one_case(input integer x, input integer y,
                            input logic signed [41:0] r,
                            input logic signed [41:0] g,
                            input logic signed [41:0] b,
                            input logic signed [41:0] z,
                            input integer old_z);
        begin
            clear_models(old_z);
            pulse_reset();
            @(negedge clk);
            set_fragment(x, y, r, g, b, z);
            @(posedge clk);
            @(negedge clk);
            set_idle();
            run_cycles(6);
            wait_empty();
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < 4; j = j + 1)
                exp_valid[j] = 1'b0;
        end else begin
            cycle_count = cycle_count + 1;

            if (exp_valid[3] && exp_pass[3])
                expected_z_mem[exp_addr[3]] = exp_new_z[3];

            for (j = 3; j > 0; j = j - 1) begin
                exp_valid[j] = exp_valid[j-1];
                exp_pass[j] = exp_pass[j-1];
                exp_addr[j] = exp_addr[j-1];
                exp_new_z[j] = exp_new_z[j-1];
                exp_colour[j] = exp_colour[j-1];
            end

            exp_valid[0] = frag_valid && frag_ready;
            if (exp_valid[0]) begin
                integer a;
                integer nz;
                integer old;
                a = addr_of(frag_x, frag_y);
                nz = q_z(frag_z_raw);
                old = expected_z_mem[a];
                exp_addr[0] = a;
                exp_new_z[0] = nz;
                exp_colour[0] = rgb332_of(frag_r_raw, frag_g_raw, frag_b_raw);
                exp_pass[0] = nz < old;
                accepted_count = accepted_count + 1;
                last_accept_cycle = cycle_count;
                if (first_accept_cycle < 0) first_accept_cycle = cycle_count;
            end
        end
    end

    always @(negedge clk) begin
        if (!rst) begin
            checks = checks + 1;
            if (z_rd_en !== exp_valid[1]) fail("unexpected Z read-valid alignment");
            if (depth_result_valid !== exp_valid[3])
                fail("depth-result valid alignment");
            if (depth_result_valid) begin
                depth_result_count = depth_result_count + 1;
                if (depth_pass !== exp_pass[3])
                    fail("depth-result pass mismatch");
                if (depth_pass) depth_pass_event_count = depth_pass_event_count + 1;
                else depth_fail_event_count = depth_fail_event_count + 1;
            end
            if (z_rd_en) begin
                read_count = read_count + 1;
                if (first_read_cycle < 0) first_read_cycle = cycle_count;
                if (z_rd_addr !== exp_addr[1]) begin
                    read_address_mismatch_count = read_address_mismatch_count + 1;
                    fail("Z read address mismatch");
                end
                if (z_rd_addr >= PIXELS) fail("Z read address out of range");
            end

            if (z_wr_en !== (exp_valid[3] && exp_pass[3])) begin
                fail("Z write-valid mismatch");
                if (!exp_valid[3] && z_wr_en) stale_write_count = stale_write_count + 1;
            end
            if (fb_wr_en !== z_wr_en) fail("colour/Z write-enable mismatch");
            if (z_wr_en) begin
                z_write_count = z_write_count + 1;
                fb_write_count = fb_write_count + 1;
                if (first_write_cycle < 0) first_write_cycle = cycle_count;
                last_write_cycle = cycle_count;
                if (z_wr_addr !== exp_addr[3] || fb_wr_addr !== exp_addr[3]) begin
                    write_address_mismatch_count = write_address_mismatch_count + 1;
                    fail("write address mismatch");
                end
                if (z_wr_data !== exp_new_z[3] || fb_wr_data !== exp_colour[3]) begin
                    write_data_mismatch_count = write_data_mismatch_count + 1;
                    fail("write data mismatch");
                end
                decision_count = decision_count + 1;
                pass_count = pass_count + 1;
            end else if (exp_valid[3]) begin
                decision_count = decision_count + 1;
                fail_count = fail_count + 1;
                if (exp_new_z[3] == expected_z_mem[exp_addr[3]])
                    equal_fail_count = equal_fail_count + 1;
            end

            if (pipeline_empty !== !(exp_valid[0] || exp_valid[1] || exp_valid[2] || exp_valid[3]))
                fail("pipeline_empty mismatch");
            if (z_rd_en && z_wr_en && (z_rd_addr == z_wr_addr)) begin
                hazard_count = hazard_count + 1;
                fail("equal-address Z read/write hazard");
            end
        end
    end

    initial begin
        frag_valid = 1'b0;
        frag_x = '0; frag_y = '0;
        frag_r_raw = '0; frag_g_raw = '0; frag_b_raw = '0; frag_z_raw = '0;
        clear_models(8'hFF);

        one_case(0, 0, 0, 0, 0, 0, 255);
        one_case(319, 0, 255*256, 0, 0, 254*256, 255);
        one_case(0, 239, 0, 255*256, 0, 100*256, 101);
        one_case(319, 239, 0, 0, 255*256, 99*256, 100);
        one_case(10, 10, -257, -256, -1, -257, 255);
        one_case(11, 10, 256*256, 255*256, 254*256, 255*256, 255);
        one_case(12, 10, 256*256, 256*256, 256*256, 256*256, 255);
        one_case(13, 10, 2147483647, -2147483648, -1, 2147483647, 255);
        one_case(14, 10, 42'sh10000000000, -42'sh10000000000,
                 42'sh10000000100, 42'sh10000000000, 255);

        clear_models(100);
        pulse_reset();
        for (i = 0; i < 12; i = i + 1) begin
            @(negedge clk);
            set_fragment(i + 20, 30, (i + 1) * 256, (i - 5) * 256,
                         (i * 17) * 256, (i % 3 == 0) ? 99*256 : 100*256);
            @(posedge clk);
        end
        @(negedge clk); set_idle();
        run_cycles(8);
        wait_empty();

        clear_models(255);
        for (i = 0; i < 40; i = i + 1) begin
            random_addr = 10000 + i * 17;
            z_mem[random_addr] = (i % 3 == 0) ? 0 : ((i % 3 == 1) ? 100 : 255);
            expected_z_mem[random_addr] = z_mem[random_addr];
        end
        pulse_reset();
        for (i = 0; i < 40; i = i + 1) begin
            random_addr = 10000 + i * 17;
            random_r = ($urandom(seed) % 2001) - 1000;
            random_g = ($urandom(seed) % 2001) - 1000;
            random_b = ($urandom(seed) % 2001) - 1000;
            random_z = (i % 3 == 0) ? -64 : ((i % 3 == 1) ? 100 : 220);
            random_gap = $urandom(seed) % 5;
            @(negedge clk);
            if (random_gap == 0)
                set_idle();
            else
                set_fragment(random_addr % 320, random_addr / 320,
                             random_r * 256, random_g * 256,
                             random_b * 256, random_z * 256);
            @(posedge clk);
        end
        @(negedge clk); set_idle();
        run_cycles(10);
        wait_empty();

        clear_models(255);
        pulse_reset();
        @(negedge clk); set_fragment(77, 88, 12*256, 34*256, 56*256, 20*256);
        @(posedge clk);
        @(negedge clk); set_idle();
        repeat (2) @(posedge clk);
        @(negedge clk); rst = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk); rst = 1'b0;
        set_idle();
        if (!pipeline_empty) fail("reset did not empty pipeline");
        @(negedge clk); set_fragment(78, 88, 1*256, 2*256, 3*256, 1*256);
        @(posedge clk);
        @(negedge clk); set_idle();
        wait_empty();

        clear_models(100);
        pulse_reset();
        @(negedge clk); set_fragment(101, 101, 0, 0, 0, 99*256);
        @(posedge clk);
        @(negedge clk); set_idle();
        wait_empty();
        @(negedge clk); set_fragment(101, 101, 255*256, 0, 0, 99*256);
        @(posedge clk);
        @(negedge clk); set_idle();
        wait_empty();
        @(negedge clk); set_fragment(101, 101, 0, 255*256, 0, 99*256);
        @(posedge clk);
        @(negedge clk); set_idle();
        wait_empty();

        for (i = 0; i < PIXELS; i = i + 1)
            if (z_mem[i] !== expected_z_mem[i])
                z_memory_mismatch_count = z_memory_mismatch_count + 1;
        if (z_memory_mismatch_count != 0)
            fail("final Z memory model mismatch");
        if (read_count != accepted_count) fail("read count does not equal accepted count");
        if (depth_result_count != decision_count) fail("depth-result count mismatch");
        if (depth_pass_event_count != pass_count || depth_fail_event_count != fail_count)
            fail("depth-result pass/fail count mismatch");
        if (fb_write_count != z_write_count) fail("colour/Z write count mismatch");
        if (hazard_count != 0) fail("legal traffic triggered hazard");
        if (stale_write_count != 0) fail("stale write observed");
        if (errors == 0)
            $display("fragment_z_tb: PASS checks=%0d accepted=%0d reads=%0d decisions=%0d passes=%0d fails=%0d equal_fails=%0d writes=%0d read_addr_mismatches=%0d write_addr_mismatches=%0d write_data_mismatches=%0d z_memory_mismatches=%0d hazards=%0d stale=%0d first_accept=%0d first_read=%0d first_write=%0d last_accept=%0d last_write=%0d seed=0x%0x",
                     checks, accepted_count, read_count, decision_count, pass_count,
                     fail_count, equal_fail_count, z_write_count,
                     read_address_mismatch_count, write_address_mismatch_count,
                     write_data_mismatch_count, z_memory_mismatch_count,
                     hazard_count, stale_write_count,
                     first_accept_cycle,
                     first_read_cycle, first_write_cycle, last_accept_cycle,
                     last_write_cycle, RANDOM_SEED);
        else
            $display("fragment_z_tb: FAIL errors=%0d checks=%0d accepted=%0d reads=%0d decisions=%0d passes=%0d fails=%0d writes=%0d hazards=%0d stale=%0d",
                     errors, checks, accepted_count, read_count, decision_count,
                     pass_count, fail_count, z_write_count, hazard_count,
                     stale_write_count);
        $finish;
    end
endmodule
