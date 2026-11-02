module sobel_apb_master (
    input  logic        clk_sys,
    input  logic        rst,
    input  logic        start_valid,
    output logic        start_ready,
    input  logic        cfg_enable,
    input  logic [7:0]  cfg_threshold,
    input  logic        cfg_bypass,
    output logic        busy,
    output logic        config_done,
    output logic        config_error,
    output logic        psel,
    output logic        penable,
    output logic        pwrite,
    output logic [7:0]  paddr,
    output logic [31:0] pwdata,
    input  logic [31:0] prdata,
    input  logic        pready,
    input  logic        pslverr
);
    localparam logic [7:0] ADDR_CONTROL = 8'h00;
    localparam logic [7:0] ADDR_THRESHOLD = 8'h04;

    typedef enum logic [2:0] {
        S_IDLE,
        S_CONTROL_SETUP,
        S_CONTROL_ACCESS,
        S_THRESHOLD_SETUP,
        S_THRESHOLD_ACCESS
    } state_t;

    state_t state_q;
    logic cfg_enable_q, cfg_bypass_q;
    logic [7:0] cfg_threshold_q;

    assign start_ready = (state_q == S_IDLE) && !rst;
    assign busy = (state_q != S_IDLE) && !rst;

    always_comb begin
        psel = 1'b0;
        penable = 1'b0;
        pwrite = 1'b1;
        paddr = ADDR_CONTROL;
        pwdata = {30'd0, cfg_bypass_q, cfg_enable_q};

        case (state_q)
            S_CONTROL_SETUP: begin
                psel = 1'b1;
                paddr = ADDR_CONTROL;
            end
            S_CONTROL_ACCESS: begin
                psel = 1'b1;
                penable = 1'b1;
                paddr = ADDR_CONTROL;
            end
            S_THRESHOLD_SETUP: begin
                psel = 1'b1;
                paddr = ADDR_THRESHOLD;
                pwdata = {24'd0, cfg_threshold_q};
            end
            S_THRESHOLD_ACCESS: begin
                psel = 1'b1;
                penable = 1'b1;
                paddr = ADDR_THRESHOLD;
                pwdata = {24'd0, cfg_threshold_q};
            end
            default: begin
                psel = 1'b0;
                penable = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk_sys or posedge rst) begin
        if (rst) begin
            state_q <= S_IDLE;
            cfg_enable_q <= 1'b0;
            cfg_bypass_q <= 1'b0;
            cfg_threshold_q <= 8'd0;
            config_done <= 1'b0;
            config_error <= 1'b0;
        end else begin
            config_done <= 1'b0;
            case (state_q)
                S_IDLE: begin
                    if (start_valid && start_ready) begin
                        cfg_enable_q <= cfg_enable;
                        cfg_bypass_q <= cfg_bypass;
                        cfg_threshold_q <= cfg_threshold;
                        config_error <= 1'b0;
                        state_q <= S_CONTROL_SETUP;
                    end
                end
                S_CONTROL_SETUP: state_q <= S_CONTROL_ACCESS;
                S_CONTROL_ACCESS: begin
                    if (pready) begin
                        if (pslverr) begin
                            config_error <= 1'b1;
                            state_q <= S_IDLE;
                        end else begin
                            state_q <= S_THRESHOLD_SETUP;
                        end
                    end
                end
                S_THRESHOLD_SETUP: state_q <= S_THRESHOLD_ACCESS;
                S_THRESHOLD_ACCESS: begin
                    if (pready) begin
                        if (pslverr) begin
                            config_error <= 1'b1;
                        end else begin
                            config_done <= 1'b1;
                        end
                        state_q <= S_IDLE;
                    end
                end
                default: state_q <= S_IDLE;
            endcase
        end
    end

    wire _unused_prdata = ^prdata;
endmodule
