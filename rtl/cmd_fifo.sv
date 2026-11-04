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
    (* ram_style = "block", no_rw_check *) logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] rd_ptr, wr_ptr;
    logic [WIDTH-1:0] ram_data_q, bypass_data_q;
    logic head_from_ram_q;
    wire pop = out_valid && out_ready;
    wire push = in_valid && in_ready;

    always_comb begin
        out_valid = (level != '0);
        in_ready = (level < LEVEL_WIDTH'(DEPTH)) || pop;
        // Data is meaningful only while valid. This also masks the unreset
        // block-RAM output during reset/empty without resetting the RAM.
        out_data = out_valid ? (head_from_ram_q ? ram_data_q : bypass_data_q) : '0;
    end

    // Keep memory access out of the asynchronously reset control process.
    // The enabled read is synchronous and can map to the ECP5 block RAM. When
    // a non-final head word is consumed, the next queued word is read on that
    // edge, preserving the existing one-word-per-cycle output behavior.
    always_ff @(posedge clk_sys) begin
        if (!rst) begin
            if (push)
                mem[wr_ptr] <= in_data;

            if (pop && (level > 1))
                ram_data_q <= mem[rd_ptr + 1'b1];
        end
    end

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            rd_ptr <= '0; wr_ptr <= '0; level <= '0;
            head_from_ram_q <= 1'b0;
            bypass_data_q <= '0;
        end else begin
            case ({push, pop})
                2'b10: level <= level + 1'b1;
                2'b01: level <= level - 1'b1;
                default: level <= level;
            endcase
            if (push) begin
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (pop) begin
                rd_ptr <= rd_ptr + 1'b1;
                if (level > 1)
                    head_from_ram_q <= 1'b1;
                else if (push) begin
                    head_from_ram_q <= 1'b0;
                    bypass_data_q <= in_data;
                end
            end else if (push && (level == 0)) begin
                head_from_ram_q <= 1'b0;
                bypass_data_q <= in_data;
            end
        end
    end
endmodule
