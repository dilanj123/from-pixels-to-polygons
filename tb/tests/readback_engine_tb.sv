`timescale 1ns/1ps
module readback_engine_tb;
    localparam integer PIXELS = 76800;
    localparam integer WORDS = 19200;
    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    logic start_valid = 0;
    logic start_ready;
    logic [15:0] start_tag = 0;
    logic [1:0] start_front_id = 0;
    logic fb_rd_en;
    logic [16:0] fb_rd_addr;
    logic [1:0] fb_rd_buffer_id;
    logic [7:0] fb_rd_data = 0;
    logic rsp_valid;
    logic rsp_ready = 1;
    logic [31:0] rsp_data;
    logic readback_active;
    logic readback_complete;

    logic [7:0] fb_mem [0:2][0:PIXELS-1];
    logic [7:0] expected_bytes [0:PIXELS-1];
    integer accepted_words, read_count, completion_count;
    integer byte_errors, response_errors, read_errors, unstable_errors;
    integer expected_id, expected_tag, prev_stall;
    integer cycle_count, seed, mode, id, addr, n, k;
    integer stall_target, stall_hold, run_count, forced_stall_cycles;
    logic [31:0] ready_seed_value;
    integer abort_stall_index;
    integer expected_checksum;
    logic [31:0] checksum_model;
    logic [31:0] previous_rsp;
    logic previous_valid;
    logic [31:0] lfsr;
    string vec_dir, render_path;
    integer rc;

    readback_engine dut (
        .clk_sys(clk), .rst(rst),
        .start_valid(start_valid), .start_ready(start_ready),
        .start_tag(start_tag), .start_front_id(start_front_id),
        .fb_rd_en(fb_rd_en), .fb_rd_addr(fb_rd_addr),
        .fb_rd_buffer_id(fb_rd_buffer_id), .fb_rd_data(fb_rd_data),
        .rsp_valid(rsp_valid), .rsp_ready(rsp_ready), .rsp_data(rsp_data),
        .readback_active(readback_active), .readback_complete(readback_complete)
    );

    // Genuine one-edge synchronous source memory, with three independent images.
    always @(posedge clk) begin
        if (fb_rd_en)
            fb_rd_data <= fb_mem[fb_rd_buffer_id][fb_rd_addr];
    end

    // Deterministic but non-periodic response backpressure.
    always @(negedge clk) begin
        if (rst) begin
            lfsr <= ready_seed_value;
            rsp_ready <= 1'b1;
            stall_hold <= 0;
        end else begin
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
            if ((rsp_valid && accepted_words == stall_target && stall_hold < 3) ||
                (abort_stall_index >= 0 && rsp_valid && accepted_words == abort_stall_index)) begin
                rsp_ready <= 1'b0;
                if (stall_hold < 3) stall_hold <= stall_hold + 1;
                forced_stall_cycles = forced_stall_cycles + 1;
            end else begin
                rsp_ready <= (lfsr[2:0] != 3'b000) && (lfsr[7:5] != 3'b000);
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            read_count = 0;
            accepted_words = 0;
            completion_count = 0;
            byte_errors = 0;
            response_errors = 0;
            read_errors = 0;
            unstable_errors = 0;
            checksum_model = 0;
            stall_hold = 0;
            previous_valid = 0;
            cycle_count = 0;
        end else begin
            cycle_count = cycle_count + 1;
            if ((rsp_valid || fb_rd_en) && !readback_active)
                response_errors = response_errors + 1;
            if (previous_valid && (!rsp_valid || rsp_data !== previous_rsp))
                unstable_errors = unstable_errors + 1;
            previous_valid = rsp_valid && !rsp_ready;
            if (previous_valid) previous_rsp = rsp_data;

            if (fb_rd_en) begin
                if (fb_rd_addr !== read_count[16:0]) read_errors = read_errors + 1;
                if (fb_rd_addr >= PIXELS) read_errors = read_errors + 1;
                if (fb_rd_buffer_id !== expected_id[1:0]) read_errors = read_errors + 1;
                read_count = read_count + 1;
            end

            if (rsp_valid && rsp_ready) begin
                case (accepted_words)
                    0: if (rsp_data !== {4'hC,12'h000,expected_tag[15:0]}) response_errors = response_errors + 1;
                    1: if (rsp_data !== 32'd19200) response_errors = response_errors + 1;
                    2: if (rsp_data !== {3'b000,8'd1,expected_id[1:0],9'd240,10'd320}) response_errors = response_errors + 1;
                    default: begin
                        if (accepted_words < 3 + WORDS) begin
                            n = accepted_words - 3;
                            expected_checksum = 0;
                            expected_checksum = expected_bytes[4*n+0]
                                | (expected_bytes[4*n+1] << 8)
                                | (expected_bytes[4*n+2] << 16)
                                | (expected_bytes[4*n+3] << 24);
                            if (rsp_data !== expected_checksum[31:0]) response_errors = response_errors + 1;
                            checksum_model = checksum_model + expected_checksum[31:0];
                            for (k = 0; k < 4; k = k + 1)
                                if (rsp_data[k*8 +: 8] !== expected_bytes[4*n+k]) byte_errors = byte_errors + 1;
                        end else if (accepted_words == 3 + WORDS)
                            if (rsp_data !== {4'hD,12'h000,expected_tag[15:0]}) response_errors = response_errors + 1;
                        else if (accepted_words == 4 + WORDS)
                            if (rsp_data !== 32'h0) response_errors = response_errors + 1;
                        else if (accepted_words == 5 + WORDS)
                            if (rsp_data !== checksum_model) response_errors = response_errors + 1;
                        else response_errors = response_errors + 1;
                    end
                endcase
                accepted_words = accepted_words + 1;
            end
            if (readback_complete) completion_count = completion_count + 1;
        end
    end

    function automatic [7:0] pattern(input integer p, input integer b);
        reg [31:0] x;
        begin
            case (p)
                0: pattern = 8'h00;
                1: pattern = 8'hff;
                2: pattern = (b * 8'h35 + (b >> 8) * 8'h17 + 8'h29) & 8'hff;
                3: pattern = b[0] ? 8'haa : 8'h55;
                4: begin
                    x = b ^ (b << 13) ^ (b >> 7) ^ 32'h7f4a7c15;
                    x = x * 32'h045d9f3b;
                    pattern = x[23:16] ^ x[7:0];
                end
                default: pattern = (p * 8'h51 + b * 8'h0b + 8'h63) & 8'hff;
            endcase
        end
    endfunction

    task automatic run_image(input integer selected_id, input integer image_mode);
        integer i;
        begin
            expected_id = selected_id;
            expected_tag = 16'ha000 + image_mode * 16 + selected_id;
            mode = image_mode;
            if (image_mode == 5) begin
                render_path = $sformatf("%s/frame_4_fb.hex", vec_dir);
                $readmemh(render_path, expected_bytes);
            end
            for (i = 0; i < PIXELS; i = i + 1) begin
                fb_mem[0][i] = (selected_id == 0) ? ((image_mode == 5) ? expected_bytes[i] : pattern(image_mode, i)) : (pattern(image_mode, i) ^ 8'h11);
                fb_mem[1][i] = (selected_id == 1) ? ((image_mode == 5) ? expected_bytes[i] : pattern(image_mode, i)) : (pattern(image_mode, i) ^ 8'h52);
                fb_mem[2][i] = (selected_id == 2) ? ((image_mode == 5) ? expected_bytes[i] : pattern(image_mode, i)) : (pattern(image_mode, i) ^ 8'ha7);
                if (image_mode != 5) expected_bytes[i] = pattern(image_mode, i);
            end
            accepted_words = 0;
            read_count = 0;
            completion_count = 0;
            byte_errors = 0;
            response_errors = 0;
            read_errors = 0;
            unstable_errors = 0;
            checksum_model = 0;
            ready_seed_value = 32'h91e10da5 ^ (run_count * 32'h10204081);
            lfsr = ready_seed_value;
            case (run_count)
                0: stall_target = 0;
                1: stall_target = 1;
                2: stall_target = 2;
                3: stall_target = 3;
                4: stall_target = 9580;
                5: stall_target = 19202;
                6: stall_target = 19203;
                7: stall_target = 19204;
                8: stall_target = 19205;
                9: stall_target = 0;
                default: stall_target = 2;
            endcase
            run_count = run_count + 1;
            @(negedge clk);
            start_tag = expected_tag[15:0];
            start_front_id = selected_id[1:0];
            start_valid = 1;
            @(posedge clk);
            #1;
            if (!readback_active) $fatal(1, "readback did not become active");
            @(negedge clk);
            start_valid = 0;
            start_tag = 16'hd00d;
            start_front_id = selected_id == 2 ? 0 : selected_id + 1;
            while (completion_count == 0 && cycle_count < 3000000) @(posedge clk);
            #2;
            if (cycle_count >= 3000000) $fatal(1, "readback timeout mode=%0d id=%0d", image_mode, selected_id);
            if (read_count != PIXELS || accepted_words != 19206 || completion_count != 1)
                $fatal(1, "counts mode=%0d id=%0d reads=%0d rsp=%0d complete=%0d", image_mode, selected_id, read_count, accepted_words, completion_count);
            if (byte_errors || response_errors || read_errors || unstable_errors)
                $fatal(1, "mismatch mode=%0d id=%0d bytes=%0d rsp=%0d reads=%0d unstable=%0d", image_mode, selected_id, byte_errors, response_errors, read_errors, unstable_errors);
            if (readback_active || rsp_valid) $fatal(1, "active/valid did not clear after final response");
            if (stall_hold < 3) $fatal(1, "targeted stall not exercised word=%0d held=%0d", stall_target, stall_hold);
            $display("READBACK IMAGE PASS mode=%0d id=%0d bytes=%0d reads=%0d responses=%0d checksum=%08x target_stall_word=%0d ready_seed=%08x", image_mode, selected_id, PIXELS, read_count, accepted_words, checksum_model, stall_target, ready_seed_value);
            @(negedge clk);
            rst = 1;
            repeat (2) @(posedge clk);
            @(negedge clk);
            rst = 0;
        end
    endtask

    task automatic reset_abort_check(input integer target_kind);
        integer guard;
        begin
            // Public phases: BEGIN, descriptor, first request, returned byte,
            // partial pack, stalled data, middle/last address and each END word.
            @(negedge clk); start_valid = 1; start_tag = 16'hbeef; start_front_id = 1;
            @(posedge clk); @(negedge clk); start_valid = 0;
            guard = 0;
            case (target_kind)
                0: while (!(rsp_valid && rsp_data[31:28] == 4'hc)) begin @(negedge clk); guard=guard+1; if(guard>20)$fatal(1,"reset target timeout"); end
                1: while (!(rsp_valid && accepted_words == 2)) begin @(negedge clk); guard=guard+1; if(guard>30)$fatal(1,"reset target timeout"); end
                2: while (!(fb_rd_en && fb_rd_addr == 17'd0)) begin @(negedge clk); guard=guard+1; if(guard>50)$fatal(1,"reset target timeout"); end
                3: begin
                    while (!(fb_rd_en && fb_rd_addr == 17'd0)) begin @(negedge clk); guard=guard+1; if(guard>50)$fatal(1,"reset target timeout"); end
                    @(posedge clk); @(negedge clk);
                end
                4: while (!(fb_rd_en && fb_rd_addr == 17'd2)) begin @(negedge clk); guard=guard+1; if(guard>100)$fatal(1,"reset target timeout"); end
                5: begin
                    abort_stall_index = 3;
                    while (!(rsp_valid && accepted_words == 3)) begin @(negedge clk); guard=guard+1; if(guard>100)$fatal(1,"reset target timeout"); end
                    repeat (3) @(negedge clk);
                end
                6: while (!(fb_rd_en && fb_rd_addr >= 17'd30000)) begin @(negedge clk); guard=guard+1; if(guard>100000)$fatal(1,"reset target timeout"); end
                7: while (!(fb_rd_en && fb_rd_addr == 17'd76799)) begin @(negedge clk); guard=guard+1; if(guard>300000)$fatal(1,"reset target timeout"); end
                8: while (!(rsp_valid && rsp_data[31:28] == 4'hd)) begin @(negedge clk); guard=guard+1; if(guard>300000)$fatal(1,"reset target timeout"); end
                9: while (!(rsp_valid && accepted_words == 19204)) begin @(negedge clk); guard=guard+1; if(guard>300000)$fatal(1,"reset target timeout"); end
                10: begin
                    abort_stall_index = 19205;
                    while (!(rsp_valid && accepted_words == 19205)) begin @(negedge clk); guard=guard+1; if(guard>300000)$fatal(1,"reset target timeout"); end
                    repeat (3) @(negedge clk);
                end
            endcase
            rst = 1;
            repeat (2) @(posedge clk);
            #1;
            if (readback_active || rsp_valid || readback_complete) $fatal(1, "reset abort outputs target=%0d", target_kind);
            @(negedge clk); rst = 0;
            abort_stall_index = -1;
            repeat (3) @(posedge clk);
            #1;
            if (readback_active || rsp_valid || fb_rd_en || readback_complete) $fatal(1, "stale activity target=%0d", target_kind);
            $display("READBACK RESET ABORT PASS target=%0d", target_kind);
        end
    endtask

    initial begin
        accepted_words = 0; read_count = 0; completion_count = 0;
        byte_errors = 0; response_errors = 0; read_errors = 0; unstable_errors = 0;
        checksum_model = 0; expected_id = 0; expected_tag = 0; cycle_count = 0;
        vec_dir = "/tmp/gfx012_vectors";
        rc = $value$plusargs("VEC_DIR=%s", vec_dir);
        ready_seed_value = 32'h91e10da5;
        lfsr = 32'h91e10da5;
        run_count = 0; stall_target = -1; stall_hold = 0; forced_stall_cycles = 0; abort_stall_index = -1;
        repeat (3) @(posedge clk);
        @(negedge clk); rst = 0;

        run_image(0, 0);
        run_image(1, 1);
        run_image(2, 2);
        run_image(0, 3);
        run_image(1, 4);
        run_image(2, 5);

        // Abort active transactions at representative public-interface phases.
        for (id = 0; id < 11; id = id + 1) begin
            reset_abort_check(id);
            // Full successful post-reset recovery after each abort.
            run_image(id % 3, (id + 2) % 5);
        end
        $display("READBACK ENGINE PASS full_frames=17 reset_aborts=11 forced_stall_cycles=%0d", forced_stall_cycles);
        $finish;
    end
endmodule
