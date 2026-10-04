// Triple-buffer role ownership and stable-payload presentation mailbox.
// Both clock domains share the common asynchronous reset; only toggles cross.
module presentation_manager (
    input  logic       clk_sys,
    input  logic       clk_pix,
    input  logic       rst,

    input  logic       present_valid,
    output logic       present_ready,
    input  logic       renderer_quiescent,
    input  logic       readback_active,
    output logic       frame_done,
    output logic       present_ack,
    output logic [1:0] front_id_sys,
    output logic [1:0] render_id,
    output logic [1:0] spare_id,
    output logic       front_valid_sys,
    output logic       presentation_pending,

    input  logic       pix_frame_boundary,
    output logic [1:0] front_id_pix,
    output logic       front_valid_pix
);
    logic rst_sys, rst_pix;
    logic request_toggle_sys;
    logic [1:0] request_id_sys;
    logic ack_toggle_pix;
    logic [1:0] ack_id_pix;
    logic req_sync1_pix, req_sync2_pix, req_seen_pix;
    logic ack_sync1_sys, ack_sync2_sys, ack_seen_sys;

    reset_sync sys_reset_i (.clk(clk_sys), .arst(rst), .srst(rst_sys));
    reset_sync pix_reset_i (.clk(clk_pix), .arst(rst), .srst(rst_pix));

    assign present_ready = !rst_sys && !presentation_pending && !readback_active &&
                           renderer_quiescent;

    always_ff @(posedge clk_pix or posedge rst_pix) begin
        if (rst_pix) begin
            req_sync1_pix <= 1'b0;
            req_sync2_pix <= 1'b0;
            req_seen_pix <= 1'b0;
            ack_toggle_pix <= 1'b0;
            ack_id_pix <= 2'd0;
            front_id_pix <= 2'd0;
            front_valid_pix <= 1'b0;
        end else begin
            req_sync1_pix <= request_toggle_sys;
            req_sync2_pix <= req_sync1_pix;
            if ((req_sync2_pix != req_seen_pix) && pix_frame_boundary) begin
                // request_id_sys is held stable from request acceptance until
                // the matching ack is observed in clk_sys.
                front_id_pix <= request_id_sys;
                front_valid_pix <= 1'b1;
                ack_id_pix <= request_id_sys;
                ack_toggle_pix <= req_sync2_pix;
                req_seen_pix <= req_sync2_pix;
            end
        end
    end

    always_ff @(posedge clk_sys or posedge rst_sys) begin
        if (rst_sys) begin
            front_id_sys <= 2'd0;
            render_id <= 2'd1;
            spare_id <= 2'd2;
            front_valid_sys <= 1'b0;
            request_toggle_sys <= 1'b0;
            request_id_sys <= 2'd0;
            ack_sync1_sys <= 1'b0;
            ack_sync2_sys <= 1'b0;
            ack_seen_sys <= 1'b0;
            presentation_pending <= 1'b0;
            frame_done <= 1'b0;
            present_ack <= 1'b0;
        end else begin
            ack_sync1_sys <= ack_toggle_pix;
            ack_sync2_sys <= ack_sync1_sys;
            frame_done <= 1'b0;
            present_ack <= 1'b0;

            if (present_valid && present_ready) begin
                request_id_sys <= render_id;
                request_toggle_sys <= ~request_toggle_sys;
                presentation_pending <= 1'b1;
            end

            if (ack_sync2_sys != ack_seen_sys) begin
                ack_seen_sys <= ack_sync2_sys;
                // NORMAL rotation happens only after the synchronized ACK.
                front_id_sys <= render_id;
                render_id <= front_id_sys;
                front_valid_sys <= 1'b1;
                presentation_pending <= 1'b0;
                present_ack <= 1'b1;
                frame_done <= 1'b1;
            end
        end
    end

    // Keep the payload observably stable while outstanding. This assertion is
    // intentionally omitted from synthesis-facing logic; the testbench checks
    // the mailbox stability and role invariants.
endmodule
