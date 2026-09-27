module cmd_fifo #(
    parameter int unsigned WIDTH = 32,
    parameter int unsigned DEPTH = 1024,
    parameter int unsigned PTR_WIDTH = $clog2(DEPTH),
    parameter int unsigned LEVEL_WIDTH = $clog2(DEPTH + 1)
) (
    input logic clk_sys, input logic rst,
    input logic in_valid, output logic in_ready, input logic [WIDTH-1:0] in_data,
    output logic out_valid, input logic out_ready, output logic [WIDTH-1:0] out_data,
    output logic [LEVEL_WIDTH-1:0] level
);
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] rd_ptr, wr_ptr;
    wire pop = out_valid && out_ready;
    wire push = in_valid && in_ready;

    always_comb begin
        out_valid = (level != '0);
        in_ready = (level < LEVEL_WIDTH'(DEPTH)) || pop;
    end

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            rd_ptr <= '0; wr_ptr <= '0; level <= '0; out_data <= '0;
        end else begin
            case ({push, pop})
                2'b10: level <= level + 1'b1;
                2'b01: level <= level - 1'b1;
                default: level <= level;
            endcase
            if (push) begin
                mem[wr_ptr] <= in_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (pop) begin
                rd_ptr <= rd_ptr + 1'b1;
                if (level == 1) begin
                    if (push) out_data <= in_data;
                end else begin
                    out_data <= mem[rd_ptr + 1'b1];
                end
            end else if (push && (level == 0)) begin
                out_data <= in_data;
            end
        end
    end
endmodule
