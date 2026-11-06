module triangle_setup (
    input  logic                            clk_sys,
    input  logic                            rst,
    input  logic                            in_valid,
    output logic                            in_ready,
    input  gfx_pkg::decoded_command_t      in_data,
    output logic                            out_valid,
    input  logic                            out_ready,
    output gfx_pkg::triangle_setup_result_t out_data
);
    typedef struct packed {
        gfx_pkg::decoded_command_t cmd;
        logic signed [15:0] dx0, dy0, dx1, dy1, dx2, dy2;
        logic signed [31:0] area_dx, area_dy;
    } geometry_input_t;

    typedef struct packed {
        geometry_input_t input_data;
        logic signed [31:0] product_a;
        logic signed [31:0] product_b;
    } area_products_t;

    typedef struct packed {
        gfx_pkg::triangle_setup_result_t base;
        logic signed [31:0] e0_sample_dx, e0_sample_dy;
        logic signed [31:0] e1_sample_dx, e1_sample_dy;
        logic signed [31:0] e2_sample_dx, e2_sample_dy;
    } prepared_setup_t;

    logic stage1_valid_q, stage2_valid_q, stage3_valid_q, stage4_valid_q;
    logic stage1_ready, stage2_ready, stage3_ready, stage4_ready;
    geometry_input_t stage1_calculated, stage1_q;
    area_products_t stage2_calculated, stage2_q;
    prepared_setup_t stage3_calculated, stage3_q;
    gfx_pkg::triangle_setup_result_t stage4_calculated, result_q;

    logic signed [31:0] dx0_32, dy0_32, dx1_32, dy1_32, dx2_32, dy2_32;
    logic signed [31:0] area_dx0_32, area_dy0_32;
    logic signed [31:0] x0_32, y0_32, x1_32, y1_32, x2_32, y2_32;
    logic signed [31:0] min_x, max_x, min_y, max_y;
    logic signed [31:0] xmin_raw, xmax_raw, ymin_raw, ymax_raw;
    logic signed [31:0] sample_x, sample_y, area;
    logic signed [31:0] product_a, product_b;
    logic bbox_nonempty;

    assign stage4_ready = !stage4_valid_q || out_ready;
    assign stage3_ready = !stage3_valid_q || stage4_ready;
    assign stage2_ready = !stage2_valid_q || stage3_ready;
    assign stage1_ready = !stage1_valid_q || stage2_ready;
    assign in_ready = stage1_ready;
    assign out_valid = stage4_valid_q;
    assign out_data = result_q;

    // Stage 1: capture source fields and register all coordinate differences.
    always_comb begin
        stage1_calculated = '0;
        stage1_calculated.cmd = in_data;
        stage1_calculated.dx0 = $signed({3'd0, in_data.v1_x}) - $signed({3'd0, in_data.v0_x});
        stage1_calculated.dy0 = $signed({3'd0, in_data.v1_y}) - $signed({3'd0, in_data.v0_y});
        stage1_calculated.dx1 = $signed({3'd0, in_data.v2_x}) - $signed({3'd0, in_data.v1_x});
        stage1_calculated.dy1 = $signed({3'd0, in_data.v2_y}) - $signed({3'd0, in_data.v1_y});
        stage1_calculated.dx2 = $signed({3'd0, in_data.v0_x}) - $signed({3'd0, in_data.v2_x});
        stage1_calculated.dy2 = $signed({3'd0, in_data.v0_y}) - $signed({3'd0, in_data.v2_y});
        stage1_calculated.area_dx = $signed({19'd0, in_data.v2_x}) - $signed({19'd0, in_data.v0_x});
        stage1_calculated.area_dy = $signed({19'd0, in_data.v2_y}) - $signed({19'd0, in_data.v0_y});
    end

    // Stage 2: calculate and register both signed32 AREA products.
    always_comb begin
        area_dx0_32 = {{16{stage1_q.dx0[15]}}, stage1_q.dx0};
        area_dy0_32 = {{16{stage1_q.dy0[15]}}, stage1_q.dy0};
        product_a = area_dx0_32 * stage1_q.area_dy;
        product_b = area_dy0_32 * stage1_q.area_dx;
        stage2_calculated = '0;
        stage2_calculated.input_data = stage1_q;
        stage2_calculated.product_a = product_a;
        stage2_calculated.product_b = product_b;
    end

    // Stage 3: subtract registered products, then prepare all geometry.
    always_comb begin
        x0_32 = $signed({19'd0, stage2_q.input_data.cmd.v0_x});
        y0_32 = $signed({19'd0, stage2_q.input_data.cmd.v0_y});
        x1_32 = $signed({19'd0, stage2_q.input_data.cmd.v1_x});
        y1_32 = $signed({19'd0, stage2_q.input_data.cmd.v1_y});
        x2_32 = $signed({19'd0, stage2_q.input_data.cmd.v2_x});
        y2_32 = $signed({19'd0, stage2_q.input_data.cmd.v2_y});
        dx0_32 = {{16{stage2_q.input_data.dx0[15]}}, stage2_q.input_data.dx0};
        dy0_32 = {{16{stage2_q.input_data.dy0[15]}}, stage2_q.input_data.dy0};
        dx1_32 = {{16{stage2_q.input_data.dx1[15]}}, stage2_q.input_data.dx1};
        dy1_32 = {{16{stage2_q.input_data.dy1[15]}}, stage2_q.input_data.dy1};
        dx2_32 = {{16{stage2_q.input_data.dx2[15]}}, stage2_q.input_data.dx2};
        dy2_32 = {{16{stage2_q.input_data.dy2[15]}}, stage2_q.input_data.dy2};

        if (stage2_q.input_data.cmd.v0_x <= stage2_q.input_data.cmd.v1_x) begin
            min_x = (stage2_q.input_data.cmd.v0_x <= stage2_q.input_data.cmd.v2_x) ? x0_32 : x2_32;
            max_x = (stage2_q.input_data.cmd.v1_x >= stage2_q.input_data.cmd.v2_x) ? x1_32 : x2_32;
        end else begin
            min_x = (stage2_q.input_data.cmd.v1_x <= stage2_q.input_data.cmd.v2_x) ? x1_32 : x2_32;
            max_x = (stage2_q.input_data.cmd.v0_x >= stage2_q.input_data.cmd.v2_x) ? x0_32 : x2_32;
        end
        if (stage2_q.input_data.cmd.v0_y <= stage2_q.input_data.cmd.v1_y) begin
            min_y = (stage2_q.input_data.cmd.v0_y <= stage2_q.input_data.cmd.v2_y) ? y0_32 : y2_32;
            max_y = (stage2_q.input_data.cmd.v1_y >= stage2_q.input_data.cmd.v2_y) ? y1_32 : y2_32;
        end else begin
            min_y = (stage2_q.input_data.cmd.v1_y <= stage2_q.input_data.cmd.v2_y) ? y1_32 : y2_32;
            max_y = (stage2_q.input_data.cmd.v0_y >= stage2_q.input_data.cmd.v2_y) ? y0_32 : y2_32;
        end
        xmin_raw = (min_x + 32'sd7) >>> 4;
        ymin_raw = (min_y + 32'sd7) >>> 4;
        xmax_raw = (max_x < 32'sd8) ? -32'sd1 : ((max_x - 32'sd8) >>> 4);
        ymax_raw = (max_y < 32'sd8) ? -32'sd1 : ((max_y - 32'sd8) >>> 4);
        bbox_nonempty = (xmin_raw <= xmax_raw) && (ymin_raw <= ymax_raw) &&
                        (xmax_raw >= 0) && (ymax_raw >= 0) &&
                        (xmin_raw <= 319) && (ymin_raw <= 239);
        area = stage2_q.product_a - stage2_q.product_b;
        sample_x = 32'sd0;
        sample_y = 32'sd0;
        stage3_calculated = '0;
        stage3_calculated.base.tag = stage2_q.input_data.cmd.tag;
        stage3_calculated.base.area = area;
        stage3_calculated.base.edge0_dx = stage2_q.input_data.dx0;
        stage3_calculated.base.edge0_dy = stage2_q.input_data.dy0;
        stage3_calculated.base.edge1_dx = stage2_q.input_data.dx1;
        stage3_calculated.base.edge1_dy = stage2_q.input_data.dy1;
        stage3_calculated.base.edge2_dx = stage2_q.input_data.dx2;
        stage3_calculated.base.edge2_dy = stage2_q.input_data.dy2;
        stage3_calculated.base.top_left[0] = (stage2_q.input_data.dy0 < 0) || ((stage2_q.input_data.dy0 == 0) && (stage2_q.input_data.dx0 > 0));
        stage3_calculated.base.top_left[1] = (stage2_q.input_data.dy1 < 0) || ((stage2_q.input_data.dy1 == 0) && (stage2_q.input_data.dx1 > 0));
        stage3_calculated.base.top_left[2] = (stage2_q.input_data.dy2 < 0) || ((stage2_q.input_data.dy2 == 0) && (stage2_q.input_data.dx2 > 0));
        stage3_calculated.base.edge0_step_x = -(dy0_32 <<< 4);
        stage3_calculated.base.edge0_step_y =  (dx0_32 <<< 4);
        stage3_calculated.base.edge1_step_x = -(dy1_32 <<< 4);
        stage3_calculated.base.edge1_step_y =  (dx1_32 <<< 4);
        stage3_calculated.base.edge2_step_x = -(dy2_32 <<< 4);
        stage3_calculated.base.edge2_step_y =  (dx2_32 <<< 4);
        stage3_calculated.base.r_start = stage2_q.input_data.cmd.r_start;
        stage3_calculated.base.g_start = stage2_q.input_data.cmd.g_start;
        stage3_calculated.base.b_start = stage2_q.input_data.cmd.b_start;
        stage3_calculated.base.z_start = stage2_q.input_data.cmd.z_start;
        stage3_calculated.base.r_dx = stage2_q.input_data.cmd.r_dx;
        stage3_calculated.base.g_dx = stage2_q.input_data.cmd.g_dx;
        stage3_calculated.base.b_dx = stage2_q.input_data.cmd.b_dx;
        stage3_calculated.base.z_dx = stage2_q.input_data.cmd.z_dx;
        stage3_calculated.base.r_dy = stage2_q.input_data.cmd.r_dy;
        stage3_calculated.base.g_dy = stage2_q.input_data.cmd.g_dy;
        stage3_calculated.base.b_dy = stage2_q.input_data.cmd.b_dy;
        stage3_calculated.base.z_dy = stage2_q.input_data.cmd.z_dy;

        if (area == 0) begin
            stage3_calculated.base.classification = gfx_pkg::TRI_SETUP_DEGENERATE;
        end else if (area < 0) begin
            stage3_calculated.base.classification = gfx_pkg::TRI_SETUP_BACKFACE;
        end else if (!bbox_nonempty) begin
            stage3_calculated.base.classification = gfx_pkg::TRI_SETUP_EMPTY;
        end else begin
            stage3_calculated.base.classification = gfx_pkg::TRI_SETUP_RASTER;
            stage3_calculated.base.xmin = (xmin_raw < 0) ? 9'd0 : ((xmin_raw > 319) ? 9'd319 : xmin_raw[8:0]);
            stage3_calculated.base.xmax = (xmax_raw < 0) ? 9'd0 : ((xmax_raw > 319) ? 9'd319 : xmax_raw[8:0]);
            stage3_calculated.base.ymin = (ymin_raw < 0) ? 8'd0 : ((ymin_raw > 239) ? 8'd239 : ymin_raw[7:0]);
            stage3_calculated.base.ymax = (ymax_raw < 0) ? 8'd0 : ((ymax_raw > 239) ? 8'd239 : ymax_raw[7:0]);
            sample_x = ($signed({23'd0, stage3_calculated.base.xmin}) <<< 4) + 32'sd8;
            sample_y = ($signed({24'd0, stage3_calculated.base.ymin}) <<< 4) + 32'sd8;
            stage3_calculated.e0_sample_dx = sample_x - x0_32;
            stage3_calculated.e0_sample_dy = sample_y - y0_32;
            stage3_calculated.e1_sample_dx = sample_x - x1_32;
            stage3_calculated.e1_sample_dy = sample_y - y1_32;
            stage3_calculated.e2_sample_dx = sample_x - x2_32;
            stage3_calculated.e2_sample_dy = sample_y - y2_32;
        end
    end

    // Stage 4: initial edge products consume only registered Stage-3 geometry.
    always_comb begin
        stage4_calculated = stage3_q.base;
        if (stage3_q.base.classification == gfx_pkg::TRI_SETUP_RASTER) begin
            stage4_calculated.e0_init =
                $signed({{16{stage3_q.base.edge0_dx[15]}}, stage3_q.base.edge0_dx}) * stage3_q.e0_sample_dy -
                $signed({{16{stage3_q.base.edge0_dy[15]}}, stage3_q.base.edge0_dy}) * stage3_q.e0_sample_dx;
            stage4_calculated.e1_init =
                $signed({{16{stage3_q.base.edge1_dx[15]}}, stage3_q.base.edge1_dx}) * stage3_q.e1_sample_dy -
                $signed({{16{stage3_q.base.edge1_dy[15]}}, stage3_q.base.edge1_dy}) * stage3_q.e1_sample_dx;
            stage4_calculated.e2_init =
                $signed({{16{stage3_q.base.edge2_dx[15]}}, stage3_q.base.edge2_dx}) * stage3_q.e2_sample_dy -
                $signed({{16{stage3_q.base.edge2_dy[15]}}, stage3_q.base.edge2_dy}) * stage3_q.e2_sample_dx;
        end else begin
            stage4_calculated.e0_init = 32'sd0;
            stage4_calculated.e1_init = 32'sd0;
            stage4_calculated.e2_init = 32'sd0;
        end
    end

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            stage1_valid_q <= 1'b0;
            stage2_valid_q <= 1'b0;
            stage3_valid_q <= 1'b0;
            stage4_valid_q <= 1'b0;
            stage1_q <= '0;
            stage2_q <= '0;
            stage3_q <= '0;
            result_q <= '0;
        end else begin
            if (stage4_ready) begin
                stage4_valid_q <= stage3_valid_q;
                if (stage3_valid_q)
                    result_q <= stage4_calculated;
            end
            if (stage3_ready) begin
                stage3_valid_q <= stage2_valid_q;
                if (stage2_valid_q)
                    stage3_q <= stage3_calculated;
            end
            if (stage2_ready) begin
                stage2_valid_q <= stage1_valid_q;
                if (stage1_valid_q)
                    stage2_q <= stage2_calculated;
            end
            if (stage1_ready) begin
                stage1_valid_q <= in_valid;
                if (in_valid)
                    stage1_q <= stage1_calculated;
            end
        end
    end
endmodule
