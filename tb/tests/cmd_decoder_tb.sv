module cmd_decoder_tb;
    import gfx_pkg::*;
    logic clk = 0, rst = 1;
    logic fifo_valid, fifo_ready;
    logic [31:0] fifo_data;
    logic dec_valid, dec_ready;
    decoded_command_t dec_data;
    logic err_valid, err_ready, cmd_error;
    decoder_error_t err_data;
    integer checks = 0, seed = 32'hD006;

    always #5 clk = ~clk;
    cmd_decoder dut (
        .clk_sys(clk), .rst(rst), .fifo_valid(fifo_valid), .fifo_ready(fifo_ready),
        .fifo_data(fifo_data), .dec_valid(dec_valid), .dec_ready(dec_ready),
        .dec_data(dec_data), .err_valid(err_valid), .err_ready(err_ready),
        .err_data(err_data), .cmd_error(cmd_error)
    );

    function automatic [31:0] hdr(input integer op, input integer tag, input integer res);
        hdr = (op << 28) | (res << 16) | tag;
    endfunction
    function automatic [31:0] vertex(input integer x, input integer y, input integer res);
        vertex = (y << 13) | x | (res << 26);
    endfunction

    task automatic send_word(input logic [31:0] word);
        begin
            while (!fifo_ready) @(posedge clk);
            @(negedge clk); fifo_data = word; fifo_valid = 1'b1;
            @(posedge clk); #1;
            if (!fifo_ready) begin end
            @(negedge clk); fifo_valid = 1'b0; fifo_data = '0;
        end
    endtask

    task automatic wait_dec(input logic [3:0] op, input logic [15:0] tag);
        begin
            while (!dec_valid) @(posedge clk);
            if (dec_data.opcode !== op || dec_data.tag !== tag)
                $fatal(1, "decoded header mismatch got=%h/%h expected=%h/%h", dec_data.opcode, dec_data.tag, op, tag);
            checks = checks + 1;
            @(posedge clk); #1;
        end
    endtask

    task automatic wait_error(input logic [7:0] code, input logic [3:0] op, input logic [15:0] tag);
        begin
            while (!err_valid) @(posedge clk);
            if (err_data.code !== code || err_data.opcode !== op || err_data.tag !== tag)
                $fatal(1, "error mismatch got=%h/%h/%h expected=%h/%h/%h", err_data.code, err_data.opcode, err_data.tag, code, op, tag);
            checks = checks + 1;
            @(posedge clk); #1;
        end
    endtask

    task automatic reset_dut;
        begin
            rst = 1'b1; repeat (2) @(posedge clk); #1; rst = 1'b0;
            fifo_valid = 0; fifo_data = 0; dec_ready = 1; err_ready = 1;
        end
    endtask

    initial begin
        fifo_valid = 0; fifo_data = 0; dec_ready = 1; err_ready = 1;
        reset_dut();

        send_word(hdr(CMD_NOP, 16'h0001, 0)); wait_dec(CMD_NOP, 16'h0001);
        send_word(hdr(CMD_READ_FRONT, 16'h0002, 0)); wait_dec(CMD_READ_FRONT, 16'h0002);
        send_word(hdr(CMD_GET_STATUS, 16'h0003, 0)); wait_dec(CMD_GET_STATUS, 16'h0003);
        send_word(hdr(CMD_GET_COUNTERS, 16'h0004, 0)); wait_dec(CMD_GET_COUNTERS, 16'h0004);

        send_word(hdr(CMD_BEGIN_FRAME, 16'h0010, 0)); send_word(32'h000000A5);
        wait_dec(CMD_BEGIN_FRAME, 16'h0010);
        if (dec_data.clear_rgb332 !== 8'hA5) $fatal(1, "BEGIN_FRAME payload mismatch");

        send_word(hdr(CMD_SET_SOBEL, 16'h0011, 0)); send_word(32'h0000017F);
        wait_dec(CMD_SET_SOBEL, 16'h0011);
        if (dec_data.sobel_threshold !== 8'h7F || dec_data.sobel_bypass !== 1'b1) $fatal(1, "SET_SOBEL payload mismatch");

        send_word(hdr(CMD_PRESENT, 16'h0012, 0)); send_word(32'h00000001);
        wait_dec(CMD_PRESENT, 16'h0012);
        if (dec_data.present_mode !== 1'b1) $fatal(1, "PRESENT payload mismatch");

        send_word(hdr(CMD_DRAW_TRIANGLE, 16'h0020, 0));
        send_word(vertex(5120, 3840, 0)); send_word(vertex(1, 2, 0)); send_word(vertex(3, 4, 0));
        send_word(32'h00000000); send_word(32'h7FFFFFFF); send_word(32'h80000000); send_word(32'hFFFFFFFF);
        send_word(32'h01020304); send_word(32'h11121314); send_word(32'h21222324); send_word(32'h31323334);
        send_word(32'h41424344); send_word(32'h51525354); send_word(32'h61626364); send_word(32'h71727374);
        wait_dec(CMD_DRAW_TRIANGLE, 16'h0020);
        if (dec_data.v0_x !== 13'd5120 || dec_data.v0_y !== 13'd3840 ||
            dec_data.r_start !== 32'sh00000000 || dec_data.g_start !== 32'sh7FFFFFFF ||
            dec_data.b_start !== -32'sh80000000 || dec_data.z_start !== -32'sh1)
            $fatal(1, "DRAW payload decode mismatch");

        // Decoder output must remain stable while downstream is stalled.
        dec_ready = 0; send_word(hdr(CMD_NOP, 16'h0030, 0));
        while (!dec_valid) @(posedge clk);
        repeat (3) begin @(posedge clk); #1; if (dec_data.tag !== 16'h0030) $fatal(1, "stalled decode changed"); end
        dec_ready = 1; @(posedge clk); #1;

        // Unknown opcodes consume exactly one word and resynchronize.
        send_word(hdr(4'h8, 16'h0040, 0)); wait_error(ERR_UNKNOWN_OPCODE, 4'h8, 16'h0040);
        send_word(hdr(CMD_NOP, 16'h0041, 0)); wait_dec(CMD_NOP, 16'h0041);
        send_word(hdr(4'hF, 16'h0042, 0)); wait_error(ERR_UNKNOWN_OPCODE, 4'hF, 16'h0042);

        // Error output must remain stable while the downstream consumer stalls.
        err_ready = 0; send_word(hdr(4'h8, 16'h0043, 0));
        while (!err_valid) @(posedge clk);
        repeat (3) begin @(posedge clk); #1; if (err_data.tag !== 16'h0043 || err_data.opcode !== 4'h8)
            $fatal(1, "stalled error changed"); end
        err_ready = 1; @(posedge clk); #1;

        // Known malformed DRAW consumes all 16 words before erroring.
        send_word(hdr(CMD_DRAW_TRIANGLE, 16'h0050, 1));
        for (integer i = 1; i < 16; i = i + 1) send_word(i);
        wait_error(ERR_RESERVED_NONZERO, CMD_DRAW_TRIANGLE, 16'h0050);
        send_word(hdr(CMD_NOP, 16'h0051, 0)); wait_dec(CMD_NOP, 16'h0051);

        send_word(hdr(CMD_BEGIN_FRAME, 16'h0060, 0));
        repeat (4) @(posedge clk);
        if (dec_valid || err_valid) $fatal(1, "partial packet emitted output");
        send_word(32'h00000012); wait_dec(CMD_BEGIN_FRAME, 16'h0060);

        send_word(hdr(CMD_BEGIN_FRAME, 16'h0061, 0));
        @(negedge clk); rst = 1; @(posedge clk); #1; rst = 0;
        send_word(hdr(CMD_NOP, 16'h0062, 0)); wait_dec(CMD_NOP, 16'h0062);

        send_word(hdr(CMD_BEGIN_FRAME, 16'h0070, 1)); send_word(32'h0); wait_error(ERR_RESERVED_NONZERO, CMD_BEGIN_FRAME, 16'h0070);
        send_word(hdr(CMD_SET_SOBEL, 16'h0071, 0)); send_word(32'h00000200); wait_error(ERR_RESERVED_NONZERO, CMD_SET_SOBEL, 16'h0071);
        send_word(hdr(CMD_PRESENT, 16'h0072, 0)); send_word(32'h00000002); wait_error(ERR_RESERVED_NONZERO, CMD_PRESENT, 16'h0072);
        send_word(hdr(CMD_DRAW_TRIANGLE, 16'h0073, 0));
        send_word(vertex(5121, 0, 0)); send_word(vertex(0, 0, 0)); send_word(vertex(0, 0, 0));
        for (integer i = 4; i < 16; i = i + 1) send_word(0);
        wait_error(ERR_COORD_RANGE, CMD_DRAW_TRIANGLE, 16'h0073);
        send_word(hdr(CMD_DRAW_TRIANGLE, 16'h0074, 0));
        send_word(vertex(0, 3841, 0)); send_word(vertex(0, 0, 0)); send_word(vertex(0, 0, 0));
        for (integer i = 4; i < 16; i = i + 1) send_word(0);
        wait_error(ERR_COORD_RANGE, CMD_DRAW_TRIANGLE, 16'h0074);
        if (!cmd_error) $fatal(1, "sticky CMD_ERROR was not set");

        // Every truncated DRAW prefix must wait without emitting output.
        for (integer p = 0; p < 15; p = p + 1) begin
            reset_dut();
            send_word(hdr(CMD_DRAW_TRIANGLE, 16'h0800 + p, 0));
            for (integer q = 0; q < p; q = q + 1) send_word(q);
            repeat (2) @(posedge clk);
            if (dec_valid || err_valid) $fatal(1, "truncated DRAW emitted at word %0d", p + 1);
        end
        reset_dut();

        // Deterministic malformed stream with an independent expected result.
        for (integer m = 0; m < 20; m = m + 1) begin
            integer mr; mr = $urandom(seed);
            repeat (mr & 3) @(posedge clk);
            if (mr & 1) begin
                send_word(hdr(8 + (mr & 7), 16'h0900 + m, 0));
                wait_error(ERR_UNKNOWN_OPCODE, 8 + (mr & 7), 16'h0900 + m);
            end else begin
                send_word(hdr(CMD_NOP, 16'h0900 + m, 1));
                wait_error(ERR_RESERVED_NONZERO, CMD_NOP, 16'h0900 + m);
            end
        end

        // Deterministic mixed legal one-word stream.
        for (integer j = 0; j < 40; j = j + 1) begin
            integer r; r = $urandom(seed);
            repeat (r & 3) @(posedge clk);
            send_word(hdr((r & 1) ? CMD_NOP : CMD_GET_STATUS, 16'h1000 + j, 0));
            wait_dec((r & 1) ? CMD_NOP : CMD_GET_STATUS, 16'h1000 + j);
        end
        $display("cmd_decoder_tb: PASS checks=%0d seed=0x%0x", checks, seed);
        $finish;
    end
endmodule
