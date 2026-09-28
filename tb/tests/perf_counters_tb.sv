`timescale 1ns/1ps
module perf_counters_tb;
    logic clk_sys = 0, rst = 1;
    always #5 clk_sys = ~clk_sys;

    logic begin_frame_event, triangle_submitted_event, triangle_degenerate_event;
    logic triangle_backface_event, candidate_retired_event, covered_fragment_event;
    logic depth_result_valid, depth_pass, clear_cycle, render_cycle, triangle_setup_cycle;
    logic frame_completed_event, present_wait_cycle, sobel_cycle;
    logic [10:0] command_fifo_level;
    gfx_pkg::performance_counters_t counters;

    perf_counters dut (.*);

    task automatic cycle;
        begin @(posedge clk_sys); #1; end
    endtask

    task automatic clear_events;
        begin
            begin_frame_event = 0; triangle_submitted_event = 0;
            triangle_degenerate_event = 0; triangle_backface_event = 0;
            candidate_retired_event = 0; covered_fragment_event = 0;
            depth_result_valid = 0; depth_pass = 0; clear_cycle = 0;
            render_cycle = 0; triangle_setup_cycle = 0;
            frame_completed_event = 0; present_wait_cycle = 0; sobel_cycle = 0;
        end
    endtask

    task automatic expect_zero_per_frame;
        begin
            if (counters.triangles_submitted !== 0 || counters.triangles_degenerate !== 0 ||
                counters.triangles_backface_rejected !== 0 || counters.candidate_pixels !== 0 ||
                counters.covered_fragments !== 0 || counters.z_pass !== 0 || counters.z_fail !== 0 ||
                counters.clear_cycles !== 0 || counters.render_cycles !== 0 ||
                counters.triangle_setup_cycles !== 0 || counters.present_wait_cycles !== 0 ||
                counters.sobel_cycles !== 0)
                $fatal(1, "per-frame counters were not cleared");
        end
    endtask

    initial begin
        command_fifo_level = 0;
        clear_events();
        repeat (2) @(posedge clk_sys);
        rst = 0;
        cycle();
        if (counters !== '0) $fatal(1, "reset did not clear counters");

        frame_completed_event = 1;
        triangle_submitted_event = 1;
        triangle_degenerate_event = 1;
        triangle_backface_event = 1;
        candidate_retired_event = 1;
        covered_fragment_event = 1;
        depth_result_valid = 1; depth_pass = 1;
        clear_cycle = 1; render_cycle = 1; triangle_setup_cycle = 1;
        present_wait_cycle = 1; sobel_cycle = 1;
        command_fifo_level = 11'd17;
        cycle();
        if (counters.frames_completed !== 32'd1 || counters.command_fifo_high_watermark !== 32'd17)
            $fatal(1, "lifetime event mismatch");
        if (counters.triangles_submitted !== 32'd1 || counters.z_pass !== 32'd1)
            $fatal(1, "initial per-frame event mismatch");

        clear_events();
        command_fifo_level = 11'd0;
        triangle_submitted_event = 1; triangle_degenerate_event = 1;
        triangle_backface_event = 1; candidate_retired_event = 1;
        covered_fragment_event = 1; depth_result_valid = 1; depth_pass = 0;
        clear_cycle = 1; render_cycle = 1; triangle_setup_cycle = 1;
        present_wait_cycle = 1; sobel_cycle = 1;
        command_fifo_level = 11'd1024;
        cycle();
        if (counters.triangles_submitted !== 2 || counters.triangles_degenerate !== 2 ||
            counters.triangles_backface_rejected !== 2 || counters.candidate_pixels !== 2 ||
            counters.covered_fragments !== 2 || counters.z_pass !== 1 || counters.z_fail !== 1 ||
            counters.clear_cycles !== 2 || counters.render_cycles !== 2 ||
            counters.triangle_setup_cycles !== 2 || counters.present_wait_cycles !== 2 ||
            counters.sobel_cycles !== 2 || counters.command_fifo_high_watermark !== 1024)
            $fatal(1, "event increment mismatch");

        clear_events();
        begin_frame_event = 1;
        triangle_submitted_event = 1; triangle_degenerate_event = 1;
        triangle_backface_event = 1; candidate_retired_event = 1;
        covered_fragment_event = 1; depth_result_valid = 1; depth_pass = 1;
        clear_cycle = 1; render_cycle = 1; triangle_setup_cycle = 1;
        present_wait_cycle = 1; sobel_cycle = 1;
        cycle();
        expect_zero_per_frame();
        if (counters.frames_completed !== 32'd1 || counters.command_fifo_high_watermark !== 32'd1024)
            $fatal(1, "BEGIN_FRAME cleared lifetime counter");

        clear_events();
        frame_completed_event = 1; command_fifo_level = 11'd4;
        cycle();
        if (counters.frames_completed !== 32'd2) $fatal(1, "frame counter mismatch");

        force dut.triangles_submitted_q = 32'hfffffffe;
        release dut.triangles_submitted_q;
        triangle_submitted_event = 1; cycle();
        if (counters.triangles_submitted !== 32'hffffffff) $fatal(1, "counter did not reach FFFFFFFF");
        triangle_submitted_event = 1; cycle();
        if (counters.triangles_submitted !== 32'h00000000) $fatal(1, "counter did not wrap");

        force dut.frames_completed_q = 32'hfffffffe;
        release dut.frames_completed_q;
        frame_completed_event = 1; cycle();
        if (counters.frames_completed !== 32'hffffffff) $fatal(1, "frame counter did not reach FFFFFFFF");
        frame_completed_event = 1; cycle();
        if (counters.frames_completed !== 32'h00000000) $fatal(1, "frame counter did not wrap");

        $display("PERF COUNTERS PASS watermark=%0d frames=%0d", counters.command_fifo_high_watermark, counters.frames_completed);
        $finish;
    end
endmodule
