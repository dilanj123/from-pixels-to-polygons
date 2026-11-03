module graphics_core (
    input  logic                       clk_sys,
    input  logic                       clk_pix,
    input  logic                       arst,
    input  logic                       render_cmd_valid,
    output logic                       render_cmd_ready,
    input  gfx_pkg::decoded_command_t render_cmd,
    input  logic                       present_valid,
    output logic                       present_ready,
    input  logic                       present_sobel,
    input  logic [15:0]                present_tag,
    input  logic [7:0]                 sobel_threshold,
    input  logic                       sobel_bypass,
    output logic                       sobel_busy,
    output logic                       sobel_error,
    output logic                       frame_done,
    output logic [15:0]                frame_done_tag,
    input  logic                       readback_start_valid,
    output logic                       readback_start_ready,
    input  logic [15:0]                readback_start_tag,
    output logic                       readback_rsp_valid,
    input  logic                       readback_rsp_ready,
    output logic [31:0]                readback_rsp_data,
    output logic                       readback_active,
    output logic                       readback_complete,
    output logic [7:0]                 red,
    output logic [7:0]                 green,
    output logic [7:0]                 blue,
    output logic                       hsync,
    output logic                       vsync,
    output logic                       active_video,
    output logic [1:0]                 front_id_sys,
    output logic [1:0]                 render_id,
    output logic [1:0]                 spare_id,
    output logic [1:0]                 front_id_pix,
    output logic                       front_valid_sys,
    output logic                       front_valid_pix,
    output logic                       renderer_quiescent,
    output logic                       presentation_pending,
    output gfx_pkg::performance_counters_t perf_counters
);
    (* async_reg = "true" *) logic [1:0] sys_reset_release, pix_reset_release;
    logic rst_sys, rst_pix;
    logic render_ready_core, render_valid_core, renderer_idle;
    logic roles_present_ready;
    logic render_fb_wr_en;
    logic [16:0] render_fb_wr_addr, rb_addr, scan_addr;
    logic [7:0] render_fb_wr_data, rb_data;
    logic [1:0] rb_buffer_id;
    logic rb_engine_start_ready, rb_rd_en;
    logic sobel_start_ready, sobel_rd_en, sobel_wr_en;
    logic [16:0] sobel_rd_addr, sobel_wr_addr;
    logic [7:0] sobel_rd_data, sobel_wr_data;
    logic [1:0] sobel_source_id, sobel_destination_id;
    logic sobel_role_valid, sobel_role_ready, sobel_role_mode;
    logic [15:0] sobel_role_tag;
    logic normal_role_valid, role_valid_mux, role_mode_mux;
    logic [15:0] role_tag_mux;
    logic [7:0] pix_data0, pix_data1, pix_data2, selected_pix_data;
    logic [7:0] sys_data0, sys_data1, sys_data2;
    logic [1:0] front_id_pix_d;
    logic scan_fb_valid, scan_frame_start, scan_line_start;
    logic signed [15:0] raster_x, raster_y, pixel_x, pixel_y;
    logic [2:0] fb_sys_we;
    logic [16:0] fb_sys_addr [0:2];
    logic [7:0] fb_sys_wdata [0:2];

    always_ff @(posedge clk_sys or posedge arst) begin
        if (arst) sys_reset_release <= 2'b11;
        else sys_reset_release <= {sys_reset_release[0], 1'b0};
    end
    always_ff @(posedge clk_pix or posedge arst) begin
        if (arst) pix_reset_release <= 2'b11;
        else pix_reset_release <= {pix_reset_release[0], 1'b0};
    end
    assign rst_sys = sys_reset_release[1];
    assign rst_pix = pix_reset_release[1];

    assign present_ready = present_sobel ?
                           (sobel_start_ready && !presentation_pending && !readback_start_valid && !sobel_error) :
                           (roles_present_ready && !readback_start_valid && !sobel_busy && !sobel_error);
    assign normal_role_valid = present_valid && !present_sobel && present_ready;
    assign role_valid_mux = normal_role_valid || sobel_role_valid;
    assign role_mode_mux = sobel_role_valid ? sobel_role_mode : 1'b0;
    assign role_tag_mux = sobel_role_valid ? sobel_role_tag : present_tag;
    assign render_cmd_ready = render_ready_core && !presentation_pending && !readback_active &&
                              !sobel_busy && !sobel_error &&
                              !frame_done &&
                              !(present_valid && present_ready) &&
                              !(readback_start_valid && readback_start_ready);
    assign render_valid_core = render_cmd_valid && render_cmd_ready;
    always_comb begin
        for (integer bank = 0; bank < 3; bank = bank + 1) begin
            fb_sys_addr[bank] = render_fb_wr_addr;
            fb_sys_wdata[bank] = render_fb_wr_data;
            fb_sys_we[bank] = render_fb_wr_en && (render_id == bank[1:0]);
            if (rb_rd_en && (rb_buffer_id == bank[1:0]))
                fb_sys_addr[bank] = rb_addr;
            if (sobel_rd_en && (sobel_source_id == bank[1:0]))
                fb_sys_addr[bank] = sobel_rd_addr;
            if (sobel_wr_en && (sobel_destination_id == bank[1:0])) begin
                fb_sys_addr[bank] = sobel_wr_addr;
                fb_sys_wdata[bank] = sobel_wr_data;
                fb_sys_we[bank] = 1'b1;
            end
        end
    end

    renderer_core renderer_i (
        .clk_sys(clk_sys), .rst(rst_sys), .frame_restart(frame_done),
        .render_cmd_valid(render_valid_core), .render_cmd_ready(render_ready_core),
        .render_cmd(render_cmd), .frame_completed_event(frame_done),
        .present_wait_cycle(1'b0), .sobel_cycle(1'b0), .command_fifo_level(11'd0),
        .perf_counters(perf_counters), .render_fb_wr_en(render_fb_wr_en),
        .render_fb_wr_addr(render_fb_wr_addr), .render_fb_wr_data(render_fb_wr_data),
        .renderer_idle(renderer_idle),
        .renderer_quiescent(renderer_quiescent)
    );

    buffer_manager roles_i (
        .clk_sys(clk_sys), .rst_sys(rst_sys),
        .present_valid(role_valid_mux), .present_ready(roles_present_ready),
        .present_sobel(role_mode_mux), .present_tag(role_tag_mux), .renderer_quiescent(renderer_quiescent),
        .readback_active(readback_active), .clk_pix(clk_pix), .rst_pix(rst_pix),
        .safe_frame_start(scan_frame_start && (raster_x == -16'sd160) &&
                          (raster_y == -16'sd45)),
        .front_id_sys(front_id_sys), .render_id(render_id), .spare_id(spare_id),
        .front_id_pix(front_id_pix), .front_valid_sys(front_valid_sys),
        .front_valid_pix(front_valid_pix), .presentation_pending(presentation_pending),
        .frame_done(frame_done), .frame_done_tag(frame_done_tag)
    );

    sobel_controller sobel_control_i (
        .clk_sys(clk_sys), .rst(rst_sys),
        .start_valid(present_valid && present_sobel && present_ready),
        .start_ready(sobel_start_ready), .start_tag(present_tag),
        .render_id(render_id), .spare_id(spare_id),
        .renderer_quiescent(renderer_quiescent), .readback_active(readback_active),
        .cfg_threshold(sobel_threshold), .cfg_bypass(sobel_bypass),
        .busy(sobel_busy), .done(), .error(sobel_error),
        .source_id(sobel_source_id), .destination_id(sobel_destination_id),
        .fb_rd_en(sobel_rd_en), .fb_rd_addr(sobel_rd_addr), .fb_rd_data(sobel_rd_data),
        .fb_wr_en(sobel_wr_en), .fb_wr_addr(sobel_wr_addr), .fb_wr_data(sobel_wr_data),
        .present_valid(sobel_role_valid), .present_ready(roles_present_ready),
        .present_done_event(frame_done), .present_sobel(sobel_role_mode), .present_tag(sobel_role_tag)
    );

    assign readback_start_ready = rb_engine_start_ready && front_valid_sys &&
                                  renderer_idle &&
                                  !presentation_pending && !sobel_busy && !sobel_error && !rst_sys;
    readback_engine readback_i (
        .clk_sys(clk_sys), .rst(rst_sys),
        .start_valid(readback_start_valid && readback_start_ready),
        .start_ready(rb_engine_start_ready), .start_tag(readback_start_tag),
        .start_front_id(front_id_sys), .fb_rd_en(rb_rd_en), .fb_rd_addr(rb_addr),
        .fb_rd_buffer_id(rb_buffer_id), .fb_rd_data(rb_data),
        .rsp_valid(readback_rsp_valid), .rsp_ready(readback_rsp_ready),
        .rsp_data(readback_rsp_data), .readback_active(readback_active),
        .readback_complete(readback_complete)
    );

    assign rb_data = (rb_buffer_id == 2'd0) ? sys_data0 :
                     (rb_buffer_id == 2'd1) ? sys_data1 :
                     (rb_buffer_id == 2'd2) ? sys_data2 : 8'h00;
    assign sobel_rd_data = (sobel_source_id == 2'd0) ? sys_data0 :
                           (sobel_source_id == 2'd1) ? sys_data1 :
                           (sobel_source_id == 2'd2) ? sys_data2 : 8'h00;

    framebuffer_dp fb0 (
        .clk_pix(clk_pix), .pix_addr(scan_addr), .pix_rdata(pix_data0),
        .clk_sys(clk_sys),
        .sys_addr(fb_sys_addr[0]), .sys_we(fb_sys_we[0]), .sys_wdata(fb_sys_wdata[0]), .sys_rdata(sys_data0)
    );
    framebuffer_dp fb1 (
        .clk_pix(clk_pix), .pix_addr(scan_addr), .pix_rdata(pix_data1),
        .clk_sys(clk_sys),
        .sys_addr(fb_sys_addr[1]), .sys_we(fb_sys_we[1]), .sys_wdata(fb_sys_wdata[1]), .sys_rdata(sys_data1)
    );
    framebuffer_dp fb2 (
        .clk_pix(clk_pix), .pix_addr(scan_addr), .pix_rdata(pix_data2),
        .clk_sys(clk_sys),
        .sys_addr(fb_sys_addr[2]), .sys_we(fb_sys_we[2]), .sys_wdata(fb_sys_wdata[2]), .sys_rdata(sys_data2)
    );

    always_ff @(posedge clk_pix or posedge rst_pix) begin
        if (rst_pix) front_id_pix_d <= 2'd0;
        else front_id_pix_d <= front_id_pix;
    end
    always_comb begin
        case (front_id_pix_d)
            2'd0: selected_pix_data = pix_data0;
            2'd1: selected_pix_data = pix_data1;
            2'd2: selected_pix_data = pix_data2;
            default: selected_pix_data = 8'h00;
        endcase
    end

    scanout_2x scanout_i (
        .clk_pix(clk_pix), .rst_pix(rst_pix), .front_valid(front_valid_pix),
        .fb_pix_valid(scan_fb_valid), .fb_pix_addr(scan_addr),
        .fb_pix_rdata(selected_pix_data), .red(red), .green(green), .blue(blue),
        .hsync(hsync), .vsync(vsync), .active_video(active_video),
        .frame_start(scan_frame_start), .line_start(scan_line_start),
        .raster_x(raster_x), .raster_y(raster_y), .pixel_x(pixel_x), .pixel_y(pixel_y)
    );

`ifndef SYNTHESIS
    always @(posedge clk_sys) begin
        if (!rst_sys && render_fb_wr_en && (fb_sys_we[front_id_sys]))
            $error("renderer write targets FRONT");
        if (!rst_sys && render_fb_wr_en && (fb_sys_we[spare_id]))
            $error("renderer write targets SPARE");
        if (!rst_sys && sobel_wr_en && (sobel_destination_id != spare_id))
            $error("Sobel write destination is not SPARE");
        if (!rst_sys && sobel_rd_en && (sobel_source_id != render_id))
            $error("Sobel read source is not RENDER");
        if (!rst_sys && readback_active && sobel_busy)
            $error("readback overlaps Sobel ownership");
        if (!rst_sys && sobel_rd_en && sobel_wr_en &&
            (sobel_source_id == sobel_destination_id))
            $error("Sobel source/destination bank collision");
    end
    always @(posedge clk_pix) begin
        if (!rst_pix && scan_fb_valid && (scan_addr >= 17'd76800))
            $error("scanout framebuffer address out of range");
    end
`endif
endmodule
