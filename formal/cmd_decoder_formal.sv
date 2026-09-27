module cmd_decoder_formal;
    (* gclk *) logic clk;
    logic rst, fifo_valid, fifo_ready;
    logic [31:0] fifo_data;
    logic dec_valid, dec_ready, err_valid, err_ready, cmd_error;
    gfx_pkg::decoded_command_t dec_data;
    gfx_pkg::decoder_error_t err_data;
    logic past_valid;
    logic shadow_active, shadow_complete;
    logic [4:0] shadow_remaining;
    logic [31:0] past_dec_data, past_err_data;

    cmd_decoder dut (
        .clk_sys(clk), .rst(rst), .fifo_valid(fifo_valid), .fifo_ready(fifo_ready),
        .fifo_data(fifo_data), .dec_valid(dec_valid), .dec_ready(dec_ready),
        .dec_data(dec_data), .err_valid(err_valid), .err_ready(err_ready),
        .err_data(err_data), .cmd_error(cmd_error)
    );

    function automatic [4:0] length(input logic [3:0] op);
        case (op)
            gfx_pkg::CMD_BEGIN_FRAME, gfx_pkg::CMD_SET_SOBEL, gfx_pkg::CMD_PRESENT: length = 2;
            gfx_pkg::CMD_DRAW_TRIANGLE: length = 16;
            default: length = 1;
        endcase
    endfunction

    wire fifo_xfer = fifo_valid && fifo_ready;
    wire dec_xfer = dec_valid && dec_ready;
    wire err_xfer = err_valid && err_ready;

    initial begin
        past_valid = 0;
        assume (rst);
    end

    always_ff @(posedge clk) begin
        if (!past_valid) begin
            past_valid <= 1;
            assume (rst);
        end else begin
            assume (!rst);
        end

        if (rst) begin
            assert (!dec_valid && !err_valid);
            assert (!cmd_error);
            shadow_active <= 0;
            shadow_complete <= 0;
            shadow_remaining <= 0;
        end else begin
            // A partial shadow packet cannot authorize any output.  This
            // checks atomic collection without depending on decoder internals.
            if (dec_valid || err_valid)
                assert (shadow_complete);
            assert (!(dec_valid && err_valid));
            if (dec_valid && !dec_ready && past_valid && $past(dec_valid && !dec_ready))
                assert ($past(dec_data) == dec_data);
            if (err_valid && !err_ready && past_valid && $past(err_valid && !err_ready))
                assert ($past(err_data) == err_data);
            if (dec_valid || err_valid)
                assert (!fifo_ready);

            if (dec_xfer || err_xfer)
                shadow_complete <= 0;

            if (fifo_xfer) begin
                if (!shadow_active) begin
                    if ((fifo_data[31:28] > gfx_pkg::CMD_GET_COUNTERS) ||
                        (length(fifo_data[31:28]) == 1)) begin
                        shadow_complete <= 1;
                    end else begin
                        shadow_active <= 1;
                        shadow_remaining <= length(fifo_data[31:28]) - 1'b1;
                    end
                end else if (shadow_remaining == 1) begin
                    shadow_active <= 0;
                    shadow_complete <= 1;
                end else begin
                    shadow_remaining <= shadow_remaining - 1'b1;
                end
            end
        end
        cover (shadow_complete);
    end
endmodule
