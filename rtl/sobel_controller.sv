module sobel_controller (
    input  logic        clk_sys,
    input  logic        rst,
    input  logic        recover,
    input  logic        start_valid,
    output logic        start_ready,
    input  logic [15:0] start_tag,
    input  logic [1:0]  render_id,
    input  logic [1:0]  spare_id,
    input  logic        renderer_quiescent,
    input  logic        readback_active,
    input  logic [7:0]  cfg_threshold,
    input  logic        cfg_bypass,
    output logic        busy,
    output logic        done,
    output logic        error,
    output logic [1:0]  source_id,
    output logic [1:0]  destination_id,
    output logic        fb_rd_en,
    output logic [16:0] fb_rd_addr,
    input  logic [7:0]  fb_rd_data,
    output logic        fb_wr_en,
    output logic [16:0] fb_wr_addr,
    output logic [7:0]  fb_wr_data,
    output logic        present_valid,
    input  logic        present_ready,
    input  logic        present_done_event,
    output logic        present_sobel,
    output logic [15:0] present_tag
);
    localparam logic [16:0] FRAME_PIXELS = 17'd76800;
    localparam logic [31:0] FRAME_TIMEOUT = 32'd300000;

    typedef enum logic [3:0] {
        S_IDLE, S_BASE_SETUP, S_BASE_ACCESS, S_CONFIG_START, S_CONFIG_WAIT,
        S_STREAM_START, S_STREAM, S_STATUS_SETUP, S_STATUS_ACCESS,
        S_COUNT_SETUP, S_COUNT_ACCESS, S_PRESENT, S_WAIT_PRESENT, S_ERROR
    } state_t;
    state_t state_q;

    logic [15:0] tag_q;
    logic [1:0] source_id_q, destination_id_q;
    logic [31:0] baseline_count_q, timeout_q;
    logic [16:0] input_count_q, output_count_q;
    logic [8:0] input_eol_count_q, output_eol_count_q;
    logic input_sof_seen_q, output_sof_seen_q, input_done_q, output_done_q;
    logic input_done_seen_q, output_done_seen_q, final_output_eol_q;
    logic reader_start_ready, reader_busy, reader_done;
    logic [23:0] reader_data;
    logic reader_valid, reader_ready, reader_sof, reader_eol;
    logic writer_start_ready, writer_busy, writer_done, writer_error;
    logic [7:0] writer_data;
    logic writer_valid, writer_ready, writer_sof, writer_eol;
    logic parent_psel, parent_penable, parent_pwrite;
    logic [7:0] parent_paddr;
    logic [31:0] parent_pwdata, parent_prdata;
    logic parent_pready, parent_pslverr;
    logic [23:0] parent_s_data;
    logic parent_s_valid, parent_s_ready, parent_s_user, parent_s_last;
    logic [7:0] parent_m_data;
    logic parent_m_valid, parent_m_ready, parent_m_user, parent_m_last;
    logic cfg_start_ready, cfg_busy, cfg_done, cfg_error;
    logic cfg_psel, cfg_penable, cfg_pwrite;
    logic [7:0] cfg_paddr;
    logic [31:0] cfg_pwdata;
    logic check_access, apb_read_setup, apb_read_access;
    logic [7:0] check_addr;
    logic parent_rst;
    logic [7:0] status_q;

    assign start_ready = (state_q == S_IDLE) && renderer_quiescent &&
                         !readback_active && !rst;
    assign busy = (state_q != S_IDLE) && (state_q != S_ERROR) && !rst;
    assign source_id = source_id_q;
    assign destination_id = destination_id_q;
    assign present_valid = (state_q == S_PRESENT);
    assign present_sobel = 1'b1;
    assign present_tag = tag_q;
    assign parent_rst = rst || (state_q == S_ERROR);

    sobel_fb_reader reader_i (
        .clk_sys(clk_sys), .rst(parent_rst),
        .start_valid((state_q == S_STREAM_START) && reader_start_ready),
        .start_ready(reader_start_ready), .busy(reader_busy), .done(reader_done),
        .fb_rd_en(fb_rd_en), .fb_rd_addr(fb_rd_addr), .fb_rd_data(fb_rd_data),
        .m_tdata(reader_data), .m_tvalid(reader_valid), .m_tready(reader_ready),
        .m_tuser(reader_sof), .m_tlast(reader_eol)
    );

    sobel_fb_writer writer_i (
        .clk_sys(clk_sys), .rst(parent_rst),
        .start_valid((state_q == S_STREAM_START) && writer_start_ready),
        .start_ready(writer_start_ready), .busy(writer_busy), .done(writer_done),
        .error(writer_error), .s_tdata(writer_data), .s_tvalid(writer_valid),
        .s_tready(writer_ready), .s_tuser(writer_sof), .s_tlast(writer_eol),
        .fb_wr_en(fb_wr_en), .fb_wr_addr(fb_wr_addr), .fb_wr_data(fb_wr_data)
    );

    assign reader_ready = parent_s_ready;
    assign writer_data = parent_m_data;
    assign writer_valid = parent_m_valid;
    assign writer_sof = parent_m_user;
    assign writer_eol = parent_m_last;
    assign parent_s_data = reader_data;
    assign parent_s_valid = reader_valid;
    assign parent_s_user = reader_sof;
    assign parent_s_last = reader_eol;
    assign parent_m_ready = writer_ready;

    sobel_apb_master config_i (
        .clk_sys(clk_sys), .rst(rst),
        .start_valid((state_q == S_CONFIG_START) && cfg_start_ready),
        .start_ready(cfg_start_ready), .cfg_enable(1'b1),
        .cfg_threshold(cfg_threshold), .cfg_bypass(cfg_bypass),
        .busy(cfg_busy), .config_done(cfg_done), .config_error(cfg_error),
        .psel(cfg_psel), .penable(cfg_penable), .pwrite(cfg_pwrite),
        .paddr(cfg_paddr), .pwdata(cfg_pwdata), .prdata(parent_prdata),
        .pready(parent_pready), .pslverr(parent_pslverr)
    );

    rtl_to_pixels_top_pipelined #(.IMG_WIDTH(320), .IMG_HEIGHT(240)) sobel_i (
        .clk(clk_sys), .rst(parent_rst),
        .s_tdata(parent_s_data), .s_tvalid(parent_s_valid), .s_tready(parent_s_ready),
        .s_tuser(parent_s_user), .s_tlast(parent_s_last),
        .m_tdata(parent_m_data), .m_tvalid(parent_m_valid), .m_tready(parent_m_ready),
        .m_tuser(parent_m_user), .m_tlast(parent_m_last),
        .psel(parent_psel), .penable(parent_penable), .pwrite(parent_pwrite),
        .paddr(parent_paddr), .pwdata(parent_pwdata), .prdata(parent_prdata),
        .pready(parent_pready), .pslverr(parent_pslverr)
    );

    assign check_access = (state_q == S_BASE_ACCESS) || (state_q == S_STATUS_ACCESS) ||
                          (state_q == S_COUNT_ACCESS);
    assign apb_read_setup = (state_q == S_BASE_SETUP) || (state_q == S_STATUS_SETUP) ||
                            (state_q == S_COUNT_SETUP);
    assign apb_read_access = check_access;
    assign check_addr = (state_q == S_BASE_SETUP || state_q == S_BASE_ACCESS) ? 8'h0c :
                        (state_q == S_STATUS_SETUP || state_q == S_STATUS_ACCESS) ? 8'h08 : 8'h0c;
    assign parent_psel = apb_read_setup || apb_read_access ? 1'b1 : cfg_psel;
    assign parent_penable = apb_read_access ? 1'b1 : apb_read_setup ? 1'b0 : cfg_penable;
    assign parent_pwrite = apb_read_setup || apb_read_access ? 1'b0 : cfg_pwrite;
    assign parent_paddr = apb_read_setup || apb_read_access ? check_addr : cfg_paddr;
    assign parent_pwdata = apb_read_setup || apb_read_access ? 32'd0 : cfg_pwdata;

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            state_q <= S_IDLE;
            tag_q <= 0;
            source_id_q <= 0;
            destination_id_q <= 0;
            baseline_count_q <= 0;
            timeout_q <= 0;
            input_count_q <= 0;
            output_count_q <= 0;
            input_eol_count_q <= 0;
            output_eol_count_q <= 0;
            input_sof_seen_q <= 0;
            output_sof_seen_q <= 0;
            input_done_seen_q <= 0;
            output_done_seen_q <= 0;
            final_output_eol_q <= 0;
            status_q <= 0;
            done <= 0;
            error <= 0;
        end else if (recover) begin
            state_q <= S_IDLE;
            tag_q <= 16'd0;
            source_id_q <= 2'd0;
            destination_id_q <= 2'd0;
            baseline_count_q <= 32'd0;
            timeout_q <= 32'd0;
            input_count_q <= 17'd0;
            output_count_q <= 17'd0;
            input_eol_count_q <= 9'd0;
            output_eol_count_q <= 9'd0;
            input_sof_seen_q <= 1'b0;
            output_sof_seen_q <= 1'b0;
            input_done_seen_q <= 1'b0;
            output_done_seen_q <= 1'b0;
            final_output_eol_q <= 1'b0;
            status_q <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            done <= 0;
            case (state_q)
                S_IDLE: if (start_valid && start_ready) begin
                    tag_q <= start_tag;
                    source_id_q <= render_id;
                    destination_id_q <= spare_id;
                    input_count_q <= 0;
                    output_count_q <= 0;
                    input_eol_count_q <= 0;
                    output_eol_count_q <= 0;
                    input_sof_seen_q <= 0;
                    output_sof_seen_q <= 0;
                    input_done_seen_q <= 0;
                    output_done_seen_q <= 0;
                    final_output_eol_q <= 0;
                    timeout_q <= 0;
                    error <= 0;
                    state_q <= S_BASE_SETUP;
                end
                S_BASE_SETUP: state_q <= S_BASE_ACCESS;
                S_BASE_ACCESS: if (parent_pready) begin
                    if (parent_pslverr) begin error <= 1; state_q <= S_ERROR; end
                    else begin baseline_count_q <= parent_prdata; state_q <= S_CONFIG_START; end
                end
                S_CONFIG_START: if (cfg_start_ready) state_q <= S_CONFIG_WAIT;
                S_CONFIG_WAIT: begin
                    if (cfg_error) begin error <= 1; state_q <= S_ERROR; end
                    else if (cfg_done) state_q <= S_STREAM_START;
                end
                S_STREAM_START: if (reader_start_ready && writer_start_ready) begin
                    timeout_q <= 0;
                    state_q <= S_STREAM;
                end
                S_STREAM: begin
                    timeout_q <= timeout_q + 1'b1;
                    if (timeout_q == FRAME_TIMEOUT) begin error <= 1; state_q <= S_ERROR; end
                    if (writer_error) begin error <= 1; state_q <= S_ERROR; end
                    if (reader_valid && reader_ready) begin
                        input_count_q <= input_count_q + 1'b1;
                        if (reader_sof) input_sof_seen_q <= 1'b1;
                        if (reader_eol) input_eol_count_q <= input_eol_count_q + 1'b1;
                    end
                    if (parent_m_valid && parent_m_ready) begin
                        output_count_q <= output_count_q + 1'b1;
                        if (parent_m_user) output_sof_seen_q <= 1'b1;
                        if (parent_m_last) begin
                            output_eol_count_q <= output_eol_count_q + 1'b1;
                            if (output_count_q == FRAME_PIXELS - 1'b1)
                                final_output_eol_q <= 1'b1;
                        end
                    end
                    if (reader_done) input_done_seen_q <= 1'b1;
                    if (writer_done) output_done_seen_q <= 1'b1;
                    if ((input_done_seen_q || reader_done) && (output_done_seen_q || writer_done)) begin
                        if (input_count_q != FRAME_PIXELS || output_count_q != FRAME_PIXELS ||
                            !input_sof_seen_q || !output_sof_seen_q ||
                            input_eol_count_q != 9'd240 || output_eol_count_q != 9'd240 ||
                            !final_output_eol_q || writer_error) begin
                            error <= 1;
                            state_q <= S_ERROR;
                        end else begin
                            state_q <= S_STATUS_SETUP;
                        end
                    end
                end
                S_STATUS_SETUP: state_q <= S_STATUS_ACCESS;
                S_STATUS_ACCESS: if (parent_pready) begin
                    if (parent_pslverr || parent_prdata[3]) begin
                        error <= 1; state_q <= S_ERROR;
                    end else if (parent_prdata[0]) begin
                        state_q <= S_STATUS_SETUP;
                    end else begin
                        status_q <= parent_prdata[7:0];
                        state_q <= S_COUNT_SETUP;
                    end
                end
                S_COUNT_SETUP: state_q <= S_COUNT_ACCESS;
                S_COUNT_ACCESS: if (parent_pready) begin
                    if (parent_pslverr || parent_prdata != baseline_count_q + 32'd1) begin
                        error <= 1; state_q <= S_ERROR;
                    end else begin
                        state_q <= S_PRESENT;
                    end
                end
                S_PRESENT: if (present_valid && present_ready) state_q <= S_WAIT_PRESENT;
                S_WAIT_PRESENT: if (done) state_q <= S_IDLE;
                S_ERROR: begin
                    error <= 1;
                end
                default: state_q <= S_ERROR;
            endcase
            if (state_q == S_WAIT_PRESENT && present_done_event)
                done <= 1;
        end
    end

    wire _unused_status = ^status_q ^ reader_busy ^ writer_busy ^ cfg_busy ^ (|source_id_q);
endmodule
