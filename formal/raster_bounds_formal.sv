module raster_bounds_formal;
    (* gclk *) logic clk;
    logic rst, in_valid, in_ready, covered_valid, covered_ready, retired, busy, complete;
    gfx_pkg::triangle_setup_result_t payload;
    logic [3:0] x;
    logic [2:0] y;
    logic signed [41:0] r,g,b,z;
    logic past_valid;

    raster_walk #(.COORD_X_WIDTH(4), .COORD_Y_WIDTH(3)) dut (
        .clk_sys(clk), .rst(rst), .walk_in_valid(in_valid), .walk_in_ready(in_ready),
        .walk_in_payload(payload), .covered_valid(covered_valid),
        .covered_ready(covered_ready), .covered_x(x), .covered_y(y),
        .covered_r_raw(r), .covered_g_raw(g), .covered_b_raw(b), .covered_z_raw(z),
        .candidate_retired(retired), .busy(busy), .walk_complete(complete)
    );

    initial begin
        past_valid=0;
        assume(rst);
        assume(in_valid);
        assume(covered_ready);
    end
    always_comb begin
        payload='0;
        payload.classification=gfx_pkg::TRI_SETUP_RASTER;
        payload.xmin=0; payload.xmax=3;
        payload.ymin=0; payload.ymax=2;
        payload.top_left=3'b111;
    end
    always_ff @(posedge clk) begin
        if (!past_valid) begin past_valid<=1; assume(rst); end
        else assume(!rst);
        assume(in_valid);
        assume(covered_ready);
        if (!rst) begin
            if (busy) begin
                assert(x <= 3);
                assert(y <= 2);
            end
            if (retired) assert(busy);
            if (complete) assert($past(retired && (x==3) && (y==2)));
        end
        cover(complete);
    end
endmodule
