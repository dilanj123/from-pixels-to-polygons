module raster_walk #(
    parameter int unsigned COORD_X_WIDTH = 9,
    parameter int unsigned COORD_Y_WIDTH = 8
) (
    input  logic                              clk_sys,
    input  logic                              rst,
    input  logic                              walk_in_valid,
    output logic                              walk_in_ready,
    input  gfx_pkg::triangle_setup_result_t  walk_in_payload,
    output logic                              covered_valid,
    input  logic                              covered_ready,
    output logic [COORD_X_WIDTH-1:0]          covered_x,
    output logic [COORD_Y_WIDTH-1:0]          covered_y,
    output logic                              busy,
    output logic                              walk_complete
);
    logic [COORD_X_WIDTH-1:0] x_q, xmin_q, xmax_q;
    logic [COORD_Y_WIDTH-1:0] y_q, ymin_q, ymax_q;
    logic [2:0] top_left_q;
    logic signed [31:0] step_x0_q, step_x1_q, step_x2_q;
    logic signed [31:0] step_y0_q, step_y1_q, step_y2_q;
    logic signed [31:0] row_e0_q, row_e1_q, row_e2_q;
    logic signed [31:0] current_e0_q, current_e1_q, current_e2_q;
    logic inside0, inside1, inside2, covered;
    logic candidate_retire;
    logic final_candidate;

    assign walk_in_ready = !busy;

    assign inside0 = (current_e0_q > 0) ||
                     ((current_e0_q == 0) && top_left_q[0]);
    assign inside1 = (current_e1_q > 0) ||
                     ((current_e1_q == 0) && top_left_q[1]);
    assign inside2 = (current_e2_q > 0) ||
                     ((current_e2_q == 0) && top_left_q[2]);
    assign covered = inside0 && inside1 && inside2;

    assign covered_valid = busy && covered;
    assign covered_x = x_q;
    assign covered_y = y_q;

    assign candidate_retire = busy && (!covered || covered_ready);
    assign final_candidate = busy && (x_q == xmax_q) && (y_q == ymax_q);

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            busy <= 1'b0;
            walk_complete <= 1'b0;
            x_q <= '0;
            y_q <= '0;
            xmin_q <= '0;
            xmax_q <= '0;
            ymin_q <= '0;
            ymax_q <= '0;
            top_left_q <= '0;
            step_x0_q <= '0;
            step_x1_q <= '0;
            step_x2_q <= '0;
            step_y0_q <= '0;
            step_y1_q <= '0;
            step_y2_q <= '0;
            row_e0_q <= '0;
            row_e1_q <= '0;
            row_e2_q <= '0;
            current_e0_q <= '0;
            current_e1_q <= '0;
            current_e2_q <= '0;
        end else begin
            walk_complete <= 1'b0;

            if (!busy) begin
                if (walk_in_valid && walk_in_ready) begin
                    busy <= 1'b1;
                    xmin_q <= walk_in_payload.xmin;
                    xmax_q <= walk_in_payload.xmax;
                    ymin_q <= walk_in_payload.ymin;
                    ymax_q <= walk_in_payload.ymax;
                    x_q <= walk_in_payload.xmin;
                    y_q <= walk_in_payload.ymin;
                    top_left_q <= walk_in_payload.top_left;
                    step_x0_q <= walk_in_payload.edge0_step_x;
                    step_x1_q <= walk_in_payload.edge1_step_x;
                    step_x2_q <= walk_in_payload.edge2_step_x;
                    step_y0_q <= walk_in_payload.edge0_step_y;
                    step_y1_q <= walk_in_payload.edge1_step_y;
                    step_y2_q <= walk_in_payload.edge2_step_y;
                    row_e0_q <= walk_in_payload.e0_init;
                    row_e1_q <= walk_in_payload.e1_init;
                    row_e2_q <= walk_in_payload.e2_init;
                    current_e0_q <= walk_in_payload.e0_init;
                    current_e1_q <= walk_in_payload.e1_init;
                    current_e2_q <= walk_in_payload.e2_init;
                end
            end else if (candidate_retire) begin
                if (final_candidate) begin
                    busy <= 1'b0;
                    walk_complete <= 1'b1;
                end else if (x_q < xmax_q) begin
                    x_q <= x_q + 1'b1;
                    current_e0_q <= current_e0_q + step_x0_q;
                    current_e1_q <= current_e1_q + step_x1_q;
                    current_e2_q <= current_e2_q + step_x2_q;
                end else begin
                    x_q <= xmin_q;
                    y_q <= y_q + 1'b1;
                    row_e0_q <= row_e0_q + step_y0_q;
                    row_e1_q <= row_e1_q + step_y1_q;
                    row_e2_q <= row_e2_q + step_y2_q;
                    current_e0_q <= row_e0_q + step_y0_q;
                    current_e1_q <= row_e1_q + step_y1_q;
                    current_e2_q <= row_e2_q + step_y2_q;
                end
            end
        end
    end
endmodule
