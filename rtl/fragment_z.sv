module fragment_z #(
    parameter int unsigned ADDR_WIDTH = gfx_pkg::FRAMEBUFFER_ADDR_WIDTH
) (
    input  logic                       clk_sys,
    input  logic                       rst,

    input  logic                       frag_valid,
    output logic                       frag_ready,
    input  logic [8:0]                 frag_x,
    input  logic [7:0]                 frag_y,
    input  logic signed [41:0]         frag_r_raw,
    input  logic signed [41:0]         frag_g_raw,
    input  logic signed [41:0]         frag_b_raw,
    input  logic signed [41:0]         frag_z_raw,

    output logic                       z_rd_en,
    output logic [ADDR_WIDTH-1:0]      z_rd_addr,
    input  logic [7:0]                 z_rd_data,

    output logic                       z_wr_en,
    output logic [ADDR_WIDTH-1:0]      z_wr_addr,
    output logic [7:0]                 z_wr_data,

    output logic                       fb_wr_en,
    output logic [ADDR_WIDTH-1:0]      fb_wr_addr,
    output logic [7:0]                 fb_wr_data,

    output logic                       pipeline_empty
);
    logic v0_q, v1_q, v2_q, v3_q;

    logic [ADDR_WIDTH-1:0] addr0_q, addr1_q, addr2_q, addr3_q;
    logic [7:0] colour0_q, colour1_q, colour2_q, colour3_q;
    logic [7:0] new_z0_q, new_z1_q, new_z2_q, new_z3_q;
    logic pass3_q;

    function automatic logic [7:0] clamp_rgb(input logic signed [41:0] raw);
        logic signed [41:0] shifted;
        begin
            shifted = raw >>> 8;
            if (shifted < 0)
                clamp_rgb = 8'd0;
            else if (shifted > 42'sd255)
                clamp_rgb = 8'd255;
            else
                clamp_rgb = shifted[7:0];
        end
    endfunction

    function automatic logic [7:0] clamp_z(input logic signed [41:0] raw);
        logic signed [41:0] shifted;
        begin
            shifted = raw >>> 8;
            if (shifted < 0)
                clamp_z = 8'd0;
            else if (shifted > 42'sd254)
                clamp_z = 8'd254;
            else
                clamp_z = shifted[7:0];
        end
    endfunction

    function automatic logic [ADDR_WIDTH-1:0] pixel_address(
        input logic [8:0] x,
        input logic [7:0] y
    );
        logic [ADDR_WIDTH-1:0] y_ext;
        logic [ADDR_WIDTH-1:0] x_ext;
        begin
            y_ext = {{(ADDR_WIDTH-8){1'b0}}, y};
            x_ext = {{(ADDR_WIDTH-9){1'b0}}, x};
            pixel_address = (y_ext << 8) + (y_ext << 6) + x_ext;
        end
    endfunction

    logic [7:0] quant_r, quant_g, quant_b, quant_z;
    logic [ADDR_WIDTH-1:0] quant_addr;

    assign quant_r = clamp_rgb(frag_r_raw);
    assign quant_g = clamp_rgb(frag_g_raw);
    assign quant_b = clamp_rgb(frag_b_raw);
    assign quant_z = clamp_z(frag_z_raw);
    assign quant_addr = pixel_address(frag_x, frag_y);

    assign frag_ready = !rst;

    assign z_rd_en = v1_q && !rst;
    assign z_rd_addr = addr1_q;

    assign z_wr_en = v3_q && pass3_q && !rst;
    assign z_wr_addr = addr3_q;
    assign z_wr_data = new_z3_q;

    assign fb_wr_en = z_wr_en;
    assign fb_wr_addr = addr3_q;
    assign fb_wr_data = colour3_q;

    assign pipeline_empty = !(v0_q || v1_q || v2_q || v3_q);

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            v0_q <= 1'b0;
            v1_q <= 1'b0;
            v2_q <= 1'b0;
            v3_q <= 1'b0;
            addr0_q <= '0;
            addr1_q <= '0;
            addr2_q <= '0;
            addr3_q <= '0;
            colour0_q <= '0;
            colour1_q <= '0;
            colour2_q <= '0;
            colour3_q <= '0;
            new_z0_q <= '0;
            new_z1_q <= '0;
            new_z2_q <= '0;
            new_z3_q <= '0;
            pass3_q <= 1'b0;
        end else begin
            v3_q <= v2_q;
            addr3_q <= addr2_q;
            colour3_q <= colour2_q;
            new_z3_q <= new_z2_q;
            pass3_q <= v2_q && (new_z2_q < z_rd_data);

            v2_q <= v1_q;
            addr2_q <= addr1_q;
            colour2_q <= colour1_q;
            new_z2_q <= new_z1_q;

            v1_q <= v0_q;
            addr1_q <= addr0_q;
            colour1_q <= colour0_q;
            new_z1_q <= new_z0_q;

            v0_q <= frag_valid && frag_ready;
            if (frag_valid && frag_ready) begin
                addr0_q <= quant_addr;
                colour0_q <= {quant_r[7:5], quant_g[7:5], quant_b[7:6]};
                new_z0_q <= quant_z;
            end
        end
    end

endmodule
