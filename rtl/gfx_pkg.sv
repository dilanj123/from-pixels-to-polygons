package gfx_pkg;
    localparam int unsigned RENDER_WIDTH = 320;
    localparam int unsigned RENDER_HEIGHT = 240;
    localparam int unsigned PIXEL_COUNT = RENDER_WIDTH * RENDER_HEIGHT;
    localparam int unsigned FRAMEBUFFER_ADDR_WIDTH = 17;
    localparam int unsigned COORD_WIDTH = 13;
    localparam int unsigned COORD_FRAC_BITS = 4;
    localparam int unsigned ATTRIBUTE_CMD_WIDTH = 32;
    localparam int unsigned ATTRIBUTE_FRAC_BITS = 8;
    localparam int unsigned ATTRIBUTE_ACCUM_WIDTH = 42;
    localparam int unsigned COMMAND_WIDTH = 32;
    localparam int unsigned COMMAND_FIFO_DEPTH = 1024;
    localparam int unsigned COMMAND_FIFO_PTR_WIDTH = 10;
    localparam int unsigned COMMAND_FIFO_LEVEL_WIDTH = 11;

    typedef enum logic [3:0] {
        CMD_NOP = 4'h0, CMD_BEGIN_FRAME = 4'h1, CMD_DRAW_TRIANGLE = 4'h2,
        CMD_SET_SOBEL = 4'h3, CMD_PRESENT = 4'h4, CMD_READ_FRONT = 4'h5,
        CMD_GET_STATUS = 4'h6, CMD_GET_COUNTERS = 4'h7
    } command_opcode_t;
    typedef enum logic [3:0] {
        RSP_FRAME_DONE = 4'h8, RSP_ERROR = 4'h9, RSP_STATUS = 4'hA,
        RSP_COUNTERS = 4'hB, RSP_READBACK_BEGIN = 4'hC, RSP_READBACK_END = 4'hD
    } response_type_t;
    typedef enum logic [7:0] {
        ERR_UNKNOWN_OPCODE = 8'h01, ERR_RESERVED_NONZERO = 8'h02,
        ERR_ILLEGAL_STATE = 8'h03, ERR_COORD_RANGE = 8'h04,
        ERR_FIELD_RANGE = 8'h05, ERR_FRONT_INVALID = 8'h06,
        ERR_SOBEL_CONFIG_MISSING = 8'h07, ERR_SOBEL_PROTOCOL = 8'h08,
        ERR_INTERNAL_PROTOCOL = 8'h09
    } error_code_t;

    typedef struct packed {
        logic [3:0] opcode;
        logic [15:0] tag;
        logic [7:0] clear_rgb332;
        logic [7:0] sobel_threshold;
        logic sobel_bypass;
        logic present_mode;
        logic [COORD_WIDTH-1:0] v0_x, v0_y, v1_x, v1_y, v2_x, v2_y;
        logic signed [31:0] r_start, g_start, b_start, z_start;
        logic signed [31:0] r_dx, g_dx, b_dx, z_dx;
        logic signed [31:0] r_dy, g_dy, b_dy, z_dy;
    } decoded_command_t;

    typedef struct packed {
        error_code_t code;
        logic [3:0] opcode;
        logic [15:0] tag;
    } decoder_error_t;

    typedef enum logic [1:0] {
        TRI_SETUP_RASTER = 2'b00,
        TRI_SETUP_EMPTY = 2'b01,
        TRI_SETUP_DEGENERATE = 2'b10,
        TRI_SETUP_BACKFACE = 2'b11
    } triangle_setup_class_t;

    typedef struct packed {
        triangle_setup_class_t classification;
        logic [15:0] tag;
        logic signed [31:0] area;
        logic signed [15:0] edge0_dx, edge0_dy;
        logic signed [15:0] edge1_dx, edge1_dy;
        logic signed [15:0] edge2_dx, edge2_dy;
        logic [2:0] top_left;
        logic signed [31:0] edge0_step_x, edge0_step_y;
        logic signed [31:0] edge1_step_x, edge1_step_y;
        logic signed [31:0] edge2_step_x, edge2_step_y;
        logic [8:0] xmin, xmax;
        logic [7:0] ymin, ymax;
        logic signed [31:0] e0_init, e1_init, e2_init;
        logic signed [31:0] r_start, g_start, b_start, z_start;
        logic signed [31:0] r_dx, g_dx, b_dx, z_dx;
        logic signed [31:0] r_dy, g_dy, b_dy, z_dy;
    } triangle_setup_result_t;

    typedef struct packed {
        logic [31:0] frames_completed;
        logic [31:0] triangles_submitted;
        logic [31:0] triangles_degenerate;
        logic [31:0] triangles_backface_rejected;
        logic [31:0] candidate_pixels;
        logic [31:0] covered_fragments;
        logic [31:0] z_pass;
        logic [31:0] z_fail;
        logic [31:0] clear_cycles;
        logic [31:0] render_cycles;
        logic [31:0] triangle_setup_cycles;
        logic [31:0] present_wait_cycles;
        logic [31:0] sobel_cycles;
        logic [31:0] command_fifo_high_watermark;
    } performance_counters_t;
endpackage
