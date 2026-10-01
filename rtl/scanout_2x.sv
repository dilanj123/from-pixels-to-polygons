module scanout_2x (
    input  logic               clk_pix,
    input  logic               rst_pix,
    input  logic               front_valid,

    output logic               fb_pix_valid,
    output logic [16:0]        fb_pix_addr,
    input  logic [7:0]         fb_pix_rdata,

    output logic [7:0]         red,
    output logic [7:0]         green,
    output logic [7:0]         blue,
    output logic               hsync,
    output logic               vsync,
    output logic               active_video,
    output logic               frame_start,
    output logic               line_start,
    output logic signed [15:0] raster_x,
    output logic signed [15:0] raster_y,
    output logic signed [15:0] pixel_x,
    output logic signed [15:0] pixel_y
);
    logic timing_hsync, timing_vsync, timing_de;
    logic timing_frame, timing_line;
    logic signed [15:0] timing_x, timing_y;
    logic [16:0] y_scaled, x_scaled;
    logic [16:0] source_addr;

    // Use the pinned file's D-036 640x480p60 defaults without altering it.
    display_480p timing_i (
        .clk_pix(clk_pix), .rst_pix(rst_pix),
        .hsync(timing_hsync), .vsync(timing_vsync), .de(timing_de),
        .frame(timing_frame), .line(timing_line),
        .sx(timing_x), .sy(timing_y)
    );

    assign y_scaled = {9'b0, timing_y[8:1]};
    assign x_scaled = {8'b0, timing_x[9:1]};
    assign source_addr = (y_scaled << 8) + (y_scaled << 6) + x_scaled;
    assign fb_pix_valid = timing_de;
    assign fb_pix_addr = timing_de ? source_addr : 17'd0;

    assign frame_start = timing_frame;
    assign line_start = timing_line;
    assign raster_x = timing_x;
    assign raster_y = timing_y;

    always_ff @(posedge clk_pix or posedge rst_pix) begin
        if (rst_pix) begin
            active_video <= 1'b0;
            hsync <= 1'b1;
            vsync <= 1'b1;
            pixel_x <= 16'sd0;
            pixel_y <= 16'sd0;
        end else begin
            // The framebuffer samples the current timing address on this edge.
            // Delay the matching control/coordinate tuple by the same cycle.
            active_video <= timing_de;
            hsync <= timing_hsync;
            vsync <= timing_vsync;
            pixel_x <= timing_x;
            pixel_y <= timing_y;
        end
    end

    assign red = (active_video && front_valid) ?
                 {fb_pix_rdata[7:5], fb_pix_rdata[7:5], fb_pix_rdata[7:6]} : 8'h00;
    assign green = (active_video && front_valid) ?
                   {fb_pix_rdata[4:2], fb_pix_rdata[4:2], fb_pix_rdata[4:3]} : 8'h00;
    assign blue = (active_video && front_valid) ?
                  {fb_pix_rdata[1:0], fb_pix_rdata[1:0], fb_pix_rdata[1:0], fb_pix_rdata[1:0]} : 8'h00;
endmodule
