module clear_engine #(
    parameter int unsigned PIXEL_COUNT_PARAM = gfx_pkg::PIXEL_COUNT,
    parameter int unsigned ADDR_WIDTH_PARAM = gfx_pkg::FRAMEBUFFER_ADDR_WIDTH
) (
    input  logic                     clk_sys,
    input  logic                     rst,
    input  logic                     start_valid,
    output logic                     start_ready,
    input  logic [7:0]               clear_rgb332,
    output logic                     busy,
    output logic                     done,
    output logic                     fb_we,
    output logic [ADDR_WIDTH_PARAM-1:0] fb_addr,
    output logic [7:0]               fb_wdata,
    output logic                     z_we,
    output logic [ADDR_WIDTH_PARAM-1:0] z_addr,
    output logic [7:0]               z_wdata
);
    localparam logic [ADDR_WIDTH_PARAM-1:0] LAST_ADDR = ADDR_WIDTH_PARAM'(PIXEL_COUNT_PARAM - 1);

    logic [ADDR_WIDTH_PARAM-1:0] address;
    logic [7:0] captured_clear;

    assign start_ready = !busy;
    assign fb_we = busy;
    assign z_we = busy;
    assign fb_addr = address;
    assign z_addr = address;
    assign fb_wdata = captured_clear;
    assign z_wdata = 8'hFF;

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            busy <= 1'b0;
            done <= 1'b0;
            address <= '0;
            captured_clear <= '0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                if (start_valid && start_ready) begin
                    busy <= 1'b1;
                    address <= '0;
                    captured_clear <= clear_rgb332;
                end
            end else if (address == LAST_ADDR) begin
                busy <= 1'b0;
                done <= 1'b1;
            end else begin
                address <= address + 1'b1;
            end
        end
    end
endmodule
