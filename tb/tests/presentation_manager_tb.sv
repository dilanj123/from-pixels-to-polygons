`timescale 1ns/1ps
module presentation_manager_tb;
    logic clk_sys = 0, clk_pix = 0, rst = 1;
    integer sys_tick = 0, pix_tick = 0;
    initial forever begin #(3 + (sys_tick % 4)); clk_sys = ~clk_sys; sys_tick = sys_tick + 1; end
    initial forever begin #(2 + (pix_tick % 5)); clk_pix = ~clk_pix; pix_tick = pix_tick + 1; end
    logic present_valid = 0, renderer_quiescent = 1, readback_active = 0;
    logic pix_frame_boundary = 0;
    logic present_ready, frame_done, present_ack, front_valid_sys;
    logic presentation_pending, front_valid_pix;
    logic [1:0] front_id_sys, render_id, spare_id, front_id_pix;
    integer boundary_count;
    integer invariant_failures;
    logic [1:0] held_payload;
    logic held_payload_valid;

    always @(posedge clk_sys) begin
        if (!rst && !dut.rst_sys) begin
            if ((front_id_sys == render_id) || (front_id_sys == spare_id) || (render_id == spare_id)) begin
                $display("role invariant failure at %0t", $time);
                invariant_failures = invariant_failures + 1;
            end
            if (presentation_pending && held_payload_valid && (dut.request_id_sys !== held_payload)) begin
                $display("mailbox payload changed while pending at %0t", $time);
                invariant_failures = invariant_failures + 1;
            end
            if (presentation_pending) begin
                held_payload <= dut.request_id_sys;
                held_payload_valid <= 1'b1;
            end else begin
                held_payload_valid <= 1'b0;
            end
        end
    end

    presentation_manager dut (
        .clk_sys(clk_sys), .clk_pix(clk_pix), .rst(rst),
        .present_valid(present_valid), .present_ready(present_ready),
        .renderer_quiescent(renderer_quiescent), .readback_active(readback_active),
        .frame_done(frame_done), .present_ack(present_ack),
        .front_id_sys(front_id_sys), .render_id(render_id), .spare_id(spare_id),
        .front_valid_sys(front_valid_sys), .presentation_pending(presentation_pending),
        .pix_frame_boundary(pix_frame_boundary), .front_id_pix(front_id_pix),
        .front_valid_pix(front_valid_pix)
    );

    task automatic boundary;
        begin
            @(negedge clk_pix); pix_frame_boundary = 1'b1;
            @(negedge clk_pix); pix_frame_boundary = 1'b0;
            boundary_count = boundary_count + 1;
        end
    endtask

    initial begin
        boundary_count = 0;
        invariant_failures = 0;
        held_payload = 0;
        held_payload_valid = 0;
        repeat (3) @(posedge clk_sys);
        rst = 0;
        wait (present_ready);
        #1;
        if (front_id_sys !== 0 || render_id !== 1 || spare_id !== 2 ||
            front_valid_sys || front_valid_pix || !present_ready)
            $fatal(1, "bad reset roles/valid state");

        @(negedge clk_sys); present_valid = 1;
        @(posedge clk_sys); #1;
        if (dut.request_id_sys !== render_id) $fatal(1, "mailbox payload not captured with request");
        @(negedge clk_sys); present_valid = 0;
        if (!presentation_pending) $fatal(1, "request was not accepted");
        if (present_ready) $fatal(1, "second request accepted while pending");
        repeat (4) @(posedge clk_pix);
        if (front_id_pix !== 0 || front_valid_pix) $fatal(1, "front switched before boundary");
        repeat (4) boundary();
        #1;
        if (front_id_pix !== 1 || front_id_sys !== 1 || render_id !== 0 ||
            spare_id !== 2 || !front_valid_sys || !front_valid_pix)
            $fatal(1, "first rotation/ack incorrect");
        @(posedge clk_sys); #1;
        if (frame_done || present_ack) $fatal(1, "ack/frame_done not one-cycle pulses");

        readback_active = 1;
        @(negedge clk_sys); present_valid = 1;
        @(negedge clk_sys); present_valid = 0;
        if (present_ready || presentation_pending) $fatal(1, "readback lock did not block presentation");
        readback_active = 0;

        // Boundary-adjacent request: acceptance immediately before a boundary.
        @(negedge clk_sys); present_valid = 1;
        @(posedge clk_sys); #1;
        if (dut.request_id_sys !== render_id) $fatal(1, "second mailbox payload mismatch");
        @(negedge clk_sys); present_valid = 0;
        if (!presentation_pending) $fatal(1, "second request was not accepted");
        boundary();
        // Reset while the request is pending and near the safe boundary.
        rst = 1;
        repeat (3) @(posedge clk_sys);
        if (presentation_pending || front_valid_sys || front_valid_pix ||
            front_id_sys !== 0 || render_id !== 1 || spare_id !== 2)
            $fatal(1, "pending/boundary reset did not clear state");
        rst = 0;
        wait (present_ready);
        // Reset after a completed switch is covered by this fresh post-reset
        // request and its boundary; no stale ACK may be emitted.
        @(negedge clk_sys); present_valid = 1;
        @(negedge clk_sys); present_valid = 0;
        repeat (4) boundary();
        #1;
        if (front_id_sys !== 1 || render_id !== 0 || spare_id !== 2 || invariant_failures != 0)
            $fatal(1, "post-reset rotation/invariant incorrect");
        rst = 1;
        repeat (2) @(posedge clk_pix);
        if (front_valid_pix) $fatal(1, "reset after switch did not clear pixel FRONT");
        rst = 0;
        $display("PASS presentation_manager_tb: randomized unrelated clocks, boundary-adjacent requests, payload stability, readback lock, reset pending/boundary/after-switch, unique roles");
        $finish;
    end
endmodule
