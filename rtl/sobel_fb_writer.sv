module sobel_fb_writer (
    input  logic        clk_sys,
    input  logic        rst,
    input  logic        start_valid,
    output logic        start_ready,
    output logic        busy,
    output logic        done,
    output logic        error,
    input  logic [7:0]  s_tdata,
    input  logic        s_tvalid,
    output logic        s_tready,
    input  logic        s_tuser,
    input  logic        s_tlast,
    output logic        fb_wr_en,
    output logic [16:0] fb_wr_addr,
    output logic [7:0]  fb_wr_data
);
    localparam logic [16:0] FRAME_PIXELS = 17'd76800;
    logic [16:0] accepted_index_q;
    logic [8:0] accepted_col_q;
    logic metadata_ok;
    logic transfer;

    assign start_ready = !busy && !error && !rst;
    assign s_tready = busy && !error && !rst;
    assign transfer = s_tvalid && s_tready;
    assign metadata_ok = (s_tuser == (accepted_index_q == 0)) &&
                         (s_tlast == (accepted_col_q == 9'd319));
    assign fb_wr_en = transfer && metadata_ok;
    assign fb_wr_addr = accepted_index_q;
    assign fb_wr_data = {s_tdata[7:5], s_tdata[7:5], s_tdata[7:6]};

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            accepted_index_q <= 0;
            accepted_col_q <= 0;
        end else begin
            done <= 1'b0;
            if (start_valid && start_ready) begin
                busy <= 1'b1;
                error <= 1'b0;
                accepted_index_q <= 0;
                accepted_col_q <= 0;
            end else if (transfer) begin
                if (!metadata_ok) begin
                    error <= 1'b1;
                    busy <= 1'b0;
                end else if (accepted_index_q == FRAME_PIXELS - 1'b1) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    accepted_index_q <= accepted_index_q + 1'b1;
                    if (accepted_col_q == 9'd319)
                        accepted_col_q <= 0;
                    else
                        accepted_col_q <= accepted_col_q + 1'b1;
                end
            end
        end
    end
endmodule
