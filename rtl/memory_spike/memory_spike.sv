// GFX-004 representative memory feasibility structures only.
// These modules intentionally contain no graphics/raster behavior.

module gfx_spike_framebuffer #(
    parameter integer DEPTH = 76800,
    parameter integer ADDR_WIDTH = 17
) (
    input  wire                  clk_pix,
    input  wire [ADDR_WIDTH-1:0] pix_addr,
    output reg  [7:0]            pix_rdata,
    input  wire                  clk_sys,
    input  wire [ADDR_WIDTH-1:0] sys_addr,
    input  wire                  sys_we,
    input  wire [7:0]            sys_wdata,
    output reg  [7:0]            sys_rdata
);
    (* ram_style = "block", no_rw_check *)
    reg [7:0] mem [0:DEPTH-1];

    always @(posedge clk_pix)
        pix_rdata <= mem[pix_addr];

    always @(posedge clk_sys) begin
        sys_rdata <= mem[sys_addr];
        if (sys_we)
            mem[sys_addr] <= sys_wdata;
    end
endmodule

module gfx_spike_zbuffer #(
    parameter integer DEPTH = 76800,
    parameter integer ADDR_WIDTH = 17
) (
    input  wire                  clk_sys,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [7:0]            rd_data,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire                  wr_en,
    input  wire [7:0]            wr_data
);
    (* ram_style = "block", no_rw_check *)
    reg [7:0] mem [0:DEPTH-1];

    always @(posedge clk_sys) begin
        rd_data <= mem[rd_addr];
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end
endmodule

module gfx_spike_fifo #(
    parameter integer DEPTH = 1024,
    parameter integer ADDR_WIDTH = 10
) (
    input  wire                  clk_sys,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [31:0]           rd_data,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire                  wr_en,
    input  wire [31:0]           wr_data
);
    (* ram_style = "block", no_rw_check *)
    reg [31:0] mem [0:DEPTH-1];

    always @(posedge clk_sys) begin
        rd_data <= mem[rd_addr];
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end
endmodule

module memory_spike_top (
    input  wire        clk_pix,
    input  wire        clk_sys,
    input  wire [16:0] fb_pix_addr,
    input  wire [16:0] fb_sys_addr,
    input  wire        fb_sys_we,
    input  wire [7:0]  fb_sys_wdata,
    output wire [7:0]  fb0_pix_rdata,
    output wire [7:0]  fb1_pix_rdata,
    output wire [7:0]  fb2_pix_rdata,
    output wire [7:0]  fb0_sys_rdata,
    output wire [7:0]  fb1_sys_rdata,
    output wire [7:0]  fb2_sys_rdata,
    input  wire [16:0] z_rd_addr,
    input  wire [16:0] z_wr_addr,
    input  wire        z_wr_en,
    input  wire [7:0]  z_wr_data,
    output wire [7:0]  z_rd_data,
    input  wire [9:0]  fifo_rd_addr,
    input  wire [9:0]  fifo_wr_addr,
    input  wire        fifo_wr_en,
    input  wire [31:0] fifo_wr_data,
    output wire [31:0] fifo_rd_data
);
    (* keep_hierarchy = "yes" *)
    gfx_spike_framebuffer fb0 (
        .clk_pix(clk_pix), .pix_addr(fb_pix_addr), .pix_rdata(fb0_pix_rdata),
        .clk_sys(clk_sys), .sys_addr(fb_sys_addr), .sys_we(fb_sys_we),
        .sys_wdata(fb_sys_wdata), .sys_rdata(fb0_sys_rdata)
    );
    (* keep_hierarchy = "yes" *)
    gfx_spike_framebuffer fb1 (
        .clk_pix(clk_pix), .pix_addr(fb_pix_addr), .pix_rdata(fb1_pix_rdata),
        .clk_sys(clk_sys), .sys_addr(fb_sys_addr), .sys_we(fb_sys_we),
        .sys_wdata(fb_sys_wdata), .sys_rdata(fb1_sys_rdata)
    );
    (* keep_hierarchy = "yes" *)
    gfx_spike_framebuffer fb2 (
        .clk_pix(clk_pix), .pix_addr(fb_pix_addr), .pix_rdata(fb2_pix_rdata),
        .clk_sys(clk_sys), .sys_addr(fb_sys_addr), .sys_we(fb_sys_we),
        .sys_wdata(fb_sys_wdata), .sys_rdata(fb2_sys_rdata)
    );
    (* keep_hierarchy = "yes" *)
    gfx_spike_zbuffer zbuffer (
        .clk_sys(clk_sys), .rd_addr(z_rd_addr), .rd_data(z_rd_data),
        .wr_addr(z_wr_addr), .wr_en(z_wr_en), .wr_data(z_wr_data)
    );
    (* keep_hierarchy = "yes" *)
    gfx_spike_fifo fifo (
        .clk_sys(clk_sys), .rd_addr(fifo_rd_addr), .rd_data(fifo_rd_data),
        .wr_addr(fifo_wr_addr), .wr_en(fifo_wr_en), .wr_data(fifo_wr_data)
    );
endmodule

module memory_spike_one_framebuffer_top (
    input wire clk_pix, input wire clk_sys,
    input wire [16:0] pix_addr, input wire [16:0] sys_addr,
    input wire sys_we, input wire [7:0] sys_wdata,
    output wire [7:0] pix_rdata, output wire [7:0] sys_rdata
);
    gfx_spike_framebuffer framebuffer (
        .clk_pix(clk_pix), .pix_addr(pix_addr), .pix_rdata(pix_rdata),
        .clk_sys(clk_sys), .sys_addr(sys_addr), .sys_we(sys_we),
        .sys_wdata(sys_wdata), .sys_rdata(sys_rdata)
    );
endmodule

module memory_spike_zbuffer_top (
    input wire clk_sys, input wire [16:0] rd_addr, output wire [7:0] rd_data,
    input wire [16:0] wr_addr, input wire wr_en, input wire [7:0] wr_data
);
    gfx_spike_zbuffer zbuffer (
        .clk_sys(clk_sys), .rd_addr(rd_addr), .rd_data(rd_data),
        .wr_addr(wr_addr), .wr_en(wr_en), .wr_data(wr_data)
    );
endmodule

module memory_spike_fifo_top (
    input wire clk_sys, input wire [9:0] rd_addr, output wire [31:0] rd_data,
    input wire [9:0] wr_addr, input wire wr_en, input wire [31:0] wr_data
);
    gfx_spike_fifo fifo (
        .clk_sys(clk_sys), .rd_addr(rd_addr), .rd_data(rd_data),
        .wr_addr(wr_addr), .wr_en(wr_en), .wr_data(wr_data)
    );
endmodule
