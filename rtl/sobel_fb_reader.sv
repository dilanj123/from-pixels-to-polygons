module sobel_fb_reader (
    input  logic        clk_sys,
    input  logic        rst,
    input  logic        start_valid,
    output logic        start_ready,
    output logic        busy,
    output logic        done,
    output logic        fb_rd_en,
    output logic [16:0] fb_rd_addr,
    input  logic [7:0]  fb_rd_data,
    output logic [23:0] m_tdata,
    output logic        m_tvalid,
    input  logic        m_tready,
    output logic        m_tuser,
    output logic        m_tlast
);
    localparam logic [16:0] FRAME_PIXELS = 17'd76800;

    logic [16:0] issue_index_q;
    logic [16:0] accepted_index_q;
    logic [8:0] accepted_col_q;
    logic [1:0] fifo_count_q;
    logic [23:0] pixel_fifo [0:1];
    logic fifo_wr_ptr_q, fifo_rd_ptr_q;
    logic read_pending_q;
    logic push_pixel, pop_pixel;

    function automatic [23:0] rgb332_to_rgb888(input logic [7:0] pixel);
        logic [2:0] red3, green3;
        logic [1:0] blue2;
        begin
            red3 = pixel[7:5];
            green3 = pixel[4:2];
            blue2 = pixel[1:0];
            rgb332_to_rgb888 = {{red3, red3, red3[2:1]},
                                {green3, green3, green3[2:1]},
                                {blue2, blue2, blue2, blue2}};
        end
    endfunction

    assign start_ready = !busy && !rst;
    assign m_tvalid = (fifo_count_q != 0) && !rst;
    assign m_tdata = pixel_fifo[fifo_rd_ptr_q];
    assign m_tuser = (accepted_index_q == 0);
    assign m_tlast = (accepted_col_q == 9'd319);
    assign pop_pixel = m_tvalid && m_tready;
    assign push_pixel = read_pending_q;

    always_comb begin
        fb_rd_en = 1'b0;
        if (busy && !rst && (issue_index_q < FRAME_PIXELS) &&
            ({1'b0, fifo_count_q} + read_pending_q < 3'd2))
            fb_rd_en = 1'b1;
    end
    assign fb_rd_addr = issue_index_q;

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            busy <= 1'b0;
            done <= 1'b0;
            issue_index_q <= 0;
            accepted_index_q <= 0;
            accepted_col_q <= 0;
            fifo_count_q <= 0;
            fifo_wr_ptr_q <= 0;
            fifo_rd_ptr_q <= 0;
            read_pending_q <= 1'b0;
        end else begin
            done <= 1'b0;
            read_pending_q <= fb_rd_en;

            if (start_valid && start_ready) begin
                busy <= 1'b1;
                issue_index_q <= 0;
                accepted_index_q <= 0;
                accepted_col_q <= 0;
                fifo_count_q <= 0;
                fifo_wr_ptr_q <= 0;
                fifo_rd_ptr_q <= 0;
            end else begin
                if (fb_rd_en)
                    issue_index_q <= issue_index_q + 1'b1;

                if (push_pixel) begin
                    pixel_fifo[fifo_wr_ptr_q] <= rgb332_to_rgb888(fb_rd_data);
                    fifo_wr_ptr_q <= ~fifo_wr_ptr_q;
                end

                if (pop_pixel) begin
                    fifo_rd_ptr_q <= ~fifo_rd_ptr_q;
                    accepted_index_q <= accepted_index_q + 1'b1;
                    if (accepted_col_q == 9'd319)
                        accepted_col_q <= 0;
                    else
                        accepted_col_q <= accepted_col_q + 1'b1;
                    if (accepted_index_q == FRAME_PIXELS - 1'b1) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                end

                case ({push_pixel, pop_pixel})
                    2'b10: fifo_count_q <= fifo_count_q + 1'b1;
                    2'b01: fifo_count_q <= fifo_count_q - 1'b1;
                    default: fifo_count_q <= fifo_count_q;
                endcase
            end
        end
    end
endmodule
