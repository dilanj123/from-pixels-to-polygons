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
endpackage
