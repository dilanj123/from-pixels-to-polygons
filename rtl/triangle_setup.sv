module triangle_setup (
    input  logic                           clk_sys,
    input  logic                           rst,
    input  logic                           in_valid,
    output logic                           in_ready,
    input  gfx_pkg::decoded_command_t     in_data,
    output logic                           out_valid,
    input  logic                           out_ready,
    output gfx_pkg::triangle_setup_result_t out_data
);
    typedef struct packed {
        gfx_pkg::triangle_setup_result_t base;
        logic signed [31:0] e0_sample_dx;
        logic signed [31:0] e0_sample_dy;
        logic signed [31:0] e1_sample_dx;
        logic signed [31:0] e1_sample_dy;
        logic signed [31:0] e2_sample_dx;
        logic signed [31:0] e2_sample_dy;
    } prepared_setup_t;

    logic prep_valid_q, out_valid_q;
    logic prep_slot_ready, out_slot_ready;
    prepared_setup_t prep_calculated, prep_q;
    gfx_pkg::triangle_setup_result_t result_calculated, result_q;

    logic signed [15:0] dx0, dy0, dx1, dy1, dx2, dy2;
    logic signed [31:0] dx0_32, dy0_32, dx1_32, dy1_32, dx2_32, dy2_32;
    logic signed [31:0] x0_32, y0_32, x1_32, y1_32, x2_32, y2_32;
    logic signed [31:0] min_x, max_x, min_y, max_y;
    logic signed [31:0] xmin_raw, xmax_raw, ymin_raw, ymax_raw;
    logic signed [31:0] sample_x, sample_y;
    logic signed [31:0] area;
    logic bbox_nonempty;

    assign out_slot_ready = !out_valid_q || out_ready;
    assign prep_slot_ready = !prep_valid_q || out_slot_ready;
    assign in_ready = prep_slot_ready;
    assign out_valid = out_valid_q;
    assign out_data = result_q;

    // Stage 1: prepare geometry and register the sample-relative edge inputs.
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

        prep_calculated = '0;
        prep_calculated.base.tag = in_data.tag;
        prep_calculated.base.area = area;
        prep_calculated.base.edge0_dx = dx0;
        prep_calculated.base.edge0_dy = dy0;
        prep_calculated.base.edge1_dx = dx1;
        prep_calculated.base.edge1_dy = dy1;
        prep_calculated.base.edge2_dx = dx2;
        prep_calculated.base.edge2_dy = dy2;
        prep_calculated.base.top_left[0] = (dy0 < 0) || ((dy0 == 0) && (dx0 > 0));
        prep_calculated.base.top_left[1] = (dy1 < 0) || ((dy1 == 0) && (dx1 > 0));
        prep_calculated.base.top_left[2] = (dy2 < 0) || ((dy2 == 0) && (dx2 > 0));
        prep_calculated.base.edge0_step_x = -(dy0_32 <<< 4);
        prep_calculated.base.edge0_step_y =  (dx0_32 <<< 4);
        prep_calculated.base.edge1_step_x = -(dy1_32 <<< 4);
        prep_calculated.base.edge1_step_y =  (dx1_32 <<< 4);
        prep_calculated.base.edge2_step_x = -(dy2_32 <<< 4);
        prep_calculated.base.edge2_step_y =  (dx2_32 <<< 4);

        prep_calculated.base.r_start = in_data.r_start;
        prep_calculated.base.g_start = in_data.g_start;
        prep_calculated.base.b_start = in_data.b_start;
        prep_calculated.base.z_start = in_data.z_start;
        prep_calculated.base.r_dx = in_data.r_dx;
        prep_calculated.base.g_dx = in_data.g_dx;
        prep_calculated.base.b_dx = in_data.b_dx;
        prep_calculated.base.z_dx = in_data.z_dx;
        prep_calculated.base.r_dy = in_data.r_dy;
        prep_calculated.base.g_dy = in_data.g_dy;
        prep_calculated.base.b_dy = in_data.b_dy;
        prep_calculated.base.z_dy = in_data.z_dy;

        if (area == 0) begin
            prep_calculated.base.classification = gfx_pkg::TRI_SETUP_DEGENERATE;
        end else if (area < 0) begin
            prep_calculated.base.classification = gfx_pkg::TRI_SETUP_BACKFACE;
        end else if (!bbox_nonempty) begin
            prep_calculated.base.classification = gfx_pkg::TRI_SETUP_EMPTY;
        end else begin
            prep_calculated.base.classification = gfx_pkg::TRI_SETUP_RASTER;
            prep_calculated.base.xmin = (xmin_raw < 0) ? 9'd0 : ((xmin_raw > 319) ? 9'd319 : xmin_raw[8:0]);
            prep_calculated.base.xmax = (xmax_raw < 0) ? 9'd0 : ((xmax_raw > 319) ? 9'd319 : xmax_raw[8:0]);
            prep_calculated.base.ymin = (ymin_raw < 0) ? 8'd0 : ((ymin_raw > 239) ? 8'd239 : ymin_raw[7:0]);
            prep_calculated.base.ymax = (ymax_raw < 0) ? 8'd0 : ((ymax_raw > 239) ? 8'd239 : ymax_raw[7:0]);
            sample_x = ($signed({23'd0, prep_calculated.base.xmin}) <<< 4) + 32'sd8;
            sample_y = ($signed({24'd0, prep_calculated.base.ymin}) <<< 4) + 32'sd8;
            prep_calculated.e0_sample_dx = sample_x - x0_32;
            prep_calculated.e0_sample_dy = sample_y - y0_32;
            prep_calculated.e1_sample_dx = sample_x - x1_32;
            prep_calculated.e1_sample_dy = sample_y - y1_32;
            prep_calculated.e2_sample_dx = sample_x - x2_32;
            prep_calculated.e2_sample_dy = sample_y - y2_32;
        end
    end

    // Stage 2: initial edge products consume only the registered preparation.
    always_comb begin
        result_calculated = prep_q.base;
        if (prep_q.base.classification == gfx_pkg::TRI_SETUP_RASTER) begin
            result_calculated.e0_init =
                $signed({{16{prep_q.base.edge0_dx[15]}}, prep_q.base.edge0_dx}) * prep_q.e0_sample_dy -
                $signed({{16{prep_q.base.edge0_dy[15]}}, prep_q.base.edge0_dy}) * prep_q.e0_sample_dx;
            result_calculated.e1_init =
                $signed({{16{prep_q.base.edge1_dx[15]}}, prep_q.base.edge1_dx}) * prep_q.e1_sample_dy -
                $signed({{16{prep_q.base.edge1_dy[15]}}, prep_q.base.edge1_dy}) * prep_q.e1_sample_dx;
            result_calculated.e2_init =
                $signed({{16{prep_q.base.edge2_dx[15]}}, prep_q.base.edge2_dx}) * prep_q.e2_sample_dy -
                $signed({{16{prep_q.base.edge2_dy[15]}}, prep_q.base.edge2_dy}) * prep_q.e2_sample_dx;
        end else begin
            result_calculated.e0_init = 32'sd0;
            result_calculated.e1_init = 32'sd0;
            result_calculated.e2_init = 32'sd0;
        end
    end

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            prep_valid_q <= 1'b0;
            out_valid_q <= 1'b0;
            prep_q <= '0;
            result_q <= '0;
        end else begin
            if (out_slot_ready) begin
                out_valid_q <= prep_valid_q;
                if (prep_valid_q)
                    result_q <= result_calculated;
            end
            if (prep_slot_ready) begin
                prep_valid_q <= in_valid;
                if (in_valid)
                    prep_q <= prep_calculated;
            end
        end
    end
endmodule
