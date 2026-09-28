module renderer_core (
    input  logic                      clk_sys,
    input  logic                      rst,
    input  logic                      render_cmd_valid,
    output logic                      render_cmd_ready,
    input  gfx_pkg::decoded_command_t render_cmd,
    output logic                      renderer_quiescent
);
    typedef enum logic [2:0] {
        S_IDLE,
        S_CLEAR,
        S_FRAME_ACTIVE,
        S_TRI_SETUP,
        S_TRI_WALK,
        S_TRI_DRAIN
    } state_t;

    state_t state_q;
    gfx_pkg::decoded_command_t draw_q;
    gfx_pkg::triangle_setup_result_t setup_q;
    logic [7:0] clear_colour_q;
    logic setup_submitted_q;

    logic clear_start_valid, clear_start_ready, clear_busy, clear_done;
    logic clear_fb_we, clear_z_we;
    logic [16:0] clear_fb_addr, clear_z_addr;
    logic [7:0] clear_fb_wdata, clear_z_wdata;

    logic setup_in_valid, setup_in_ready, setup_out_valid, setup_out_ready;
    gfx_pkg::triangle_setup_result_t setup_out_data;

    logic walk_in_valid, walk_in_ready, walk_busy, walk_complete;
    logic covered_valid, covered_ready;
    logic [8:0] covered_x;
    logic [7:0] covered_y;
    logic signed [41:0] covered_r_raw, covered_g_raw, covered_b_raw, covered_z_raw;

    logic frag_ready;
    logic z_rd_en, z_wr_en, fb_wr_en, fragment_empty;
    logic [16:0] z_rd_addr, z_wr_addr, fb_wr_addr;
    logic [7:0] z_rd_data, z_wr_data, fb_wr_data;

    logic [7:0] fb_pix_rdata, fb_sys_rdata;
    logic [7:0] z_unused_rdata;

    logic in_receptive_state;
    logic command_fire;
    logic clear_owner, fragment_owner;

    assign in_receptive_state = (state_q == S_IDLE) || (state_q == S_FRAME_ACTIVE);
    assign render_cmd_ready = in_receptive_state;
    assign command_fire = render_cmd_valid && render_cmd_ready;

    assign clear_start_valid = command_fire &&
                               (render_cmd.opcode == gfx_pkg::CMD_BEGIN_FRAME) &&
                               (state_q == S_IDLE);

    assign setup_in_valid = (state_q == S_TRI_SETUP) && !setup_submitted_q;
    assign setup_out_ready = (state_q == S_TRI_SETUP);

    assign walk_in_valid = (state_q == S_TRI_WALK) && !walk_complete;
    assign covered_ready = frag_ready;

    assign clear_owner = (state_q == S_CLEAR);
    assign fragment_owner = (state_q == S_TRI_WALK) || (state_q == S_TRI_DRAIN);

    clear_engine clear_i (
        .clk_sys(clk_sys), .rst(rst),
        .start_valid(clear_start_valid), .start_ready(clear_start_ready),
        .clear_rgb332(clear_start_valid ? render_cmd.clear_rgb332 : clear_colour_q),
        .busy(clear_busy), .done(clear_done),
        .fb_we(clear_fb_we), .fb_addr(clear_fb_addr), .fb_wdata(clear_fb_wdata),
        .z_we(clear_z_we), .z_addr(clear_z_addr), .z_wdata(clear_z_wdata)
    );

    triangle_setup setup_i (
        .clk_sys(clk_sys), .rst(rst),
        .in_valid(setup_in_valid), .in_ready(setup_in_ready), .in_data(draw_q),
        .out_valid(setup_out_valid), .out_ready(setup_out_ready), .out_data(setup_out_data)
    );

    raster_walk walk_i (
        .clk_sys(clk_sys), .rst(rst),
        .walk_in_valid(walk_in_valid), .walk_in_ready(walk_in_ready),
        .walk_in_payload(setup_q), .covered_valid(covered_valid),
        .covered_ready(covered_ready), .covered_x(covered_x), .covered_y(covered_y),
        .covered_r_raw(covered_r_raw), .covered_g_raw(covered_g_raw),
        .covered_b_raw(covered_b_raw), .covered_z_raw(covered_z_raw),
        .busy(walk_busy), .walk_complete(walk_complete)
    );

    fragment_z fragment_i (
        .clk_sys(clk_sys), .rst(rst),
        .frag_valid(covered_valid), .frag_ready(frag_ready),
        .frag_x(covered_x), .frag_y(covered_y),
        .frag_r_raw(covered_r_raw), .frag_g_raw(covered_g_raw),
        .frag_b_raw(covered_b_raw), .frag_z_raw(covered_z_raw),
        .z_rd_en(z_rd_en), .z_rd_addr(z_rd_addr), .z_rd_data(z_rd_data),
        .z_wr_en(z_wr_en), .z_wr_addr(z_wr_addr), .z_wr_data(z_wr_data),
        .fb_wr_en(fb_wr_en), .fb_wr_addr(fb_wr_addr), .fb_wr_data(fb_wr_data),
        .pipeline_empty(fragment_empty)
    );

    framebuffer_dp framebuffer_i (
        .clk_pix(clk_sys), .pix_addr('0), .pix_rdata(fb_pix_rdata),
        .clk_sys(clk_sys),
        .sys_addr(clear_owner ? clear_fb_addr : fb_wr_addr),
        .sys_we(clear_owner ? clear_fb_we : (fragment_owner && fb_wr_en)),
        .sys_wdata(clear_owner ? clear_fb_wdata : fb_wr_data),
        .sys_rdata(fb_sys_rdata)
    );

    zbuffer zbuffer_i (
        .clk_sys(clk_sys),
        .rd_addr(z_rd_addr), .rd_data(z_rd_data),
        .wr_en(clear_owner ? clear_z_we : (fragment_owner && z_wr_en)),
        .wr_addr(clear_owner ? clear_z_addr : z_wr_addr),
        .wr_data(clear_owner ? clear_z_wdata : z_wr_data)
    );

    assign renderer_quiescent = (state_q == S_FRAME_ACTIVE) &&
                                !clear_busy && !setup_out_valid &&
                                !walk_busy && fragment_empty;

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            state_q <= S_IDLE;
            draw_q <= '0;
            setup_q <= '0;
            clear_colour_q <= '0;
            setup_submitted_q <= 1'b0;
        end else begin
            case (state_q)
                S_IDLE: begin
                    if (command_fire) begin
                        if (render_cmd.opcode == gfx_pkg::CMD_BEGIN_FRAME) begin
                            clear_colour_q <= render_cmd.clear_rgb332;
                            state_q <= S_CLEAR;
                        end
                    end
                end
                S_CLEAR: begin
                    if (clear_done)
                        state_q <= S_FRAME_ACTIVE;
                end
                S_FRAME_ACTIVE: begin
                    if (command_fire && (render_cmd.opcode == gfx_pkg::CMD_DRAW_TRIANGLE)) begin
                        draw_q <= render_cmd;
                        setup_submitted_q <= 1'b0;
                        state_q <= S_TRI_SETUP;
                    end
                end
                S_TRI_SETUP: begin
                    if (setup_in_valid && setup_in_ready)
                        setup_submitted_q <= 1'b1;
                    if (setup_out_valid && setup_out_ready) begin
                        setup_q <= setup_out_data;
                        setup_submitted_q <= 1'b0;
                        if (setup_out_data.classification == gfx_pkg::TRI_SETUP_RASTER)
                            state_q <= S_TRI_WALK;
                        else
                            state_q <= S_FRAME_ACTIVE;
                    end
                end
                S_TRI_WALK: begin
                    if (walk_complete)
                        state_q <= S_TRI_DRAIN;
                end
                S_TRI_DRAIN: begin
                    if (fragment_empty)
                        state_q <= S_FRAME_ACTIVE;
                end
                default: state_q <= S_IDLE;
            endcase
        end
    end

endmodule
