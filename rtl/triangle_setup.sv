module triangle_setup (
    input  logic                         clk_sys,
    input  logic                         rst,
    input  logic                         in_valid,
    output logic                         in_ready,
    input  gfx_pkg::decoded_command_t   in_data,
    output logic                         out_valid,
    input  logic                         out_ready,
    output gfx_pkg::triangle_setup_result_t out_data
);
    logic can_accept;
    gfx_pkg::triangle_setup_result_t calculated;
    gfx_pkg::triangle_setup_result_t result_q;

    logic signed [15:0] dx0, dy0, dx1, dy1, dx2, dy2;
    logic signed [31:0] dx0_32, dy0_32, dx1_32, dy1_32, dx2_32, dy2_32;
    logic signed [31:0] x0_32, y0_32, x1_32, y1_32, x2_32, y2_32;
    logic signed [31:0] min_x, max_x, min_y, max_y;
    logic signed [31:0] xmin_raw, xmax_raw, ymin_raw, ymax_raw;
    logic signed [31:0] sample_x, sample_y;
    logic signed [31:0] area;
    logic bbox_nonempty;

    assign can_accept = !out_valid || out_ready;
    assign in_ready = can_accept;
    assign out_data = result_q;

    always_comb begin
        x0_32 = $signed({19'd0, in_data.v0_x});
        y0_32 = $signed({19'd0, in_data.v0_y});
        x1_32 = $signed({19'd0, in_data.v1_x});
        y1_32 = $signed({19'd0, in_data.v1_y});
        x2_32 = $signed({19'd0, in_data.v2_x});
        y2_32 = $signed({19'd0, in_data.v2_y});

        dx0 = $signed({3'd0, in_data.v1_x}) - $signed({3'd0, in_data.v0_x});
        dy0 = $signed({3'd0, in_data.v1_y}) - $signed({3'd0, in_data.v0_y});
        dx1 = $signed({3'd0, in_data.v2_x}) - $signed({3'd0, in_data.v1_x});
        dy1 = $signed({3'd0, in_data.v2_y}) - $signed({3'd0, in_data.v1_y});
        dx2 = $signed({3'd0, in_data.v0_x}) - $signed({3'd0, in_data.v2_x});
        dy2 = $signed({3'd0, in_data.v0_y}) - $signed({3'd0, in_data.v2_y});
        dx0_32 = {{16{dx0[15]}}, dx0};
        dy0_32 = {{16{dy0[15]}}, dy0};
        dx1_32 = {{16{dx1[15]}}, dx1};
        dy1_32 = {{16{dy1[15]}}, dy1};
        dx2_32 = {{16{dx2[15]}}, dx2};
        dy2_32 = {{16{dy2[15]}}, dy2};

        if (in_data.v0_x <= in_data.v1_x) begin
            min_x = (in_data.v0_x <= in_data.v2_x) ? x0_32 : x2_32;
            max_x = (in_data.v1_x >= in_data.v2_x) ? x1_32 : x2_32;
        end else begin
            min_x = (in_data.v1_x <= in_data.v2_x) ? x1_32 : x2_32;
            max_x = (in_data.v0_x >= in_data.v2_x) ? x0_32 : x2_32;
        end
        if (in_data.v0_y <= in_data.v1_y) begin
            min_y = (in_data.v0_y <= in_data.v2_y) ? y0_32 : y2_32;
            max_y = (in_data.v1_y >= in_data.v2_y) ? y1_32 : y2_32;
        end else begin
            min_y = (in_data.v1_y <= in_data.v2_y) ? y1_32 : y2_32;
            max_y = (in_data.v0_y >= in_data.v2_y) ? y0_32 : y2_32;
        end

        xmin_raw = (min_x + 32'sd7) >>> 4;
        ymin_raw = (min_y + 32'sd7) >>> 4;
        xmax_raw = (max_x < 32'sd8) ? -32'sd1 : ((max_x - 32'sd8) >>> 4);
        ymax_raw = (max_y < 32'sd8) ? -32'sd1 : ((max_y - 32'sd8) >>> 4);
        bbox_nonempty = (xmin_raw <= xmax_raw) && (ymin_raw <= ymax_raw) &&
                        (xmax_raw >= 0) && (ymax_raw >= 0) &&
                        (xmin_raw <= 319) && (ymin_raw <= 239);
        area = dx0_32 * (y2_32 - y0_32) - dy0_32 * (x2_32 - x0_32);
        sample_x = 32'sd0;
        sample_y = 32'sd0;

        calculated = '0;
        calculated.tag = in_data.tag;
        calculated.area = area;
        calculated.edge0_dx = dx0;
        calculated.edge0_dy = dy0;
        calculated.edge1_dx = dx1;
        calculated.edge1_dy = dy1;
        calculated.edge2_dx = dx2;
        calculated.edge2_dy = dy2;
        calculated.top_left[0] = (dy0 < 0) || ((dy0 == 0) && (dx0 > 0));
        calculated.top_left[1] = (dy1 < 0) || ((dy1 == 0) && (dx1 > 0));
        calculated.top_left[2] = (dy2 < 0) || ((dy2 == 0) && (dx2 > 0));
        calculated.edge0_step_x = -(dy0_32 <<< 4);
        calculated.edge0_step_y =  (dx0_32 <<< 4);
        calculated.edge1_step_x = -(dy1_32 <<< 4);
        calculated.edge1_step_y =  (dx1_32 <<< 4);
        calculated.edge2_step_x = -(dy2_32 <<< 4);
        calculated.edge2_step_y =  (dx2_32 <<< 4);

        calculated.r_start = in_data.r_start;
        calculated.g_start = in_data.g_start;
        calculated.b_start = in_data.b_start;
        calculated.z_start = in_data.z_start;
        calculated.r_dx = in_data.r_dx;
        calculated.g_dx = in_data.g_dx;
        calculated.b_dx = in_data.b_dx;
        calculated.z_dx = in_data.z_dx;
        calculated.r_dy = in_data.r_dy;
        calculated.g_dy = in_data.g_dy;
        calculated.b_dy = in_data.b_dy;
        calculated.z_dy = in_data.z_dy;

        if (area == 0) begin
            calculated.classification = gfx_pkg::TRI_SETUP_DEGENERATE;
        end else if (area < 0) begin
            calculated.classification = gfx_pkg::TRI_SETUP_BACKFACE;
        end else if (!bbox_nonempty) begin
            calculated.classification = gfx_pkg::TRI_SETUP_EMPTY;
        end else begin
            calculated.classification = gfx_pkg::TRI_SETUP_RASTER;
            calculated.xmin = (xmin_raw < 0) ? 9'd0 : ((xmin_raw > 319) ? 9'd319 : xmin_raw[8:0]);
            calculated.xmax = (xmax_raw < 0) ? 9'd0 : ((xmax_raw > 319) ? 9'd319 : xmax_raw[8:0]);
            calculated.ymin = (ymin_raw < 0) ? 8'd0 : ((ymin_raw > 239) ? 8'd239 : ymin_raw[7:0]);
            calculated.ymax = (ymax_raw < 0) ? 8'd0 : ((ymax_raw > 239) ? 8'd239 : ymax_raw[7:0]);
            sample_x = ($signed({23'd0, calculated.xmin}) <<< 4) + 32'sd8;
            sample_y = ($signed({24'd0, calculated.ymin}) <<< 4) + 32'sd8;
            calculated.e0_init = dx0_32 * (sample_y - y0_32) - dy0_32 * (sample_x - x0_32);
            calculated.e1_init = dx1_32 * (sample_y - y1_32) - dy1_32 * (sample_x - x1_32);
            calculated.e2_init = dx2_32 * (sample_y - y2_32) - dy2_32 * (sample_x - x2_32);
        end
    end

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            out_valid <= 1'b0;
            result_q <= '0;
        end else begin
            if (out_valid && out_ready)
                out_valid <= 1'b0;
            if (in_valid && in_ready) begin
                result_q <= calculated;
                out_valid <= 1'b1;
            end
        end
    end
endmodule
