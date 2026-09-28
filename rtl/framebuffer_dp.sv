module framebuffer_dp #(
    parameter int unsigned DEPTH = gfx_pkg::PIXEL_COUNT,
    parameter int unsigned ADDR_WIDTH = gfx_pkg::FRAMEBUFFER_ADDR_WIDTH
) (
    input  logic                  clk_pix,
    input  logic [ADDR_WIDTH-1:0] pix_addr,
    output logic [7:0]            pix_rdata,

    input  logic                  clk_sys,
    input  logic [ADDR_WIDTH-1:0] sys_addr,
    input  logic                  sys_we,
    input  logic [7:0]            sys_wdata,
    output logic [7:0]            sys_rdata
);
    logic [7:0] mem [0:DEPTH-1];

    always_ff @(posedge clk_pix)
        pix_rdata <= mem[pix_addr];

    always_ff @(posedge clk_sys) begin
        if (sys_we)
            mem[sys_addr] <= sys_wdata;
        sys_rdata <= mem[sys_addr];
    end
endmodule
