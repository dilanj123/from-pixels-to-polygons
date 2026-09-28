module perf_counters (
    input  logic                         clk_sys,
    input  logic                         rst,
    input  logic                         begin_frame_event,
    input  logic                         triangle_submitted_event,
    input  logic                         triangle_degenerate_event,
    input  logic                         triangle_backface_event,
    input  logic                         candidate_retired_event,
    input  logic                         covered_fragment_event,
    input  logic                         depth_result_valid,
    input  logic                         depth_pass,
    input  logic                         clear_cycle,
    input  logic                         render_cycle,
    input  logic                         triangle_setup_cycle,
    input  logic                         frame_completed_event,
    input  logic                         present_wait_cycle,
    input  logic                         sobel_cycle,
    input  logic [10:0]                  command_fifo_level,
    output gfx_pkg::performance_counters_t counters
);
    logic [31:0] frames_completed_q, triangles_submitted_q;
    logic [31:0] triangles_degenerate_q, triangles_backface_rejected_q;
    logic [31:0] candidate_pixels_q, covered_fragments_q;
    logic [31:0] z_pass_q, z_fail_q, clear_cycles_q, render_cycles_q;
    logic [31:0] triangle_setup_cycles_q, present_wait_cycles_q, sobel_cycles_q;
    logic [31:0] command_fifo_high_watermark_q;
    logic [31:0] fifo_level_ext;

    assign fifo_level_ext = {21'd0, command_fifo_level};
    always_comb begin
        counters.frames_completed            = frames_completed_q;
        counters.triangles_submitted         = triangles_submitted_q;
        counters.triangles_degenerate        = triangles_degenerate_q;
        counters.triangles_backface_rejected = triangles_backface_rejected_q;
        counters.candidate_pixels            = candidate_pixels_q;
        counters.covered_fragments           = covered_fragments_q;
        counters.z_pass                      = z_pass_q;
        counters.z_fail                      = z_fail_q;
        counters.clear_cycles                = clear_cycles_q;
        counters.render_cycles               = render_cycles_q;
        counters.triangle_setup_cycles       = triangle_setup_cycles_q;
        counters.present_wait_cycles         = present_wait_cycles_q;
        counters.sobel_cycles                = sobel_cycles_q;
        counters.command_fifo_high_watermark = command_fifo_high_watermark_q;
    end

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            frames_completed_q            <= 32'd0;
            triangles_submitted_q         <= 32'd0;
            triangles_degenerate_q        <= 32'd0;
            triangles_backface_rejected_q <= 32'd0;
            candidate_pixels_q            <= 32'd0;
            covered_fragments_q           <= 32'd0;
            z_pass_q                      <= 32'd0;
            z_fail_q                      <= 32'd0;
            clear_cycles_q                <= 32'd0;
            render_cycles_q               <= 32'd0;
            triangle_setup_cycles_q       <= 32'd0;
            present_wait_cycles_q         <= 32'd0;
            sobel_cycles_q                <= 32'd0;
            command_fifo_high_watermark_q <= 32'd0;
        end else begin
            if (frame_completed_event)
                frames_completed_q <= frames_completed_q + 32'd1;
            if (fifo_level_ext > command_fifo_high_watermark_q)
                command_fifo_high_watermark_q <= fifo_level_ext;

            if (begin_frame_event) begin
                triangles_submitted_q         <= 32'd0;
                triangles_degenerate_q        <= 32'd0;
                triangles_backface_rejected_q <= 32'd0;
                candidate_pixels_q            <= 32'd0;
                covered_fragments_q           <= 32'd0;
                z_pass_q                      <= 32'd0;
                z_fail_q                      <= 32'd0;
                clear_cycles_q                <= 32'd0;
                render_cycles_q               <= 32'd0;
                triangle_setup_cycles_q       <= 32'd0;
                present_wait_cycles_q         <= 32'd0;
                sobel_cycles_q                <= 32'd0;
            end else begin
                if (triangle_submitted_event) triangles_submitted_q <= triangles_submitted_q + 32'd1;
                if (triangle_degenerate_event) triangles_degenerate_q <= triangles_degenerate_q + 32'd1;
                if (triangle_backface_event) triangles_backface_rejected_q <= triangles_backface_rejected_q + 32'd1;
                if (candidate_retired_event) candidate_pixels_q <= candidate_pixels_q + 32'd1;
                if (covered_fragment_event) covered_fragments_q <= covered_fragments_q + 32'd1;
                if (depth_result_valid) begin
                    if (depth_pass) z_pass_q <= z_pass_q + 32'd1;
                    else z_fail_q <= z_fail_q + 32'd1;
                end
                if (clear_cycle) clear_cycles_q <= clear_cycles_q + 32'd1;
                if (render_cycle) render_cycles_q <= render_cycles_q + 32'd1;
                if (triangle_setup_cycle) triangle_setup_cycles_q <= triangle_setup_cycles_q + 32'd1;
                if (present_wait_cycle) present_wait_cycles_q <= present_wait_cycles_q + 32'd1;
                if (sobel_cycle) sobel_cycles_q <= sobel_cycles_q + 32'd1;
            end
        end
    end
endmodule
