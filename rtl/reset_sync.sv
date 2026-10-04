// Common asynchronous assertion with independent two-flop reset release.
module reset_sync (
    input  logic clk,
    input  logic arst,
    output logic srst
);
    logic [1:0] release_q;
    always_ff @(posedge clk or posedge arst) begin
        if (arst)
            release_q <= 2'b00;
        else
            release_q <= {release_q[0], 1'b1};
    end
    assign srst = ~release_q[1];
endmodule
