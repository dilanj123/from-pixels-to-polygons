`timescale 1ns/1ps
module graphics_system_tb;
    logic clk_sys = 0, clk_pix = 0, rst = 1;
    always #3 clk_sys = ~clk_sys;
    always #2 clk_pix = ~clk_pix;
    logic cmd_valid = 0, cmd_ready;
    gfx_pkg::decoded_command_t cmd;
    logic frame_done, present_ack, front_valid_sys, front_valid_pix, active_video;
    logic [1:0] front_id_sys, render_id, spare_id;
    logic [7:0] red, green, blue;
    logic hsync, vsync;
    integer write_invariant_failures = 0;

    always @(posedge clk_sys) begin
        if (!rst && !dut.rst_sys && dut.renderer_i.render_fb_wr_en) begin
            if ((dut.renderer_i.render_fb_wr_addr === 17'hx) ||
                (dut.render_id == dut.front_id_sys) || (dut.render_id == dut.spare_id))
                write_invariant_failures = write_invariant_failures + 1;
        end
    end

    graphics_system dut (
        .clk_sys(clk_sys), .clk_pix(clk_pix), .rst(rst),
        .render_cmd_valid(cmd_valid), .render_cmd_ready(cmd_ready), .render_cmd(cmd),
        .frame_done(frame_done), .present_ack(present_ack),
        .front_id_sys(front_id_sys), .render_id(render_id), .spare_id(spare_id),
        .front_valid_sys(front_valid_sys), .front_valid_pix(front_valid_pix),
        .red(red), .green(green), .blue(blue), .hsync(hsync), .vsync(vsync),
        .active_video(active_video)
    );

    task automatic send_simple(input logic [3:0] opcode, input logic [7:0] clear);
        begin
            while (!cmd_ready) @(posedge clk_sys);
            @(negedge clk_sys);
            cmd = '0;
            cmd.opcode = opcode;
            cmd.clear_rgb332 = clear;
            cmd_valid = 1'b1;
            @(posedge clk_sys);
            @(negedge clk_sys);
            cmd_valid = 1'b0;
        end
    endtask

    task automatic wait_done;
        integer guard;
        begin
            guard = 0;
            while (!frame_done) begin
                @(posedge clk_sys);
                guard = guard + 1;
                if (guard > 1000000) begin
                    $display("timeout ready=%b mgr_ready=%b pending=%b frame=%b req=%b ack=%b rst_sys=%b rst_pix=%b state=%0d", cmd_ready, dut.normal_present_ready, dut.manager_i.presentation_pending, dut.scan_frame, dut.manager_i.request_toggle_sys, dut.manager_i.ack_toggle_pix, dut.rst_sys, dut.rst_pix, dut.renderer_i.state_q);
                    $fatal(1, "NORMAL presentation timeout");
                end
            end
        end
    endtask

    initial begin
        cmd = '0;
        repeat (4) @(posedge clk_sys);
        rst = 0;
        send_simple(gfx_pkg::CMD_BEGIN_FRAME, 8'h1c);
        $display("after BEGIN state=%0d ready=%b rst_sys=%b", dut.renderer_i.state_q, cmd_ready, dut.rst_sys);
        send_simple(gfx_pkg::CMD_PRESENT, 8'h00);
        wait_done();
        #1;
        if (front_id_sys !== 2'd1 || render_id !== 2'd0 || spare_id !== 2'd2 ||
            !front_valid_sys || !front_valid_pix)
            $fatal(1, "first NORMAL frame roles invalid");
        if (dut.g_fb[1].framebuffer_i.mem[0] !== 8'h1c)
            $fatal(1, "first rendered buffer did not retain distinct clear data");

        send_simple(gfx_pkg::CMD_BEGIN_FRAME, 8'he3);
        send_simple(gfx_pkg::CMD_PRESENT, 8'h00);
        wait_done();
        #1;
        if (front_id_sys !== 2'd0 || render_id !== 2'd1 || spare_id !== 2'd2)
            $fatal(1, "second NORMAL frame roles invalid");
        $display("buffers after second: b0=%02x b1=%02x roles=%0d/%0d/%0d", dut.g_fb[0].framebuffer_i.mem[0], dut.g_fb[1].framebuffer_i.mem[0], front_id_sys, render_id, spare_id);
        if (dut.g_fb[0].framebuffer_i.mem[0] !== 8'he3 ||
            dut.g_fb[1].framebuffer_i.mem[0] !== 8'h1c)
            $fatal(1, "multi-frame physical buffers are not distinct");
        if (write_invariant_failures != 0)
            $fatal(1, "renderer write ownership invariant failed");
        wait (active_video);
        #1;
        if ({red, green, blue} !== 24'hff00ff)
            $fatal(1, "scanout did not select the second distinct front frame");
        $display("PASS graphics_system_tb: two renderer-produced NORMAL frames presented through three physical buffers");
        $finish;
    end
endmodule
