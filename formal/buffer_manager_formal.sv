module buffer_manager_formal;
    (* gclk *) logic clk;
    logic rst, present_valid, present_sobel, renderer_quiescent, readback_active;
    logic safe_frame_start;
    logic [15:0] present_tag;
    logic present_ready, front_valid_sys, front_valid_pix, pending, present_wait;
    logic [1:0] front_sys, render_id, spare_id, front_pix;
    logic frame_done;
    logic [15:0] frame_done_tag;
    logic past_valid, outstanding;
    logic [1:0] requested_front;
    logic [15:0] requested_tag;

    buffer_manager dut (
        .clk_sys(clk), .rst_sys(rst), .present_valid(present_valid),
        .present_ready(present_ready), .present_sobel(present_sobel),
        .present_tag(present_tag), .renderer_quiescent(renderer_quiescent),
        .readback_active(readback_active), .clk_pix(clk), .rst_pix(rst),
        .safe_frame_start(safe_frame_start), .front_id_sys(front_sys),
        .render_id(render_id), .spare_id(spare_id), .front_id_pix(front_pix),
        .front_valid_sys(front_valid_sys), .front_valid_pix(front_valid_pix),
        .presentation_pending(pending), .present_wait_cycle(present_wait),
        .frame_done(frame_done), .frame_done_tag(frame_done_tag)
    );

    initial begin
        past_valid = 0;
        outstanding = 0;
        requested_front = 0;
        requested_tag = 0;
        assume(rst);
    end

    always_ff @(posedge clk) begin
        if (!past_valid) begin past_valid<=1; assume(rst); end
        else assume(!rst);
        if (rst) begin
            outstanding <= 0;
            requested_front <= 0;
            requested_tag <= 0;
            assert(front_sys == 0 && render_id == 1 && spare_id == 2);
            assert(!front_valid_sys && !pending);
        end else begin
            assert(front_sys <= 2 && render_id <= 2 && spare_id <= 2);
            assert(front_sys != render_id && front_sys != spare_id && render_id != spare_id);
            if (readback_active) assert(!present_ready);
            if (past_valid && front_pix != $past(front_pix)) assert($past(safe_frame_start));
            if (present_valid && present_ready) begin
                assert(!outstanding || frame_done);
                requested_front <= present_sobel ? spare_id : render_id;
                requested_tag <= present_tag;
            end
            if (frame_done) begin
                assert(outstanding);
                assert(front_sys == requested_front);
                assert(frame_done_tag == requested_tag);
                outstanding <= 0;
            end
            if (present_valid && present_ready) outstanding <= 1;
            if (past_valid && front_sys != $past(front_sys)) assert($past(outstanding));
            if (present_wait) assert(pending);
        end
        cover(frame_done);
    end
endmodule
