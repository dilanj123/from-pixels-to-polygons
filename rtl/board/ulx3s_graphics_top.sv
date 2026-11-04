module ulx3s_graphics_top (
    input  logic       clk_25m,
    input  logic       btn_rst_n,
    input  logic       ftdi_txd,
    output logic       ftdi_rxd,
    output logic [3:0] gpdi_dp
);
    logic clk_300m, clk_sys, clk_315m, clk_315m_aux;
    logic clk_pix_5x, clk_pix;
    logic pll_sys_locked, pll_mid_locked, pll_video_locked;
    logic arst;
    logic rx_overrun, rx_framing_error;
    logic [7:0] red, green, blue;
    logic hsync, vsync, active_video;
    logic [1:0] front_id, render_id, spare_id;
    logic front_valid, command_error;

    // 25 MHz -> 300/60 MHz, VCO 600 MHz, PFD 25 MHz.
    clock2_gen #(
        .CLKI_DIV(1), .CLKFB_DIV(12),
        .CLKOP_DIV(2), .CLKOP_CPHASE(1),
        .CLKOS_DIV(10), .CLKOS_CPHASE(1)
    ) pll_sys_i (
        .clk_in(clk_25m), .clk_5x_out(clk_300m), .clk_out(clk_sys),
        .clk_locked(pll_sys_locked)
    );

    // 300 MHz -> 315 MHz, VCO 630 MHz, PFD 15 MHz.
    clock2_gen #(
        .CLKI_DIV(20), .CLKFB_DIV(21),
        .CLKOP_DIV(2), .CLKOP_CPHASE(1),
        .CLKOS_DIV(2), .CLKOS_CPHASE(1)
    ) pll_mid_i (
        .clk_in(clk_300m), .clk_5x_out(clk_315m), .clk_out(clk_315m_aux),
        .clk_locked(pll_mid_locked)
    );

    // 315 MHz -> 126 MHz serializer and 25.2 MHz pixel clocks.
    // VCO 630 MHz, PFD 63 MHz.
    clock2_gen #(
        .CLKI_DIV(5), .CLKFB_DIV(2),
        .CLKOP_DIV(5), .CLKOP_CPHASE(2),
        .CLKOS_DIV(25), .CLKOS_CPHASE(2)
    ) pll_video_i (
        .clk_in(clk_315m), .clk_5x_out(clk_pix_5x), .clk_out(clk_pix),
        .clk_locked(pll_video_locked)
    );

    // ULX3S button B0 is active low. Hold all logic in common reset until
    // each stage of the generated clock chain reports lock.
    assign arst = !btn_rst_n || !pll_sys_locked ||
                  !pll_mid_locked || !pll_video_locked;

    graphics_uart_top #(.CLKS_PER_BIT(521)) graphics_i (
        .clk_sys(clk_sys), .clk_pix(clk_pix), .arst(arst),
        .uart_rx(ftdi_txd), .uart_tx(ftdi_rxd),
        .rx_overrun(rx_overrun), .rx_framing_error(rx_framing_error),
        .red(red), .green(green), .blue(blue), .hsync(hsync), .vsync(vsync),
        .active_video(active_video), .front_id(front_id), .render_id(render_id),
        .spare_id(spare_id), .front_valid(front_valid),
        .command_error(command_error)
    );

    dvi_generator dvi_i (
        .clk_pix(clk_pix), .clk_pix_5x(clk_pix_5x), .rst_pix(arst),
        .de(active_video),
        .data_in_ch0(blue), .data_in_ch1(green), .data_in_ch2(red),
        .ctrl_in_ch0({vsync, hsync}), .ctrl_in_ch1(2'b00), .ctrl_in_ch2(2'b00),
        .tmds_ch0_serial(gpdi_dp[0]), .tmds_ch1_serial(gpdi_dp[1]),
        .tmds_ch2_serial(gpdi_dp[2]), .tmds_clk_serial(gpdi_dp[3])
    );
endmodule
