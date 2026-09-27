module cmd_decoder (
    input  logic clk_sys,
    input  logic rst,
    input  logic fifo_valid,
    output logic fifo_ready,
    input  logic [31:0] fifo_data,
    output logic dec_valid,
    input  logic dec_ready,
    output gfx_pkg::decoded_command_t dec_data,
    output logic err_valid,
    input  logic err_ready,
    output gfx_pkg::decoder_error_t err_data,
    output logic cmd_error
);
    typedef enum logic [1:0] {S_HEADER, S_COLLECT, S_FINALIZE} state_t;
    state_t state;
    logic [31:0] packet [0:15];
    logic [4:0] expected_len, word_count;
    gfx_pkg::decoded_command_t dec_reg;
    gfx_pkg::decoder_error_t err_reg;

    logic [7:0] syntax_code;
    logic [3:0] syntax_opcode;
    logic [15:0] syntax_tag;
    gfx_pkg::decoded_command_t syntax_decoded;

    assign dec_data = dec_reg;
    assign err_data = err_reg;
    assign fifo_ready = !dec_valid && !err_valid && (state != S_FINALIZE);

    function automatic [4:0] packet_length(input logic [3:0] opcode);
        case (opcode)
            gfx_pkg::CMD_NOP, gfx_pkg::CMD_READ_FRONT, gfx_pkg::CMD_GET_STATUS, gfx_pkg::CMD_GET_COUNTERS: packet_length = 1;
            gfx_pkg::CMD_BEGIN_FRAME, gfx_pkg::CMD_SET_SOBEL, gfx_pkg::CMD_PRESENT: packet_length = 2;
            gfx_pkg::CMD_DRAW_TRIANGLE: packet_length = 16;
            default: packet_length = 1;
        endcase
    endfunction

    always_comb begin
        syntax_code = 8'h00;
        syntax_opcode = packet[0][31:28];
        syntax_tag = packet[0][15:0];
        syntax_decoded = '0;
        syntax_decoded.opcode = packet[0][31:28];
        syntax_decoded.tag = packet[0][15:0];

        if (packet[0][27:16] != 0) begin
            syntax_code = gfx_pkg::ERR_RESERVED_NONZERO;
        end else begin
            case (packet[0][31:28])
                gfx_pkg::CMD_NOP, gfx_pkg::CMD_READ_FRONT, gfx_pkg::CMD_GET_STATUS, gfx_pkg::CMD_GET_COUNTERS: begin end
                gfx_pkg::CMD_BEGIN_FRAME: begin
                    if (packet[1][31:8] != 0) syntax_code = gfx_pkg::ERR_RESERVED_NONZERO;
                    syntax_decoded.clear_rgb332 = packet[1][7:0];
                end
                gfx_pkg::CMD_SET_SOBEL: begin
                    if (packet[1][31:9] != 0) syntax_code = gfx_pkg::ERR_RESERVED_NONZERO;
                    syntax_decoded.sobel_threshold = packet[1][7:0];
                    syntax_decoded.sobel_bypass = packet[1][8];
                end
                gfx_pkg::CMD_PRESENT: begin
                    if (packet[1][31:1] != 0) syntax_code = gfx_pkg::ERR_RESERVED_NONZERO;
                    syntax_decoded.present_mode = packet[1][0];
                end
                gfx_pkg::CMD_DRAW_TRIANGLE: begin
                    if ((packet[1][31:26] != 0) || (packet[2][31:26] != 0) ||
                        (packet[3][31:26] != 0)) begin
                        syntax_code = gfx_pkg::ERR_RESERVED_NONZERO;
                    end else if ((packet[1][25:13] > 13'd3840) ||
                                 (packet[2][25:13] > 13'd3840) ||
                                 (packet[3][25:13] > 13'd3840) ||
                                 (packet[1][12:0] > 13'd5120) ||
                                 (packet[2][12:0] > 13'd5120) ||
                                 (packet[3][12:0] > 13'd5120)) begin
                        syntax_code = gfx_pkg::ERR_COORD_RANGE;
                    end
                    syntax_decoded.v0_x = packet[1][12:0]; syntax_decoded.v0_y = packet[1][25:13];
                    syntax_decoded.v1_x = packet[2][12:0]; syntax_decoded.v1_y = packet[2][25:13];
                    syntax_decoded.v2_x = packet[3][12:0]; syntax_decoded.v2_y = packet[3][25:13];
                    syntax_decoded.r_start = packet[4]; syntax_decoded.g_start = packet[5];
                    syntax_decoded.b_start = packet[6]; syntax_decoded.z_start = packet[7];
                    syntax_decoded.r_dx = packet[8]; syntax_decoded.g_dx = packet[9];
                    syntax_decoded.b_dx = packet[10]; syntax_decoded.z_dx = packet[11];
                    syntax_decoded.r_dy = packet[12]; syntax_decoded.g_dy = packet[13];
                    syntax_decoded.b_dy = packet[14]; syntax_decoded.z_dy = packet[15];
                end
                default: syntax_code = gfx_pkg::ERR_UNKNOWN_OPCODE;
            endcase
        end
    end

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            state <= S_HEADER;
            expected_len <= 0;
            word_count <= 0;
            dec_valid <= 1'b0;
            err_valid <= 1'b0;
            dec_reg <= '0;
            err_reg <= '0;
            cmd_error <= 1'b0;
        end else begin
            if (dec_valid && dec_ready) dec_valid <= 1'b0;
            if (err_valid && err_ready) err_valid <= 1'b0;

            case (state)
                S_HEADER: begin
                    if (fifo_valid && fifo_ready) begin
                        packet[0] <= fifo_data;
                        if (fifo_data[31:28] > gfx_pkg::CMD_GET_COUNTERS) begin
                            err_valid <= 1'b1;
                            err_reg.code <= gfx_pkg::ERR_UNKNOWN_OPCODE;
                            err_reg.opcode <= fifo_data[31:28];
                            err_reg.tag <= fifo_data[15:0];
                            cmd_error <= 1'b1;
                        end else begin
                            expected_len <= packet_length(fifo_data[31:28]);
                            word_count <= 1;
                            if (packet_length(fifo_data[31:28]) == 1)
                                state <= S_FINALIZE;
                            else
                                state <= S_COLLECT;
                        end
                    end
                end
                S_COLLECT: begin
                    if (fifo_valid && fifo_ready) begin
                        packet[word_count[3:0]] <= fifo_data;
                        if (word_count == expected_len - 1'b1)
                            state <= S_FINALIZE;
                        else
                            word_count <= word_count + 1'b1;
                    end
                end
                S_FINALIZE: begin
                    if (syntax_code != 0) begin
                        err_valid <= 1'b1;
                        err_reg.code <= gfx_pkg::error_code_t'(syntax_code);
                        err_reg.opcode <= syntax_opcode;
                        err_reg.tag <= syntax_tag;
                        cmd_error <= 1'b1;
                    end else begin
                        dec_valid <= 1'b1;
                        dec_reg <= syntax_decoded;
                    end
                    state <= S_HEADER;
                end
                default: state <= S_HEADER;
            endcase
        end
    end
endmodule
