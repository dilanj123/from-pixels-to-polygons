`timescale 1ns/1ps
module renderer_counter_tb;
    localparam int PIXELS = 76800;
    logic clk = 0, rst = 1;
    always #5 clk = ~clk;

    logic render_cmd_valid, render_cmd_ready;
    gfx_pkg::decoded_command_t render_cmd;
    logic frame_completed_event, present_wait_cycle, sobel_cycle;
    logic [10:0] command_fifo_level;
    gfx_pkg::performance_counters_t perf_counters;
    logic renderer_quiescent;
    integer event_candidates, event_covered, event_pass, event_fail;
    integer event_clear, event_render, event_setup, event_submitted;
    integer event_degenerate, event_backface;

    renderer_core dut (
        .clk_sys(clk), .rst(rst), .render_cmd_valid(render_cmd_valid),
        .render_cmd_ready(render_cmd_ready), .render_cmd(render_cmd),
        .frame_completed_event(frame_completed_event),
        .present_wait_cycle(present_wait_cycle), .sobel_cycle(sobel_cycle),
        .command_fifo_level(command_fifo_level), .perf_counters(perf_counters),
        .renderer_quiescent(renderer_quiescent)
    );

    always @(posedge clk) begin
        if (!rst) begin
            if (dut.triangle_submitted_event) event_submitted = event_submitted + 1;
            if (dut.triangle_degenerate_event) event_degenerate = event_degenerate + 1;
            if (dut.triangle_backface_event) event_backface = event_backface + 1;
            if (dut.candidate_retired) event_candidates = event_candidates + 1;
            if (dut.covered_fragment_event) event_covered = event_covered + 1;
            if (dut.depth_result_valid) begin
                if (dut.depth_pass) event_pass = event_pass + 1;
                else event_fail = event_fail + 1;
            end
            if (dut.clear_cycle) event_clear = event_clear + 1;
            if (dut.render_cycle) event_render = event_render + 1;
            if (dut.triangle_setup_cycle) event_setup = event_setup + 1;
        end
    end

    task automatic send_command(input gfx_pkg::decoded_command_t command);
        begin
            while (!render_cmd_ready) @(posedge clk);
            @(negedge clk); render_cmd = command; render_cmd_valid = 1;
            @(posedge clk); @(negedge clk); render_cmd_valid = 0;
        end
    endtask

    function automatic gfx_pkg::decoded_command_t make_draw(
        input logic [15:0] tag,
        input logic [12:0] x0, input logic [12:0] y0,
        input logic [12:0] x1, input logic [12:0] y1,
        input logic [12:0] x2, input logic [12:0] y2,
        input logic signed [31:0] z
    );
        gfx_pkg::decoded_command_t c;
        begin
            c = '0; c.opcode = gfx_pkg::CMD_DRAW_TRIANGLE; c.tag = tag;
            c.v0_x=x0; c.v0_y=y0; c.v1_x=x1; c.v1_y=y1; c.v2_x=x2; c.v2_y=y2;
            c.r_start=0; c.g_start=0; c.b_start=0; c.z_start=z;
            make_draw = c;
        end
    endfunction

    function automatic gfx_pkg::decoded_command_t make_begin_frame;
        gfx_pkg::decoded_command_t c;
        begin
            c = '0;
            c.opcode = gfx_pkg::CMD_BEGIN_FRAME;
            c.tag = 16'h1000;
            c.clear_rgb332 = 8'hA5;
            make_begin_frame = c;
        end
    endfunction

    initial begin
        render_cmd_valid = 0; render_cmd = '0;
        frame_completed_event = 0; present_wait_cycle = 0; sobel_cycle = 0;
        command_fifo_level = 0;
        event_candidates=0; event_covered=0; event_pass=0; event_fail=0;
        event_clear=0; event_render=0; event_setup=0; event_submitted=0;
        event_degenerate=0; event_backface=0;
        repeat (3) @(posedge clk); rst = 0;
        command_fifo_level = 11'd1024;

        send_command(make_begin_frame());
        while (!renderer_quiescent) @(posedge clk);

        send_command(make_draw(16'h2000, 13'd0, 13'd0, 13'd32, 13'd0, 13'd0, 13'd32, 32'sd2560));
        send_command(make_draw(16'h2001, 13'd0, 13'd0, 13'd16, 13'd0, 13'd32, 13'd0, 32'sd2560));
        send_command(make_draw(16'h2002, 13'd0, 13'd0, 13'd0, 13'd32, 13'd32, 13'd0, 32'sd2560));
        send_command(make_draw(16'h2003, 13'd7, 13'd7, 13'd8, 13'd7, 13'd7, 13'd8, 32'sd2560));
        send_command(make_draw(16'h2004, 13'd0, 13'd0, 13'd32, 13'd0, 13'd0, 13'd32, 32'sd2560));
        while (!renderer_quiescent) @(posedge clk);

        frame_completed_event = 1; present_wait_cycle = 1; sobel_cycle = 1;
        @(posedge clk); frame_completed_event = 0; present_wait_cycle = 0; sobel_cycle = 0;
        @(posedge clk);

        if (perf_counters.frames_completed !== 1 || perf_counters.triangles_submitted !== 5 ||
            perf_counters.triangles_degenerate !== 1 || perf_counters.triangles_backface_rejected !== 1 ||
            perf_counters.candidate_pixels !== 9 || perf_counters.covered_fragments !== 2 ||
            perf_counters.z_pass !== 1 || perf_counters.z_fail !== 1 ||
            perf_counters.clear_cycles !== 76800 || perf_counters.command_fifo_high_watermark !== 1024)
            $fatal(1, "integrated counter mismatch sub=%0d deg=%0d back=%0d cand=%0d cov=%0d pass=%0d fail=%0d clear=%0d wm=%0d",
                   perf_counters.triangles_submitted, perf_counters.triangles_degenerate,
                   perf_counters.triangles_backface_rejected, perf_counters.candidate_pixels,
                   perf_counters.covered_fragments, perf_counters.z_pass, perf_counters.z_fail,
                   perf_counters.clear_cycles, perf_counters.command_fifo_high_watermark);
        if (perf_counters.render_cycles !== event_render ||
            perf_counters.triangle_setup_cycles !== event_setup ||
            event_submitted != 5 || event_degenerate != 1 || event_backface != 1 ||
            event_candidates != 9 || event_covered != 2 || event_pass != 1 || event_fail != 1 ||
            event_clear != 76800)
            $fatal(1, "event scoreboard mismatch");
        if (perf_counters.triangle_setup_cycles > perf_counters.render_cycles)
            $fatal(1, "setup cycles exceed render cycles");
        $display("RENDERER COUNTERS PASS submitted=%0d candidates=%0d covered=%0d pass=%0d fail=%0d render=%0d setup=%0d",
                 perf_counters.triangles_submitted, perf_counters.candidate_pixels,
                 perf_counters.covered_fragments, perf_counters.z_pass, perf_counters.z_fail,
                 perf_counters.render_cycles, perf_counters.triangle_setup_cycles);
        $finish;
    end
endmodule
