module buffer_manager (
    input  logic       clk_sys,
    input  logic       rst_sys,
    input  logic       present_valid,
    output logic       present_ready,
    input  logic       present_sobel,
    input  logic [15:0] present_tag,
    input  logic       renderer_quiescent,
    input  logic       readback_active,
    input  logic       clk_pix,
    input  logic       rst_pix,
    input  logic       safe_frame_start,
    output logic [1:0] front_id_sys,
    output logic [1:0] render_id,
    output logic [1:0] spare_id,
    output logic [1:0] front_id_pix,
    output logic       front_valid_sys,
    output logic       front_valid_pix,
    output logic       presentation_pending,
    output logic       frame_done,
    output logic [15:0] frame_done_tag
);
    logic request_ready, request_ack, request_pending;
    logic [1:0] request_front_id;
    logic accepted_present;
    logic sobel_mode_q;

    typedef enum logic [1:0] {M_IDLE, M_WAIT_ACK, M_DONE} manager_state_t;
    manager_state_t state_q;
    logic [15:0] tag_q;

    assign present_ready = (state_q == M_IDLE) && renderer_quiescent &&
                           !readback_active && request_ready && !rst_sys;
    assign accepted_present = present_valid && present_ready;
    assign request_front_id = present_sobel ? spare_id : render_id;
    assign presentation_pending = (state_q != M_IDLE) || request_pending;
    present_cdc mailbox_i (
        .clk_sys(clk_sys), .rst_sys(rst_sys),
        .request_valid(accepted_present), .request_ready(request_ready),
        .request_front_id(request_front_id), .acknowledge(request_ack),
        .clk_pix(clk_pix), .rst_pix(rst_pix),
        .safe_frame_start(safe_frame_start),
        .front_id_pix(front_id_pix), .front_valid_pix(front_valid_pix),
        .request_pending_sys(request_pending)
    );

    always_ff @(posedge clk_sys or posedge rst_sys) begin
        if (rst_sys) begin
            front_id_sys <= 2'd0;
            render_id <= 2'd1;
            spare_id <= 2'd2;
            front_valid_sys <= 1'b0;
            state_q <= M_IDLE;
            tag_q <= 16'd0;
            sobel_mode_q <= 1'b0;
            frame_done <= 1'b0;
            frame_done_tag <= 16'd0;
        end else begin
            frame_done <= 1'b0;
            case (state_q)
                M_IDLE: if (accepted_present) begin
                    tag_q <= present_tag;
                    sobel_mode_q <= present_sobel;
                    state_q <= M_WAIT_ACK;
                end
                M_WAIT_ACK: if (request_ack) begin
                    if (sobel_mode_q) begin
                        render_id <= front_id_sys;
                        spare_id <= render_id;
                        front_id_sys <= spare_id;
                    end else begin
                        render_id <= front_id_sys;
                        front_id_sys <= render_id;
                    end
                    front_valid_sys <= 1'b1;
                    state_q <= M_DONE;
                end
                M_DONE: begin
                    frame_done <= 1'b1;
                    frame_done_tag <= tag_q;
                    state_q <= M_IDLE;
                end
                default: state_q <= M_IDLE;
            endcase
        end
    end

`ifndef SYNTHESIS
    always @(posedge clk_sys) begin
        if (!rst_sys && ((front_id_sys == render_id) ||
                         (front_id_sys == spare_id) ||
                         (render_id == spare_id)))
            $error("buffer role uniqueness violation");
        if (!rst_sys && ((front_id_sys > 2'd2) || (render_id > 2'd2) ||
                         (spare_id > 2'd2)))
            $error("invalid framebuffer role ID");
    end
`endif
endmodule
