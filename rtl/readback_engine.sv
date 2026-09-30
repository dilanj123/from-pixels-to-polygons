module readback_engine (
    input  logic        clk_sys,
    input  logic        rst,

    input  logic        start_valid,
    output logic        start_ready,
    input  logic [15:0] start_tag,
    input  logic [1:0]  start_front_id,

    output logic        fb_rd_en,
    output logic [16:0] fb_rd_addr,
    output logic [1:0]  fb_rd_buffer_id,
    input  logic [7:0]  fb_rd_data,

    output logic        rsp_valid,
    input  logic        rsp_ready,
    output logic [31:0] rsp_data,

    output logic        readback_active,
    output logic        readback_complete
);
    localparam logic [16:0] PIXEL_COUNT = 17'd76800;
    localparam logic [14:0] DATA_WORD_COUNT = 15'd19200;

    typedef enum logic [3:0] {
        S_IDLE,
        S_BEGIN_W0,
        S_BEGIN_W1,
        S_BEGIN_W2,
        S_READ_ISSUE,
        S_READ_RETURN,
        S_DATA,
        S_END_W0,
        S_END_W1,
        S_END_W2
    } state_t;

    state_t state_q;
    logic [15:0] snapshot_tag_q;
    logic [1:0] snapshot_front_id_q;
    logic [16:0] pixel_addr_q;
    logic [14:0] data_word_index_q;
    logic [1:0] byte_index_q;
    logic [31:0] packed_word_q;
    logic [31:0] checksum_q;
    logic readback_complete_q;

    assign start_ready = (state_q == S_IDLE) && !rst;
    assign readback_active = (state_q != S_IDLE) && !rst;
    assign fb_rd_en = (state_q == S_READ_ISSUE) && !rst;
    assign fb_rd_addr = pixel_addr_q;
    assign fb_rd_buffer_id = snapshot_front_id_q;
    assign rsp_valid = (state_q == S_BEGIN_W0) ||
                       (state_q == S_BEGIN_W1) ||
                       (state_q == S_BEGIN_W2) ||
                       (state_q == S_DATA) ||
                       (state_q == S_END_W0) ||
                       (state_q == S_END_W1) ||
                       (state_q == S_END_W2);
    assign readback_complete = readback_complete_q;

    always_comb begin
        rsp_data = 32'd0;
        case (state_q)
            S_BEGIN_W0: rsp_data = {4'hC, 12'h000, snapshot_tag_q};
            S_BEGIN_W1: rsp_data = 32'd19200;
            S_BEGIN_W2: rsp_data = {3'b000, 8'd1, snapshot_front_id_q,
                                    9'd240, 10'd320};
            S_DATA:     rsp_data = packed_word_q;
            S_END_W0:   rsp_data = {4'hD, 12'h000, snapshot_tag_q};
            S_END_W1:   rsp_data = 32'h00000000;
            S_END_W2:   rsp_data = checksum_q;
            default:    rsp_data = 32'd0;
        endcase
    end

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            state_q <= S_IDLE;
            snapshot_tag_q <= 16'd0;
            snapshot_front_id_q <= 2'd0;
            pixel_addr_q <= 17'd0;
            data_word_index_q <= 15'd0;
            byte_index_q <= 2'd0;
            packed_word_q <= 32'd0;
            checksum_q <= 32'd0;
            readback_complete_q <= 1'b0;
        end else begin
            readback_complete_q <= 1'b0;
            case (state_q)
                S_IDLE: begin
                    if (start_valid && start_ready) begin
                        snapshot_tag_q <= start_tag;
                        snapshot_front_id_q <= start_front_id;
                        pixel_addr_q <= 17'd0;
                        data_word_index_q <= 15'd0;
                        byte_index_q <= 2'd0;
                        packed_word_q <= 32'd0;
                        checksum_q <= 32'd0;
                        state_q <= S_BEGIN_W0;
                    end
                end
                S_BEGIN_W0: if (rsp_valid && rsp_ready) state_q <= S_BEGIN_W1;
                S_BEGIN_W1: if (rsp_valid && rsp_ready) state_q <= S_BEGIN_W2;
                S_BEGIN_W2: begin
                    if (rsp_valid && rsp_ready) begin
                        pixel_addr_q <= 17'd0;
                        byte_index_q <= 2'd0;
                        packed_word_q <= 32'd0;
                        state_q <= S_READ_ISSUE;
                    end
                end
                S_READ_ISSUE: state_q <= S_READ_RETURN;
                S_READ_RETURN: begin
                    case (byte_index_q)
                        2'd0: packed_word_q[7:0]   <= fb_rd_data;
                        2'd1: packed_word_q[15:8]  <= fb_rd_data;
                        2'd2: packed_word_q[23:16] <= fb_rd_data;
                        2'd3: packed_word_q[31:24] <= fb_rd_data;
                    endcase
                    if (pixel_addr_q != PIXEL_COUNT - 1'b1)
                        pixel_addr_q <= pixel_addr_q + 1'b1;
                    if (byte_index_q == 2'd3) begin
                        byte_index_q <= 2'd0;
                        state_q <= S_DATA;
                    end else begin
                        byte_index_q <= byte_index_q + 1'b1;
                        state_q <= S_READ_ISSUE;
                    end
                end
                S_DATA: begin
                    if (rsp_valid && rsp_ready) begin
                        checksum_q <= checksum_q + packed_word_q;
                        if (data_word_index_q == DATA_WORD_COUNT - 1'b1) begin
                            state_q <= S_END_W0;
                        end else begin
                            data_word_index_q <= data_word_index_q + 1'b1;
                            state_q <= S_READ_ISSUE;
                        end
                    end
                end
                S_END_W0: if (rsp_valid && rsp_ready) state_q <= S_END_W1;
                S_END_W1: if (rsp_valid && rsp_ready) state_q <= S_END_W2;
                S_END_W2: begin
                    if (rsp_valid && rsp_ready) begin
                        readback_complete_q <= 1'b1;
                        state_q <= S_IDLE;
                    end
                end
                default: state_q <= S_IDLE;
            endcase
        end
    end

`ifndef SYNTHESIS
    always @(posedge clk_sys) begin
        if (!rst && start_valid && start_ready && start_front_id == 2'b11)
            $error("readback_engine start_front_id 3 is outside the valid buffer set");
    end
`endif
endmodule
