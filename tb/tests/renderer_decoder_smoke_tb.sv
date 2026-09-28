`timescale 1ns/1ps
module renderer_decoder_smoke_tb;
    localparam int PIXELS = 76800;
    logic clk = 0, rst = 1;
    always #5 clk = ~clk;

    logic fifo_valid, fifo_ready;
    logic [31:0] fifo_data;
    logic dec_valid, dec_ready, err_valid, err_ready, cmd_error;
    gfx_pkg::decoded_command_t dec_data;
    gfx_pkg::decoder_error_t err_data;
    logic renderer_quiescent;
    integer i, mismatches;
    integer expected_fb [0:PIXELS-1];
    integer expected_z [0:PIXELS-1];
    string vec_dir, path;

    cmd_decoder decoder (
        .clk_sys(clk), .rst(rst), .fifo_valid(fifo_valid), .fifo_ready(fifo_ready),
        .fifo_data(fifo_data), .dec_valid(dec_valid), .dec_ready(dec_ready),
        .dec_data(dec_data), .err_valid(err_valid), .err_ready(err_ready),
        .err_data(err_data), .cmd_error(cmd_error)
    );
    renderer_core renderer (
        .clk_sys(clk), .rst(rst), .render_cmd_valid(dec_valid),
        .render_cmd_ready(dec_ready), .render_cmd(dec_data),
        .renderer_quiescent(renderer_quiescent)
    );

    logic [31:0] words [0:18];
    integer word_count, index;
    integer draw_seen;

    always @(posedge clk) begin
        if (!rst && dec_valid && dec_ready && dec_data.opcode == gfx_pkg::CMD_DRAW_TRIANGLE) begin
            draw_seen = draw_seen + 1;
        end
    end

    task automatic send_word(input logic [31:0] word);
        begin
            while (!fifo_ready) @(posedge clk);
            @(negedge clk); fifo_data = word; fifo_valid = 1'b1;
            @(posedge clk); @(negedge clk); fifo_valid = 1'b0;
        end
    endtask

    initial begin
        fifo_valid = 0; fifo_data = 0; err_ready = 1;
        if (!$value$plusargs("VEC_DIR=%s", vec_dir)) vec_dir = "/tmp/gfx012_vectors";
        words[0] = 32'h10000002; words[1] = 32'h000000A5;
        words[2] = 32'h00000003;
        words[3] = 32'h20000004;
        words[4] = 32'h000A0050; words[5] = 32'h000A0320; words[6] = 32'h00640050;
        words[7] = 32'h00005000; words[8] = 32'h00002800; words[9] = 32'h00001400; words[10] = 32'h00006400;
        words[11] = 32'h00000000; words[12] = 32'h00000000; words[13] = 32'h00000000; words[14] = 32'h00000000;
        words[15] = 32'h00000000; words[16] = 32'h00000000; words[17] = 32'h00000000; words[18] = 32'h00000000;
        word_count = 19;
        draw_seen = 0;
        repeat (3) @(posedge clk); rst = 0;
        for (index = 0; index < word_count; index = index + 1) send_word(words[index]);
        while (draw_seen != 1) @(posedge clk);
        @(posedge clk);
        while (!renderer_quiescent) @(posedge clk);
        path = $sformatf("%s/frame_1_fb.hex", vec_dir); $readmemh(path, expected_fb);
        path = $sformatf("%s/frame_1_z.hex", vec_dir); $readmemh(path, expected_z);
        mismatches = 0;
        for (i = 0; i < PIXELS; i = i + 1) begin
            if (renderer.framebuffer_i.mem[i] !== expected_fb[i][7:0]) begin
                if (mismatches == 0) $display("first FB mismatch addr=%0d exp=%02x act=%02x", i, expected_fb[i], renderer.framebuffer_i.mem[i]);
                mismatches = mismatches + 1;
            end
            if (renderer.zbuffer_i.mem[i] !== expected_z[i][7:0]) begin
                if (mismatches == 0) $display("first Z mismatch addr=%0d exp=%02x act=%02x", i, expected_z[i], renderer.zbuffer_i.mem[i]);
                mismatches = mismatches + 1;
            end
        end
        if (err_valid || cmd_error) $fatal(1, "decoder error during smoke");
        if (mismatches != 0) $fatal(1, "decoder smoke mismatches=%0d", mismatches);
        $display("RAW DECODER SMOKE PASS");
        $finish;
    end
endmodule
