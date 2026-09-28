module zbuffer #(
    parameter int unsigned DEPTH = gfx_pkg::PIXEL_COUNT,
    parameter int unsigned ADDR_WIDTH = gfx_pkg::FRAMEBUFFER_ADDR_WIDTH
) (
    input  logic                  clk_sys,
    input  logic [ADDR_WIDTH-1:0] rd_addr,
    output logic [7:0]            rd_data,
    input  logic                  wr_en,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [7:0]            wr_data
);
    logic [7:0] mem [0:DEPTH-1];

    always_ff @(posedge clk_sys) begin
        rd_data <= mem[rd_addr];
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end
endmodule
