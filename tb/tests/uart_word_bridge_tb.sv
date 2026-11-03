`timescale 1ns/1ps
module uart_word_bridge_tb;
    localparam integer CPB = 16;
    logic clk = 0, arst = 1, rx = 1;
    always #5 clk = ~clk;
    logic tx, cmd_valid, cmd_ready = 0;
    logic [31:0] cmd_data;
    logic rsp_valid = 0, rsp_ready;
    logic [31:0] rsp_data = 0;
    logic rx_overrun, rx_framing_error;
    integer checked = 0;

    uart_word_bridge #(.CLKS_PER_BIT(CPB)) dut (
        .clk_sys(clk), .arst(arst), .uart_rx(rx), .uart_tx(tx),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_data(cmd_data),
        .rsp_valid(rsp_valid), .rsp_ready(rsp_ready), .rsp_data(rsp_data),
        .rx_overrun(rx_overrun), .rx_framing_error(rx_framing_error));

    task automatic uart_bit(input logic value);
        begin rx=value; repeat(CPB) @(posedge clk); end
    endtask

    task automatic send_byte(input logic [7:0] value, input logic good_stop);
        integer b;
        begin
            uart_bit(0);
            for (b=0;b<8;b=b+1) uart_bit(value[b]);
            uart_bit(good_stop);
            rx=1; repeat(CPB) @(posedge clk);
        end
    endtask

    task automatic send_word(input logic [31:0] value);
        integer b;
        begin for (b=0;b<4;b=b+1) send_byte(value[b*8 +: 8],1); end
    endtask

    task automatic receive_byte(output logic [7:0] value);
        integer b;
        begin
            wait(tx==0);
            repeat(CPB + CPB/2) @(posedge clk);
            for (b=0;b<8;b=b+1) begin
                value[b]=tx;
                if (b != 7) repeat(CPB) @(posedge clk);
            end
            repeat(CPB/2) @(posedge clk);
            if (tx !== 1) $fatal(1,"UART stop bit low");
            repeat(CPB/2) @(posedge clk);
        end
    endtask

    logic [7:0] byte_value;
    logic [31:0] rx_word;
    integer i;
    initial begin
        repeat(4) @(posedge clk); @(negedge clk); arst=0;
        send_word(32'h12345678);
        wait(cmd_valid);
        if(cmd_data !== 32'h12345678) $fatal(1,"RX word/byte order %08x",cmd_data);
        checked=checked+1;
        @(negedge clk); cmd_ready=1;
        @(posedge clk); @(negedge clk); cmd_ready=0;

        @(negedge clk); rsp_data=32'h89abcdef; rsp_valid=1;
        do @(posedge clk); while(!rsp_ready);
        @(negedge clk); rsp_valid=0;
        rx_word=0;
        for(i=0;i<4;i=i+1) begin
            receive_byte(byte_value);
            rx_word[i*8 +: 8]=byte_value;
        end
        if(rx_word !== 32'h89abcdef) $fatal(1,"TX word/byte order %08x",rx_word);
        checked=checked+1;

        // Invalid stop bit is sticky and prevents command delivery until reset.
        send_byte(8'h55,0);
        repeat(4) @(posedge clk);
        if(!rx_framing_error || cmd_valid) $fatal(1,"framing error not blocked");
        checked=checked+1;

        @(negedge clk); arst=1; rx=1;
        repeat(4) @(posedge clk);
        @(negedge clk); arst=0;
        repeat(4) @(posedge clk);
        send_word(32'h01020304);
        send_word(32'h05060708);
        repeat(4) @(posedge clk);
        if(!rx_overrun || cmd_valid) $fatal(1,"RX overrun not reported/blocked");
        checked=checked+1;
        $display("UART WORD BRIDGE PASS checks=%0d framing_block=1 overrun_block=1",checked);
        $finish;
    end
    initial begin #1000000; $fatal(1,"UART test watchdog"); end
endmodule
