module uart_word_bridge #(
    parameter integer CLKS_PER_BIT = 217
) (
    input  logic        clk_sys,
    input  logic        arst,
    input  logic        uart_rx,
    output logic        uart_tx,
    output logic        cmd_valid,
    input  logic        cmd_ready,
    output logic [31:0] cmd_data,
    input  logic        rsp_valid,
    output logic        rsp_ready,
    input  logic [31:0] rsp_data,
    output logic        rx_overrun,
    output logic        rx_framing_error
);
    localparam integer HALF_BIT = CLKS_PER_BIT / 2;
    typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_t;
    typedef enum logic [1:0] {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state_t;
    rx_state_t rx_state_q;
    tx_state_t tx_state_q;
    (* async_reg = "true" *) logic [1:0] rx_sync_q;
    (* async_reg = "true" *) logic [1:0] reset_release_q;
    logic rst_sys;
    logic [31:0] assemble_q, command_word_q;
    logic [7:0] rx_shift_q;
    logic [1:0] byte_index_q;
    logic command_pending_q, rx_block_q;
    logic [31:0] tx_word_q;
    logic [2:0] rx_bit_q, tx_bit_q;
    logic [1:0] tx_byte_q;
    logic [31:0] rx_baud_q, tx_baud_q;

    assign cmd_valid = command_pending_q && !rx_block_q;
    assign cmd_data = command_word_q;
    assign rsp_ready = (tx_state_q == TX_IDLE);

    initial begin
        if (CLKS_PER_BIT < 4) $error("CLKS_PER_BIT must be at least 4");
    end

    always_ff @(posedge clk_sys or posedge arst) begin
        if (arst) reset_release_q <= 2'b11;
        else reset_release_q <= {reset_release_q[0], 1'b0};
    end
    assign rst_sys = reset_release_q[1];

    always_ff @(posedge clk_sys or posedge arst) begin
        if (arst) rx_sync_q <= 2'b11;
        else rx_sync_q <= {rx_sync_q[0], uart_rx};
    end

    always_ff @(posedge clk_sys or posedge rst_sys) begin
        if (rst_sys) begin
            rx_state_q <= RX_IDLE;
            rx_baud_q <= 0;
            rx_bit_q <= 0;
            rx_shift_q <= 0;
            assemble_q <= 0;
            command_word_q <= 0;
            byte_index_q <= 0;
            command_pending_q <= 0;
            rx_block_q <= 0;
            rx_overrun <= 0;
            rx_framing_error <= 0;
        end else begin
            if (command_pending_q && cmd_ready) command_pending_q <= 0;
            case (rx_state_q)
                RX_IDLE: begin
                    if (!rx_sync_q[1] && !rx_block_q) begin
                        rx_baud_q <= HALF_BIT - 1;
                        rx_state_q <= RX_START;
                    end
                end
                RX_START: begin
                    if (rx_baud_q != 0) rx_baud_q <= rx_baud_q - 1'b1;
                    else if (!rx_sync_q[1]) begin
                        rx_baud_q <= CLKS_PER_BIT - 1;
                        rx_bit_q <= 0;
                        rx_state_q <= RX_DATA;
                    end else rx_state_q <= RX_IDLE;
                end
                RX_DATA: begin
                    if (rx_baud_q != 0) rx_baud_q <= rx_baud_q - 1'b1;
                    else begin
                        rx_shift_q[rx_bit_q] <= rx_sync_q[1];
                        rx_baud_q <= CLKS_PER_BIT - 1;
                        if (rx_bit_q == 7) rx_state_q <= RX_STOP;
                        else rx_bit_q <= rx_bit_q + 1'b1;
                    end
                end
                RX_STOP: begin
                    if (rx_baud_q != 0) rx_baud_q <= rx_baud_q - 1'b1;
                    else begin
                        rx_state_q <= RX_IDLE;
                        if (!rx_sync_q[1]) begin
                            rx_framing_error <= 1'b1;
                            rx_block_q <= 1'b1;
                            byte_index_q <= 0;
                        end else if (!rx_block_q) begin
                            assemble_q[byte_index_q*8 +: 8] <= rx_shift_q;
                            if (byte_index_q == 3) begin
                                if (!command_pending_q || (command_pending_q && cmd_ready)) begin
                                    command_word_q <= {rx_shift_q, assemble_q[23:0]};
                                    command_pending_q <= 1'b1;
                                end else begin
                                    rx_overrun <= 1'b1;
                                    rx_block_q <= 1'b1;
                                end
                                byte_index_q <= 0;
                            end else byte_index_q <= byte_index_q + 1'b1;
                        end
                    end
                end
                default: rx_state_q <= RX_IDLE;
            endcase
        end
    end

    always_ff @(posedge clk_sys or posedge rst_sys) begin
        if (rst_sys) begin
            tx_state_q <= TX_IDLE;
            tx_baud_q <= 0;
            tx_bit_q <= 0;
            tx_byte_q <= 0;
            tx_word_q <= 0;
            uart_tx <= 1'b1;
        end else begin
            case (tx_state_q)
                TX_IDLE: begin
                    uart_tx <= 1'b1;
                    if (rsp_valid && rsp_ready) begin
                        tx_word_q <= rsp_data;
                        tx_byte_q <= 0;
                        tx_bit_q <= 0;
                        tx_baud_q <= CLKS_PER_BIT - 1;
                        uart_tx <= 1'b0;
                        tx_state_q <= TX_START;
                    end
                end
                TX_START: begin
                    if (tx_baud_q != 0) tx_baud_q <= tx_baud_q - 1'b1;
                    else begin
                        uart_tx <= tx_word_q[tx_byte_q*8];
                        tx_baud_q <= CLKS_PER_BIT - 1;
                        tx_bit_q <= 0;
                        tx_state_q <= TX_DATA;
                    end
                end
                TX_DATA: begin
                    if (tx_baud_q != 0) tx_baud_q <= tx_baud_q - 1'b1;
                    else if (tx_bit_q == 7) begin
                        uart_tx <= 1'b1;
                        tx_baud_q <= CLKS_PER_BIT - 1;
                        tx_state_q <= TX_STOP;
                    end else begin
                        tx_bit_q <= tx_bit_q + 1'b1;
                        uart_tx <= tx_word_q[tx_byte_q*8 + tx_bit_q + 1'b1];
                        tx_baud_q <= CLKS_PER_BIT - 1;
                    end
                end
                TX_STOP: begin
                    if (tx_baud_q != 0) tx_baud_q <= tx_baud_q - 1'b1;
                    else if (tx_byte_q == 3) begin
                        tx_state_q <= TX_IDLE;
                        uart_tx <= 1'b1;
                    end else begin
                        tx_byte_q <= tx_byte_q + 1'b1;
                        tx_baud_q <= CLKS_PER_BIT - 1;
                        uart_tx <= 1'b0;
                        tx_state_q <= TX_START;
                    end
                end
                default: tx_state_q <= TX_IDLE;
            endcase
        end
    end
endmodule
