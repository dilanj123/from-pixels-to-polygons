`timescale 1ns/1ps
module renderer_reset_tb;
    localparam int PIXELS = 76800;
    logic clk = 0, rst = 1;
    always #5 clk = ~clk;
    logic cmd_valid, cmd_ready;
    gfx_pkg::decoded_command_t cmd;
    logic quiescent;
    integer i, stale_writes, clear_fb_count, clear_z_count;

    renderer_core dut (.clk_sys(clk), .rst(rst), .render_cmd_valid(cmd_valid),
                       .render_cmd_ready(cmd_ready), .render_cmd(cmd),
                       .renderer_quiescent(quiescent));

    always @(posedge clk) begin
        if (!rst) begin
            if (dut.clear_owner && dut.clear_fb_we) clear_fb_count = clear_fb_count + 1;
            if (dut.clear_owner && dut.clear_z_we) clear_z_count = clear_z_count + 1;
        end
    end

    task automatic send_begin(input logic [7:0] colour);
        begin
            while (!cmd_ready) @(posedge clk);
            @(negedge clk); cmd = '0; cmd.opcode = gfx_pkg::CMD_BEGIN_FRAME;
            cmd.clear_rgb332 = colour; cmd_valid = 1;
            @(posedge clk); @(negedge clk); cmd_valid = 0;
        end
    endtask

    task automatic send_draw;
        begin
            while (!cmd_ready) @(posedge clk);
            @(negedge clk); cmd = '0; cmd.opcode = gfx_pkg::CMD_DRAW_TRIANGLE;
            cmd.v0_x = 0; cmd.v0_y = 0; cmd.v1_x = 5120; cmd.v1_y = 0;
            cmd.v2_x = 0; cmd.v2_y = 3840;
            cmd.r_start = 8'sd0; cmd.g_start = 8'sd0; cmd.b_start = 8'sd0; cmd.z_start = 8'sd0;
            cmd_valid = 1;
            @(posedge clk); @(negedge clk); cmd_valid = 0;
        end
    endtask

    task automatic wait_q;
        begin
            @(posedge clk);
            while (!quiescent) @(posedge clk);
        end
    endtask

    task automatic check_clear(input logic [7:0] colour);
        begin
            for (i = 0; i < PIXELS; i = i + 1) begin
                if (dut.framebuffer_i.mem[i] !== colour) $fatal(1, "clear fb mismatch addr=%0d", i);
                if (dut.zbuffer_i.mem[i] !== 8'hFF) $fatal(1, "clear z mismatch addr=%0d", i);
            end
        end
    endtask

    initial begin
        cmd_valid = 0; cmd = '0; stale_writes = 0; clear_fb_count = 0; clear_z_count = 0;
        repeat (3) @(posedge clk); rst = 0;

        send_begin(8'h12);
        repeat (100) @(posedge clk);
        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;
        repeat (10) @(posedge clk);
        if (dut.state_q != 0 || dut.clear_busy || dut.walk_busy || !dut.fragment_empty)
            $fatal(1, "reset during clear did not return idle");
        send_begin(8'h5A);
        wait_q();
        check_clear(8'h5A);

        send_draw();
        while (dut.state_q != 4) @(posedge clk);
        repeat (25) @(posedge clk);
        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;
        repeat (10) begin
            @(posedge clk);
            if (dut.clear_owner && (dut.clear_fb_we || dut.clear_z_we)) stale_writes = stale_writes + 1;
            if (dut.fragment_owner && (dut.fragment_i.fb_wr_en || dut.fragment_i.z_wr_en)) stale_writes = stale_writes + 1;
        end
        if (dut.state_q != 0 || stale_writes != 0) $fatal(1, "reset during walk stale/state failure");
        send_begin(8'h3C);
        wait_q();
        check_clear(8'h3C);
        $display("RENDERER RESET PASS clear_fb=%0d clear_z=%0d stale_writes=%0d", clear_fb_count, clear_z_count, stale_writes);
        $finish;
    end
endmodule
