// Gate-5 NORMAL graphics composition: renderer, three colour framebuffers,
// presentation manager, and the reviewed 640x480 scanout.
module graphics_system (
    input  logic                      clk_sys,
    input  logic                      clk_pix,
    input  logic                      rst,
    input  logic                      render_cmd_valid,
    output logic                      render_cmd_ready,
    input  gfx_pkg::decoded_command_t render_cmd,
    output logic                      frame_done,
    output logic                      present_ack,
    output logic [1:0]                front_id_sys,
    output logic [1:0]                render_id,
    output logic [1:0]                spare_id,
    output logic                      front_valid_sys,
    output logic                      front_valid_pix,
    output logic [7:0]                red,
    output logic [7:0]                green,
    output logic [7:0]                blue,
    output logic                      hsync,
    output logic                      vsync,
    output logic                      active_video
);
    logic renderer_ready, renderer_quiescent;
    logic [16:0] render_wr_addr;
    logic [7:0] render_wr_data;
    logic render_wr_en;
    logic [7:0] pix_data [0:2];
    logic [7:0] sys_rdata [0:2];
    logic [7:0] scan_data;
    logic [16:0] scan_addr;
    logic scan_valid, scan_frame, scan_line;
    logic signed [15:0] scan_rx, scan_ry, scan_px, scan_py;
    logic [1:0] front_id_pix;
    logic normal_present_valid, normal_present_ready;
    logic present_fire;
    logic [1:0] front_id_pix_d;
    logic rst_sys, rst_pix;

    reset_sync sys_reset_i (.clk(clk_sys), .arst(rst), .srst(rst_sys));
    reset_sync pix_reset_i (.clk(clk_pix), .arst(rst), .srst(rst_pix));

    assign normal_present_valid = render_cmd_valid && renderer_ready &&
                                  (render_cmd.opcode == gfx_pkg::CMD_PRESENT) &&
                                  !render_cmd.present_mode;
    assign present_fire = normal_present_valid && normal_present_ready;
    assign render_cmd_ready = !rst_sys && renderer_ready &&
                              (!normal_present_valid || normal_present_ready);

    renderer_core renderer_i (
        .clk_sys(clk_sys), .rst(rst_sys),
        .render_cmd_valid(render_cmd_valid && render_cmd_ready),
        .render_cmd_ready(renderer_ready), .render_cmd(render_cmd),
        .frame_completed_event(frame_done), .present_wait_cycle(1'b0),
        .sobel_cycle(1'b0), .command_fifo_level(11'd0),
        .perf_counters(), .renderer_quiescent(renderer_quiescent),
        .render_fb_wr_en(render_wr_en), .render_fb_wr_addr(render_wr_addr),
        .render_fb_wr_data(render_wr_data)
    );

    presentation_manager manager_i (
        .clk_sys(clk_sys), .clk_pix(clk_pix), .rst(rst),
        .present_valid(present_fire), .present_ready(normal_present_ready),
        .renderer_quiescent(renderer_quiescent), .readback_active(1'b0),
        .frame_done(frame_done), .present_ack(present_ack),
        .front_id_sys(front_id_sys), .render_id(render_id), .spare_id(spare_id),
        .front_valid_sys(front_valid_sys), .presentation_pending(),
        .pix_frame_boundary(scan_frame), .front_id_pix(front_id_pix),
        .front_valid_pix(front_valid_pix)
    );

    genvar i;
    generate for (i = 0; i < 3; i++) begin : g_fb
        framebuffer_dp framebuffer_i (
            .clk_pix(clk_pix), .pix_addr(scan_addr), .pix_rdata(pix_data[i]),
            .clk_sys(clk_sys),
            .sys_addr(render_wr_addr),
            .sys_we(render_wr_en && (render_id == i[1:0])),
            .sys_wdata(render_wr_data), .sys_rdata(sys_rdata[i])
        );
    end endgenerate

    // The selected ID is delayed with the synchronous framebuffer read.
    always_ff @(posedge clk_pix or posedge rst) begin
        if (rst_pix) front_id_pix_d <= 2'd0;
        else front_id_pix_d <= front_id_pix;
    end
    always_comb begin
        case (front_id_pix_d)
            2'd0: scan_data = pix_data[0];
            2'd1: scan_data = pix_data[1];
            2'd2: scan_data = pix_data[2];
            default: scan_data = 8'd0;
        endcase
    end

    scanout_2x scanout_i (
        .clk_pix(clk_pix), .rst_pix(rst_pix), .front_valid(front_valid_pix),
        .fb_pix_valid(scan_valid), .fb_pix_addr(scan_addr),
        .fb_pix_rdata(scan_data), .red(red), .green(green), .blue(blue),
        .hsync(hsync), .vsync(vsync), .active_video(active_video),
        .frame_start(scan_frame), .line_start(scan_line),
        .raster_x(scan_rx), .raster_y(scan_ry), .pixel_x(scan_px), .pixel_y(scan_py)
    );
endmodule
