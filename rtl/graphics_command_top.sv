module graphics_command_top (
    input  logic        clk_sys,
    input  logic        clk_pix,
    input  logic        arst,
    input  logic        cmd_valid,
    output logic        cmd_ready,
    input  logic [31:0] cmd_data,
    output logic        rsp_valid,
    input  logic        rsp_ready,
    output logic [31:0] rsp_data,
    output logic [7:0]  red,
    output logic [7:0]  green,
    output logic [7:0]  blue,
    output logic        hsync,
    output logic        vsync,
    output logic        active_video,
    output logic [1:0]  front_id,
    output logic [1:0]  render_id,
    output logic [1:0]  spare_id,
    output logic        front_valid,
    output logic        command_error
);
    typedef enum logic [2:0] {ST_IDLE, ST_FRAME, ST_WAIT_PRESENT,
                              ST_READBACK, ST_RESPONSE} control_state_t;
    typedef enum logic [1:0] {Q_FRAME_DONE, Q_ERROR, Q_STATUS, Q_COUNTERS} response_kind_t;

    (* async_reg = "true" *) logic [1:0] reset_release_q;
    logic rst_sys;
    logic [31:0] fifo_data;
    logic fifo_valid, fifo_ready;
    logic [10:0] fifo_level;
    logic dec_valid, dec_ready, dec_error_valid, dec_error_ready, decoder_cmd_error;
    gfx_pkg::decoded_command_t dec_data;
    gfx_pkg::decoder_error_t dec_error_data;

    control_state_t state_q, response_return_state_q;
    response_kind_t response_kind_q;
    logic [4:0] response_words_q, response_index_q;
    logic response_fatal_q;
    logic runtime_error_q, frame_active_q, sobel_config_valid_q;
    logic [7:0] sobel_threshold_q;
    logic sobel_bypass_q;
    logic [15:0] response_tag_q;
    logic [7:0] response_error_code_q;
    logic [31:0] status_flags_q, status_roles_q;
    gfx_pkg::performance_counters_t counters_snapshot_q;

    logic render_valid, render_ready;
    logic present_valid, present_ready, present_sobel;
    logic [15:0] present_tag;
    logic sobel_busy, sobel_error;
    logic frame_done;
    logic [15:0] frame_done_tag;
    logic readback_start_valid, readback_start_ready;
    logic readback_rsp_valid, readback_rsp_ready, readback_active, readback_complete;
    logic [31:0] readback_rsp_data;
    logic fatal_recover;
    gfx_pkg::performance_counters_t perf_counters;
    logic front_valid_sys, front_valid_pix;
    logic [1:0] front_id_pix;
    logic renderer_quiescent, presentation_pending;

    assign rst_sys = reset_release_q[1];
    always_ff @(posedge clk_sys or posedge arst) begin
        if (arst) reset_release_q <= 2'b11;
        else reset_release_q <= {reset_release_q[0], 1'b0};
    end

    cmd_fifo #(.WIDTH(32), .DEPTH(1024), .PTR_WIDTH(10), .LEVEL_WIDTH(11)) command_fifo_i (
        .clk_sys(clk_sys), .rst(rst_sys),
        .in_valid(cmd_valid), .in_ready(cmd_ready), .in_data(cmd_data),
        .out_valid(fifo_valid), .out_ready(fifo_ready), .out_data(fifo_data),
        .level(fifo_level)
    );

    cmd_decoder command_decoder_i (
        .clk_sys(clk_sys), .rst(rst_sys),
        .fifo_valid(fifo_valid), .fifo_ready(fifo_ready), .fifo_data(fifo_data),
        .dec_valid(dec_valid), .dec_ready(dec_ready), .dec_data(dec_data),
        .err_valid(dec_error_valid), .err_ready(dec_error_ready),
        .err_data(dec_error_data), .cmd_error(decoder_cmd_error)
    );

    graphics_core graphics_i (
        .clk_sys(clk_sys), .clk_pix(clk_pix), .arst(arst),
        .fatal_recover(fatal_recover), .command_fifo_level(fifo_level),
        .render_cmd_valid(render_valid), .render_cmd_ready(render_ready), .render_cmd(dec_data),
        .present_valid(present_valid), .present_ready(present_ready),
        .present_sobel(present_sobel), .present_tag(present_tag),
        .sobel_threshold(sobel_threshold_q), .sobel_bypass(sobel_bypass_q),
        .sobel_busy(sobel_busy), .sobel_error(sobel_error),
        .frame_done(frame_done), .frame_done_tag(frame_done_tag),
        .readback_start_valid(readback_start_valid), .readback_start_ready(readback_start_ready),
        .readback_start_tag(dec_data.tag), .readback_rsp_valid(readback_rsp_valid),
        .readback_rsp_ready(readback_rsp_ready), .readback_rsp_data(readback_rsp_data),
        .readback_active(readback_active), .readback_complete(readback_complete),
        .red(red), .green(green), .blue(blue), .hsync(hsync), .vsync(vsync),
        .active_video(active_video), .front_id_sys(front_id), .render_id(render_id),
        .spare_id(spare_id), .front_id_pix(front_id_pix),
        .front_valid_sys(front_valid_sys), .front_valid_pix(front_valid_pix),
        .renderer_quiescent(renderer_quiescent),
        .presentation_pending(presentation_pending), .perf_counters(perf_counters)
    );
    assign front_valid = front_valid_sys;

    function automatic logic [31:0] response_header(input logic [3:0] typ,
                                                     input logic [15:0] tag);
        response_header = {typ, 12'd0, tag};
    endfunction

    function automatic logic [31:0] counter_word(
        input gfx_pkg::performance_counters_t c, input logic [3:0] index);
        case (index)
            1: counter_word=c.frames_completed;
            2: counter_word=c.triangles_submitted;
            3: counter_word=c.triangles_degenerate;
            4: counter_word=c.triangles_backface_rejected;
            5: counter_word=c.candidate_pixels;
            6: counter_word=c.covered_fragments;
            7: counter_word=c.z_pass;
            8: counter_word=c.z_fail;
            9: counter_word=c.clear_cycles;
            10: counter_word=c.render_cycles;
            11: counter_word=c.triangle_setup_cycles;
            12: counter_word=c.present_wait_cycles;
            13: counter_word=c.sobel_cycles;
            14: counter_word=c.command_fifo_high_watermark;
            default: counter_word=32'd0;
        endcase
    endfunction

    always_comb begin
        dec_ready = 1'b0;
        dec_error_ready = 1'b0;
        render_valid = 1'b0;
        present_valid = 1'b0;
        present_sobel = dec_data.present_mode;
        present_tag = dec_data.tag;
        readback_start_valid = 1'b0;
        readback_rsp_ready = 1'b0;

        if ((state_q == ST_IDLE) || (state_q == ST_FRAME)) begin
            if (dec_error_valid) begin
                dec_error_ready = 1'b1;
            end else if (dec_valid) begin
                case (dec_data.opcode)
                    gfx_pkg::CMD_NOP: dec_ready = 1'b1;
                    gfx_pkg::CMD_BEGIN_FRAME: begin
                        if (state_q == ST_IDLE) begin
                            render_valid = 1'b1;
                            dec_ready = render_ready;
                        end else dec_ready = 1'b1;
                    end
                    gfx_pkg::CMD_DRAW_TRIANGLE: begin
                        if (state_q == ST_FRAME) begin
                            render_valid = 1'b1;
                            dec_ready = render_ready;
                        end else dec_ready = 1'b1;
                    end
                    gfx_pkg::CMD_SET_SOBEL: dec_ready = 1'b1;
                    gfx_pkg::CMD_PRESENT: begin
                        if (state_q == ST_FRAME &&
                            !(dec_data.present_mode && !sobel_config_valid_q)) begin
                            present_valid = 1'b1;
                            dec_ready = present_ready;
                        end else dec_ready = 1'b1;
                    end
                    gfx_pkg::CMD_READ_FRONT: begin
                        if (state_q != ST_IDLE || !front_valid_sys) dec_ready=1'b1;
                        else begin
                            readback_start_valid=1'b1;
                            dec_ready=readback_start_ready;
                        end
                    end
                    // Consume requests in FRAME_ACTIVE so the sequential
                    // legality check can return ERR_ILLEGAL_STATE instead of
                    // holding the decoder output and blocking a later PRESENT.
                    gfx_pkg::CMD_GET_STATUS, gfx_pkg::CMD_GET_COUNTERS:
                        dec_ready = 1'b1;
                    default: dec_ready = 1'b1;
                endcase
            end
        end

        if (state_q == ST_READBACK)
            readback_rsp_ready = rsp_ready;

        rsp_valid = 1'b0;
        rsp_data = 32'd0;
        if (state_q == ST_READBACK) begin
            rsp_valid = readback_rsp_valid;
            rsp_data = readback_rsp_data;
        end else if (state_q == ST_RESPONSE) begin
            rsp_valid = 1'b1;
            case (response_kind_q)
                Q_FRAME_DONE: begin
                    rsp_data = (response_index_q == 0) ? response_header(gfx_pkg::RSP_FRAME_DONE,response_tag_q) : 32'd0;
                end
                Q_ERROR: begin
                    rsp_data = (response_index_q == 0) ? response_header(gfx_pkg::RSP_ERROR,response_tag_q) : {24'd0,response_error_code_q};
                end
                Q_STATUS: begin
                    case (response_index_q)
                        0: rsp_data=response_header(gfx_pkg::RSP_STATUS,response_tag_q);
                        1: rsp_data=status_flags_q;
                        2: rsp_data=status_roles_q;
                        default: rsp_data=32'd0;
                    endcase
                end
                Q_COUNTERS: begin
                    if (response_index_q == 0) rsp_data=response_header(gfx_pkg::RSP_COUNTERS,response_tag_q);
                    else rsp_data=counter_word(counters_snapshot_q,response_index_q[3:0]);
                end
                default: rsp_data=32'd0;
            endcase
        end
        fatal_recover = (state_q == ST_RESPONSE) && response_fatal_q && rsp_valid && rsp_ready &&
                        (response_index_q == response_words_q-1'b1);
        command_error = decoder_cmd_error || runtime_error_q;
    end

    always_ff @(posedge clk_sys or posedge rst_sys) begin
        if (rst_sys) begin
            state_q <= ST_IDLE;
            response_return_state_q <= ST_IDLE;
            response_kind_q <= Q_ERROR;
            response_words_q <= 0;
            response_index_q <= 0;
            response_fatal_q <= 0;
            runtime_error_q <= 0;
            frame_active_q <= 0;
            sobel_config_valid_q <= 0;
            sobel_threshold_q <= 0;
            sobel_bypass_q <= 0;
            response_tag_q <= 0;
            response_error_code_q <= 0;
            status_flags_q <= 0;
            status_roles_q <= 0;
            counters_snapshot_q <= '0;
        end else begin
            case (state_q)
                ST_IDLE, ST_FRAME: begin
                    if (dec_error_valid && dec_error_ready) begin
                        response_kind_q <= Q_ERROR;
                        response_words_q <= 2;
                        response_index_q <= 0;
                        response_tag_q <= dec_error_data.tag;
                        response_error_code_q <= dec_error_data.code;
                        response_fatal_q <= 0;
                        response_return_state_q <= state_q;
                        runtime_error_q <= 1'b1;
                        state_q <= ST_RESPONSE;
                    end else if (dec_valid && dec_ready) begin
                        case (dec_data.opcode)
                            gfx_pkg::CMD_BEGIN_FRAME: begin
                                if (state_q == ST_IDLE) begin
                                    frame_active_q <= 1'b1;
                                    state_q <= ST_FRAME;
                                end else begin
                                    response_kind_q<=Q_ERROR; response_words_q<=2; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_error_code_q<=gfx_pkg::ERR_ILLEGAL_STATE;
                                    response_fatal_q<=0; response_return_state_q<=state_q;
                                    runtime_error_q<=1'b1; state_q<=ST_RESPONSE;
                                end
                            end
                            gfx_pkg::CMD_DRAW_TRIANGLE: begin
                                if (state_q != ST_FRAME) begin
                                    response_kind_q<=Q_ERROR; response_words_q<=2; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_error_code_q<=gfx_pkg::ERR_ILLEGAL_STATE;
                                    response_fatal_q<=0; response_return_state_q<=state_q;
                                    runtime_error_q<=1'b1; state_q<=ST_RESPONSE;
                                end
                            end
                            gfx_pkg::CMD_SET_SOBEL: begin
                                if (state_q != ST_IDLE) begin
                                    response_kind_q<=Q_ERROR; response_words_q<=2; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_error_code_q<=gfx_pkg::ERR_ILLEGAL_STATE;
                                    response_fatal_q<=0; response_return_state_q<=state_q;
                                    runtime_error_q<=1'b1; state_q<=ST_RESPONSE;
                                end else begin
                                    sobel_threshold_q<=dec_data.sobel_threshold;
                                    sobel_bypass_q<=dec_data.sobel_bypass;
                                    sobel_config_valid_q<=1'b1;
                                end
                            end
                            gfx_pkg::CMD_PRESENT: begin
                                if (state_q != ST_FRAME) begin
                                    response_error_code_q<=gfx_pkg::ERR_ILLEGAL_STATE;
                                    response_kind_q<=Q_ERROR; response_words_q<=2; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_fatal_q<=0;
                                    response_return_state_q<=state_q; runtime_error_q<=1'b1; state_q<=ST_RESPONSE;
                                end else if (dec_data.present_mode && !sobel_config_valid_q) begin
                                    response_error_code_q<=gfx_pkg::ERR_SOBEL_CONFIG_MISSING;
                                    response_kind_q<=Q_ERROR; response_words_q<=2; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_fatal_q<=0;
                                    response_return_state_q<=state_q; runtime_error_q<=1'b1; state_q<=ST_RESPONSE;
                                end else begin
                                    response_tag_q<=dec_data.tag;
                                    state_q<=ST_WAIT_PRESENT;
                                end
                            end
                            gfx_pkg::CMD_READ_FRONT: begin
                                if (state_q != ST_IDLE) begin
                                    response_error_code_q<=gfx_pkg::ERR_ILLEGAL_STATE;
                                    response_kind_q<=Q_ERROR; response_words_q<=2; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_fatal_q<=0;
                                    response_return_state_q<=state_q; runtime_error_q<=1'b1; state_q<=ST_RESPONSE;
                                end else if (!front_valid_sys) begin
                                    response_error_code_q<=gfx_pkg::ERR_FRONT_INVALID;
                                    response_kind_q<=Q_ERROR; response_words_q<=2; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_fatal_q<=0;
                                    response_return_state_q<=state_q; runtime_error_q<=1'b1; state_q<=ST_RESPONSE;
                                end else state_q<=ST_READBACK;
                            end
                            gfx_pkg::CMD_GET_STATUS: begin
                                if (state_q != ST_IDLE) begin
                                    response_error_code_q<=gfx_pkg::ERR_ILLEGAL_STATE;
                                    response_kind_q<=Q_ERROR; response_words_q<=2; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_fatal_q<=0;
                                    response_return_state_q<=state_q; runtime_error_q<=1'b1; state_q<=ST_RESPONSE;
                                end else begin
                                    response_kind_q<=Q_STATUS; response_words_q<=3; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_fatal_q<=0;
                                    status_flags_q<={25'd0,sobel_config_valid_q,command_error,sobel_busy,
                                                     readback_active,presentation_pending,front_valid_sys,frame_active_q};
                                    status_roles_q<={26'd0,spare_id,render_id,front_id};
                                    response_return_state_q<=ST_IDLE; state_q<=ST_RESPONSE;
                                end
                            end
                            gfx_pkg::CMD_GET_COUNTERS: begin
                                if (state_q != ST_IDLE) begin
                                    response_error_code_q<=gfx_pkg::ERR_ILLEGAL_STATE;
                                    response_kind_q<=Q_ERROR; response_words_q<=2; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_fatal_q<=0;
                                    response_return_state_q<=state_q; runtime_error_q<=1'b1; state_q<=ST_RESPONSE;
                                end else begin
                                    response_kind_q<=Q_COUNTERS; response_words_q<=15; response_index_q<=0;
                                    response_tag_q<=dec_data.tag; response_fatal_q<=0;
                                    counters_snapshot_q<=perf_counters;
                                    response_return_state_q<=ST_IDLE; state_q<=ST_RESPONSE;
                                end
                            end
                            default: begin end // NOP and successfully dispatched renderer commands have no success response.
                        endcase
                    end
                end
                ST_WAIT_PRESENT: begin
                    if (frame_done) begin
                        response_kind_q<=Q_FRAME_DONE; response_words_q<=2; response_index_q<=0;
                        response_tag_q<=frame_done_tag; response_fatal_q<=0;
                        response_return_state_q<=ST_IDLE; frame_active_q<=0; state_q<=ST_RESPONSE;
                    end else if (sobel_error) begin
                        response_kind_q<=Q_ERROR; response_words_q<=2; response_index_q<=0;
                        response_tag_q<=response_tag_q; response_error_code_q<=gfx_pkg::ERR_SOBEL_PROTOCOL;
                        response_fatal_q<=1; response_return_state_q<=ST_IDLE;
                        frame_active_q<=0; runtime_error_q<=1'b1; state_q<=ST_RESPONSE;
                    end
                end
                ST_READBACK: if (readback_complete) state_q<=ST_IDLE;
                ST_RESPONSE: begin
                    if (rsp_valid && rsp_ready) begin
                        if (response_index_q == response_words_q-1'b1) begin
                            state_q<=response_return_state_q;
                            response_index_q<=0;
                            response_fatal_q<=0;
                        end else response_index_q<=response_index_q+1'b1;
                    end
                end
                default: state_q<=ST_IDLE;
            endcase
        end
    end

`ifndef SYNTHESIS
    always @(posedge clk_sys) begin
        if (!rst_sys && fifo_level > 11'd1024) $error("command FIFO level out of range");
    end
`endif
endmodule
