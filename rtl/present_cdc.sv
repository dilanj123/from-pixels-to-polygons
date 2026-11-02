module present_cdc (
    input  logic               clk_sys,
    input  logic               rst_sys,
    input  logic               request_valid,
    output logic               request_ready,
    input  logic [1:0]         request_front_id,
    output logic               acknowledge,
    input  logic               clk_pix,
    input  logic               rst_pix,
    input  logic               safe_frame_start,
    output logic [1:0]         front_id_pix,
    output logic               front_valid_pix,
    output logic               request_pending_sys
);
    logic request_toggle_sys, acknowledge_toggle_pix;
    (* async_reg = "true" *) logic [1:0] request_sync_pix;
    (* async_reg = "true" *) logic [1:0] acknowledge_sync_sys;
    logic request_seen_pix, acknowledge_seen_sys;
    logic [1:0] requested_id_sys, requested_id_pix;
    logic pending_pix;
    logic request_pending_q;

    assign request_ready = !request_pending_q && !rst_sys;
    assign request_pending_sys = request_pending_q;

    always_ff @(posedge clk_sys or posedge rst_sys) begin
        if (rst_sys) begin
            acknowledge_sync_sys <= '0;
            acknowledge_seen_sys <= 1'b0;
            request_toggle_sys <= 1'b0;
            requested_id_sys <= 2'd0;
            request_pending_q <= 1'b0;
            acknowledge <= 1'b0;
        end else begin
            acknowledge_sync_sys <= {acknowledge_sync_sys[0], acknowledge_toggle_pix};
            acknowledge <= 1'b0;
            if (request_valid && request_ready) begin
                requested_id_sys <= request_front_id;
                request_toggle_sys <= ~request_toggle_sys;
                request_pending_q <= 1'b1;
            end
            if (acknowledge_sync_sys[1] != acknowledge_seen_sys) begin
                acknowledge_seen_sys <= acknowledge_sync_sys[1];
                request_pending_q <= 1'b0;
                acknowledge <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk_pix or posedge rst_pix) begin
        if (rst_pix) begin
            request_sync_pix <= '0;
            request_seen_pix <= 1'b0;
            acknowledge_toggle_pix <= 1'b0;
            requested_id_pix <= 2'd0;
            front_id_pix <= 2'd0;
            front_valid_pix <= 1'b0;
            pending_pix <= 1'b0;
        end else begin
            request_sync_pix <= {request_sync_pix[0], request_toggle_sys};
            if (!pending_pix && (request_sync_pix[1] != request_seen_pix)) begin
                request_seen_pix <= request_sync_pix[1];
                requested_id_pix <= requested_id_sys;
                pending_pix <= 1'b1;
            end
            if (pending_pix && safe_frame_start) begin
                front_id_pix <= requested_id_pix;
                front_valid_pix <= 1'b1;
                acknowledge_toggle_pix <= request_seen_pix;
                pending_pix <= 1'b0;
            end
        end
    end

`ifndef SYNTHESIS
    always @(posedge clk_sys) begin
        if (!rst_sys && request_valid && request_ready && request_front_id == 2'b11)
            $error("presentation request has invalid FRONT ID");
    end
`endif
endmodule
