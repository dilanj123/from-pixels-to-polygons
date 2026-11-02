`timescale 1ns/1ps
module buffer_manager_tb #(
    parameter integer SYS_HALF = 5,
    parameter integer PIX_HALF = 7,
    parameter integer PIX_PHASE = 1
);
    logic clk_sys = 0, clk_pix = 0, rst = 1;
    always #(SYS_HALF) clk_sys = ~clk_sys;
    initial begin #(PIX_PHASE); forever #(PIX_HALF) clk_pix = ~clk_pix; end

    logic present_valid, present_ready, renderer_quiescent, readback_active;
    logic [15:0] present_tag;
    logic safe_frame_start;
    logic [1:0] front_sys, render_id, spare_id, front_pix;
    logic front_valid_sys, front_valid_pix, pending, frame_done;
    logic [15:0] frame_done_tag;
    integer accepts, completions, role_errors, early_switches;
    logic [1:0] prior_front_pix;
    logic safe_seen_q;

    buffer_manager dut (
        .clk_sys(clk_sys), .rst_sys(rst), .present_valid(present_valid),
        .present_ready(present_ready), .present_tag(present_tag),
        .renderer_quiescent(renderer_quiescent), .readback_active(readback_active),
        .clk_pix(clk_pix), .rst_pix(rst), .safe_frame_start(safe_frame_start),
        .front_id_sys(front_sys), .render_id(render_id), .spare_id(spare_id),
        .front_id_pix(front_pix), .front_valid_sys(front_valid_sys),
        .front_valid_pix(front_valid_pix), .presentation_pending(pending),
        .frame_done(frame_done), .frame_done_tag(frame_done_tag)
    );

    always @(posedge clk_sys) if (!rst) begin
        if ((front_sys == render_id) || (front_sys == spare_id) || (render_id == spare_id))
            role_errors = role_errors + 1;
        if (dut.mailbox_i.request_pending_sys && dut.mailbox_i.requested_id_sys != render_id)
            role_errors = role_errors + 1;
        if (frame_done) begin
            completions = completions + 1;
            if ((front_sys != front_pix) || frame_done_tag != present_tag)
                role_errors = role_errors + 1;
        end
    end
    always @(posedge clk_pix) if (!rst) begin
        if (front_pix != prior_front_pix && !safe_frame_start && !safe_seen_q)
            early_switches = early_switches + 1;
        prior_front_pix <= front_pix;
        safe_seen_q <= safe_frame_start;
    end

    task automatic issue_present(input logic [15:0] tag);
        begin
            @(negedge clk_sys); present_tag = tag; present_valid = 1;
            while (!present_ready) @(negedge clk_sys);
            @(posedge clk_sys); accepts = accepts + 1;
            @(negedge clk_sys); present_valid = 0;
        end
    endtask

    task automatic pulse_boundary;
        begin
            repeat (2) @(negedge clk_pix);
            safe_frame_start = 1;
            @(negedge clk_pix); safe_frame_start = 0;
        end
    endtask

    task automatic wait_done;
        integer guard;
        begin
            guard = 0;
            while (completions == 0 || pending) begin
                @(posedge clk_sys); guard = guard + 1;
                if (guard > 100) $fatal(1, "presentation timeout");
            end
        end
    endtask

    initial begin
        present_valid=0; present_tag=0; renderer_quiescent=0; readback_active=0;
        safe_frame_start=0; accepts=0; completions=0; role_errors=0; early_switches=0;
        prior_front_pix=0;
        safe_seen_q=0;
        repeat (4) @(posedge clk_sys); rst=0;
        repeat (4) @(posedge clk_sys);
        if (front_sys != 0 || render_id != 1 || spare_id != 2 || front_valid_sys || front_valid_pix)
            $fatal(1, "initial roles/front_valid incorrect");
        renderer_quiescent=1;

        readback_active=1;
        @(negedge clk_sys); present_valid=1; present_tag=16'h1001;
        repeat (4) @(posedge clk_sys);
        if (present_ready || pending) $fatal(1, "presentation accepted during readback lock");
        @(negedge clk_sys); present_valid=0; readback_active=0;

        issue_present(16'h1001);
        repeat (12) @(posedge clk_pix);
        if (front_pix != 0 || completions != 0) $fatal(1, "switch before safe boundary");
        pulse_boundary();
        wait_done();
        if (front_sys != 1 || render_id != 0 || spare_id != 2 || !front_valid_sys || !front_valid_pix)
            $fatal(1, "first NORMAL role swap incorrect");
        if (frame_done_tag != 16'h1001) $fatal(1, "completion tag mismatch");

        // A request arriving just after a safe event must wait for the next one.
        pulse_boundary();
        issue_present(16'h1002);
        repeat (8) @(posedge clk_pix);
        if (front_pix != 1 || completions != 1) $fatal(1, "post-boundary request switched early");
        pulse_boundary();
        wait_done();
        if (front_sys != 0 || render_id != 1 || spare_id != 2)
            $fatal(1, "second NORMAL role swap incorrect");

        // Reset after the pixel side has accepted a request but before its boundary.
        issue_present(16'h1003);
        repeat (10) @(posedge clk_pix);
        rst=1;
        repeat (3) @(posedge clk_sys);
        rst=0;
        repeat (15) @(posedge clk_sys);
        if (front_sys != 0 || render_id != 1 || spare_id != 2 || front_valid_sys ||
            front_pix != 0 || frame_done || pending)
            $fatal(1, "reset left stale presentation state");
        // Let pixel FRONT switch, then asynchronously assert the common reset
        // before the system synchronizer can retire the matching ACK.
        issue_present(16'h1004);
        repeat (12) @(posedge clk_pix);
        pulse_boundary();
        wait(front_pix == 2'd1);
        if (front_sys != 0 || render_id != 1 || completions != 2)
            $fatal(1, "system roles changed before synchronized ACK");
        #1 rst=1;
        repeat (3) @(posedge clk_sys);
        rst=0;
        repeat (12) @(posedge clk_sys);
        if (front_sys != 0 || render_id != 1 || spare_id != 2 || front_valid_sys ||
            front_pix != 0 || frame_done || pending || completions != 2)
            $fatal(1, "reset after pixel switch leaked stale ACK/completion");

        // Reset while the GFX-014 ownership lock is asserted.
        readback_active=1;
        repeat (2) @(posedge clk_sys);
        rst=1;
        repeat (2) @(posedge clk_sys);
        rst=0; readback_active=0;
        repeat (8) @(posedge clk_sys);
        if (front_sys != 0 || render_id != 1 || spare_id != 2 || frame_done || pending)
            $fatal(1, "reset with readback lock did not clear manager state");

        if (accepts != 4 || role_errors || early_switches)
            $fatal(1, "monitor mismatch accepts=%0d roles=%0d early=%0d", accepts, role_errors, early_switches);
        $display("BUFFER MANAGER PASS accepts=%0d completed=%0d role_errors=%0d early_switches=%0d",
                 accepts, completions, role_errors, early_switches);
        $finish;
    end
endmodule
