module cmd_fifo_formal;
    (* gclk *) logic clk;
    logic rst, in_valid, in_ready, out_valid, out_ready;
    logic [31:0] in_data, out_data;
    logic [2:0] level;
    logic past_valid;
    logic [31:0] ghost_mem0, ghost_mem1, ghost_mem2, ghost_mem3;
    logic [1:0] ghost_rd, ghost_wr;
    logic [2:0] ghost_count;
    logic [31:0] ghost_head_data;

    wire ghost_push = in_valid && in_ready;
    wire ghost_pop = out_valid && out_ready;

    // The formal harness uses depth 4 to keep the symbolic memory tractable.
    // The production default remains DEPTH=1024 and LEVEL_WIDTH=11.
    cmd_fifo #(.DEPTH(4), .PTR_WIDTH(2), .LEVEL_WIDTH(3)) dut (
        .clk_sys(clk), .rst(rst), .in_valid(in_valid), .in_ready(in_ready),
        .in_data(in_data), .out_valid(out_valid), .out_ready(out_ready),
        .out_data(out_data), .level(level)
    );

    initial begin
        past_valid = 1'b0;
        assume (rst);
    end

    always_comb begin
        case (ghost_rd)
            2'd0: ghost_head_data = ghost_mem0;
            2'd1: ghost_head_data = ghost_mem1;
            2'd2: ghost_head_data = ghost_mem2;
            default: ghost_head_data = ghost_mem3;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!past_valid) begin
            past_valid <= 1'b1;
            assume (rst);
        end else begin
            assume (!rst);
        end
        if (rst) begin
            assert (level == 0);
            assert (!out_valid);
            ghost_mem0 <= '0;
            ghost_mem1 <= '0;
            ghost_mem2 <= '0;
            ghost_mem3 <= '0;
            ghost_rd <= '0;
            ghost_wr <= '0;
            ghost_count <= '0;
        end
        if (past_valid && !$past(rst)) begin
            assert (level <= 4);
            assert (level == $past(level) +
                (($past(in_valid && in_ready) ? 1 : 0) -
                 ($past(out_valid && out_ready) ? 1 : 0)));
        end
        if (out_valid && !out_ready && past_valid && $past(out_valid && !out_ready))
            assert (out_data == $past(out_data));
        if (level == 4)
            assert (in_ready == out_ready);
        if (level == 0)
            assert (!out_valid);
        if (past_valid && !$past(rst) && $past(in_valid && in_ready) &&
            !$past(out_valid && out_ready) && $past(level == 0))
            assert (out_valid && out_data == $past(in_data));

        // Independent scalar ghost queue.  Its head comparison proves that
        // every legal output transfers the oldest accepted token, including
        // simultaneous push/pop and pointer wraparound.  The count equality
        // proves accepted-minus-consumed conservation for the formal epoch.
        if (!rst) begin
            assert (ghost_count == level);
            if (ghost_pop)
                assert (out_data == ghost_head_data);
            if (ghost_push) begin
                case (ghost_wr)
                    2'd0: ghost_mem0 <= in_data;
                    2'd1: ghost_mem1 <= in_data;
                    2'd2: ghost_mem2 <= in_data;
                    default: ghost_mem3 <= in_data;
                endcase
                ghost_wr <= ghost_wr + 1'b1;
            end
            if (ghost_pop)
                ghost_rd <= ghost_rd + 1'b1;
            case ({ghost_push, ghost_pop})
                2'b10: ghost_count <= ghost_count + 1'b1;
                2'b01: ghost_count <= ghost_count - 1'b1;
                default: ghost_count <= ghost_count;
            endcase
        end
        assert (level <= 1024);
        cover (level == 4);
    end
endmodule
