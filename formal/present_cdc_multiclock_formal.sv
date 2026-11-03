module present_cdc_multiclock_formal;
    (* gclk *) logic global_step;
    (* anyseq *) logic clk_sys;
    (* anyseq *) logic clk_pix;
    (* anyseq *) logic arst_next;
    logic arst = 1'b1;
    logic [1:0] rst_sys_pipe = 2'b11, rst_pix_pipe = 2'b11;
    wire rst_sys = rst_sys_pipe[1];
    wire rst_pix = rst_pix_pipe[1];
    (* anyseq *) logic present_valid, present_sobel, renderer_quiescent;
    (* anyseq *) logic readback_active, safe_frame_start;
    (* anyseq *) logic [15:0] present_tag;

    logic present_ready, front_valid_sys, front_valid_pix, pending, present_wait;
    logic [1:0] front_sys, render_id, spare_id, front_pix;
    logic frame_done;
    logic [15:0] frame_done_tag;
    logic past_sys=0, past_pix=0, outstanding=0;
    logic [1:0] expected_front=0;
    logic [15:0] expected_tag=0;
    logic expected_sobel=0;
    logic accepted_any=0, pixel_switched=0, completed_any=0;
    logic [1:0] old_front_sys, old_render_sys, old_spare_sys;
    (* anyseq *) logic mailbox_req_valid;
    (* anyseq *) logic [1:0] mailbox_req_id;
    logic mailbox_req_ready, mailbox_ack, mailbox_pending, mailbox_front_valid;
    logic [1:0] mailbox_front_id;
    logic mailbox_outstanding=0, mailbox_accepted=0, mailbox_ack_seen=0;
    logic [1:0] mailbox_expected_id=0;
    logic mailbox_pixel_switched=0;

    buffer_manager dut (
        .clk_sys(clk_sys), .rst_sys(rst_sys), .present_valid(present_valid),
        .present_ready(present_ready), .present_sobel(present_sobel),
        .present_tag(present_tag), .renderer_quiescent(renderer_quiescent),
        .readback_active(readback_active), .clk_pix(clk_pix), .rst_pix(rst_pix),
        .safe_frame_start(safe_frame_start), .front_id_sys(front_sys),
        .render_id(render_id), .spare_id(spare_id), .front_id_pix(front_pix),
        .front_valid_sys(front_valid_sys), .front_valid_pix(front_valid_pix),
        .presentation_pending(pending), .present_wait_cycle(present_wait),
        .frame_done(frame_done), .frame_done_tag(frame_done_tag)
    );

    present_cdc mailbox_dut (
        .clk_sys(clk_sys), .rst_sys(rst_sys), .request_valid(mailbox_req_valid),
        .request_ready(mailbox_req_ready), .request_front_id(mailbox_req_id),
        .acknowledge(mailbox_ack), .clk_pix(clk_pix), .rst_pix(rst_pix),
        .safe_frame_start(safe_frame_start), .front_id_pix(mailbox_front_id),
        .front_valid_pix(mailbox_front_valid), .request_pending_sys(mailbox_pending)
    );

    // One common asynchronous assertion with independently synchronized
    // release in each clock domain, matching the documented reset contract.
    always @(posedge global_step) arst <= arst_next;
    always_ff @(posedge clk_sys or posedge arst) begin
        if (arst) rst_sys_pipe <= 2'b11;
        else rst_sys_pipe <= {rst_sys_pipe[0],1'b0};
    end
    always_ff @(posedge clk_pix or posedge arst) begin
        if (arst) rst_pix_pipe <= 2'b11;
        else rst_pix_pipe <= {rst_pix_pipe[0],1'b0};
    end

    // Clock inputs are separate symbolic traces at global formal time steps.
    // Exclude exact coincident rising edges to select interleaved event orders;
    // no frequency lock or phase relation is imposed.
    always @(posedge global_step) begin
        if ($initstate) begin
            assume(!clk_sys && !clk_pix);
            assume(arst);
        end else
            assume(!(clk_sys && !$past(clk_sys) && clk_pix && !$past(clk_pix)));
    end

    always @(posedge clk_sys) begin
        past_sys <= 1'b1;
        if (rst_sys) begin
            outstanding <= 1'b0;
            accepted_any <= 1'b0;
            completed_any <= 1'b0;
            expected_front <= 0;
            expected_tag <= 0;
        end else begin
            if (present_ready && readback_active) assert(1'b0);
            if (frame_done) begin
                assert(outstanding);
                assert(front_sys == expected_front);
                assert(frame_done_tag == expected_tag);
                if (expected_sobel) begin
                    assert(render_id == old_front_sys);
                    assert(spare_id == old_render_sys);
                end else begin
                    assert(render_id == old_front_sys);
                    assert(spare_id == old_spare_sys);
                end
                outstanding <= 1'b0;
                completed_any <= 1'b1;
            end
            if (present_valid && present_ready) begin
                assert(!outstanding || frame_done);
                expected_front <= present_sobel ? spare_id : render_id;
                expected_tag <= present_tag;
                expected_sobel <= present_sobel;
                old_front_sys <= front_sys;
                old_render_sys <= render_id;
                old_spare_sys <= spare_id;
                outstanding <= 1'b1;
                accepted_any <= 1'b1;
            end
            if (past_sys && front_sys != $past(front_sys)) begin
                assert(outstanding);
                assert(front_pix == expected_front && front_valid_pix);
            end
            if (outstanding && pending && front_sys == old_front_sys)
                assert(render_id == old_render_sys && spare_id == old_spare_sys);
            if (outstanding && front_sys != old_front_sys) assert(front_sys == expected_front);
        end
    end

    always @(posedge clk_pix) begin
        past_pix <= 1'b1;
        if (rst_pix) begin
            pixel_switched <= 1'b0;
        end else if (past_pix && front_pix != $past(front_pix)) begin
            assert($past(safe_frame_start));
            pixel_switched <= 1'b1;
        end
        if (!rst_pix && past_pix && mailbox_front_id != $past(mailbox_front_id)) begin
            assert($past(safe_frame_start));
            mailbox_pixel_switched <= 1'b1;
        end
    end

    always @(posedge clk_sys) begin
        if (rst_sys) begin
            mailbox_outstanding <= 1'b0;
            mailbox_expected_id <= 0;
            mailbox_accepted <= 1'b0;
            mailbox_ack_seen <= 1'b0;
        end else begin
            if (mailbox_ack) begin
                assert(mailbox_outstanding);
                assert(mailbox_front_valid);
                assert(mailbox_front_id == mailbox_expected_id);
                mailbox_outstanding <= 1'b0;
                mailbox_ack_seen <= 1'b1;
            end
            if (mailbox_req_valid && mailbox_req_ready) begin
                assert(!mailbox_outstanding || mailbox_ack);
                mailbox_outstanding <= 1'b1;
                mailbox_expected_id <= mailbox_req_id;
                mailbox_accepted <= 1'b1;
            end
        end
    end

    always @(*) begin
        if (!rst_sys && !rst_pix) begin
            assert(front_sys <= 2 && render_id <= 2 && spare_id <= 2);
            assert(front_sys != render_id && front_sys != spare_id && render_id != spare_id);
            if (readback_active) assert(!present_ready);
        end
        cover(accepted_any);
        cover(pixel_switched);
        cover(completed_any);
        cover(mailbox_accepted);
        cover(mailbox_pixel_switched);
        cover(mailbox_ack_seen);
        cover(arst && outstanding);
        cover(completed_any && expected_sobel);
        cover(completed_any && !expected_sobel);
    end

endmodule
