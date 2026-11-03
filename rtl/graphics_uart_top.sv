module graphics_uart_top #(
    parameter integer CLKS_PER_BIT = 217
) (
    input  logic       clk_sys,
    input  logic       clk_pix,
    input  logic       arst,
    input  logic       uart_rx,
    output logic       uart_tx,
    output logic       rx_overrun,
    output logic       rx_framing_error,
    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue,
    output logic       hsync,
    output logic       vsync,
    output logic       active_video,
    output logic [1:0] front_id,
    output logic [1:0] render_id,
    output logic [1:0] spare_id,
    output logic       front_valid,
    output logic       command_error
);
    logic cmd_valid, cmd_ready, rsp_valid, rsp_ready;
    logic [31:0] cmd_data, rsp_data;

    uart_word_bridge #(.CLKS_PER_BIT(CLKS_PER_BIT)) transport_i (
        .clk_sys(clk_sys), .arst(arst), .uart_rx(uart_rx), .uart_tx(uart_tx),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_data(cmd_data),
        .rsp_valid(rsp_valid), .rsp_ready(rsp_ready), .rsp_data(rsp_data),
        .rx_overrun(rx_overrun), .rx_framing_error(rx_framing_error)
    );

    graphics_command_top graphics_i (
        .clk_sys(clk_sys), .clk_pix(clk_pix), .arst(arst),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_data(cmd_data),
        .rsp_valid(rsp_valid), .rsp_ready(rsp_ready), .rsp_data(rsp_data),
        .red(red), .green(green), .blue(blue), .hsync(hsync), .vsync(vsync),
        .active_video(active_video), .front_id(front_id), .render_id(render_id),
        .spare_id(spare_id), .front_valid(front_valid), .command_error(command_error)
    );
endmodule
