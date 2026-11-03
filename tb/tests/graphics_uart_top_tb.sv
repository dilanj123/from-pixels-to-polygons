`timescale 1ns/1ps
module graphics_uart_top_tb;
    localparam integer CPB=16;
    logic clk=0, arst=1, rx=1, tx;
    always #5 clk=~clk;
    logic [7:0] red,green,blue;
    logic hsync,vsync,active_video,front_valid,command_error;
    logic [1:0] front_id,render_id,spare_id;
    logic rx_overrun,rx_framing_error;
    logic [31:0] response_word;
    logic [7:0] rx_byte;
    integer b,w;

    graphics_uart_top #(.CLKS_PER_BIT(CPB)) dut (
        .clk_sys(clk), .clk_pix(clk), .arst(arst), .uart_rx(rx), .uart_tx(tx),
        .rx_overrun(rx_overrun), .rx_framing_error(rx_framing_error),
        .red(red),.green(green),.blue(blue),.hsync(hsync),.vsync(vsync),
        .active_video(active_video),.front_id(front_id),.render_id(render_id),
        .spare_id(spare_id),.front_valid(front_valid),.command_error(command_error)
    );

    task automatic send_bit(input logic value);
        begin rx=value; repeat(CPB) @(posedge clk); end
    endtask
    task automatic send_byte(input logic [7:0] value);
        integer k;
        begin
            send_bit(0);
            for(k=0;k<8;k=k+1) send_bit(value[k]);
            send_bit(1);
        end
    endtask
    task automatic send_word(input logic [31:0] value);
        integer k;
        begin for(k=0;k<4;k=k+1) send_byte(value[k*8 +: 8]); end
    endtask
    task automatic receive_byte(output logic [7:0] value);
        integer k;
        begin
            wait(tx==0);
            repeat(CPB+CPB/2) @(posedge clk);
            for(k=0;k<8;k=k+1) begin
                value[k]=tx;
                if(k!=7) repeat(CPB) @(posedge clk);
            end
            repeat(CPB) @(posedge clk);
            if(tx!==1) $fatal(1,"UART TX stop bit low sampled=%02x time=%0t",value,$time);
            repeat(CPB/2) @(posedge clk);
        end
    endtask
    task automatic receive_word(output logic [31:0] value);
        integer k;
        begin
            value=0;
            for(k=0;k<4;k=k+1) begin
                receive_byte(rx_byte);
                value[k*8 +: 8]=rx_byte;
            end
        end
    endtask

    initial begin
        repeat(5) @(posedge clk); @(negedge clk); arst=0;
        repeat(5) @(posedge clk);
        send_word(32'h00001230); // NOP
        send_word(32'h60001234); // GET_STATUS
        receive_word(response_word);
        if(response_word!==32'ha0001234) $fatal(1,"UART STATUS header %08x",response_word);
        receive_word(response_word);
        if(response_word!==0) $fatal(1,"UART STATUS flags %08x",response_word);
        receive_word(response_word);
        if(response_word!==32'h24) $fatal(1,"UART STATUS roles %08x",response_word);
        if(rx_overrun || rx_framing_error) $fatal(1,"unexpected UART error flags");
        $display("GRAPHICS UART TOP PASS NOP+GET_STATUS bytes=12 little_endian=1");
        $finish;
    end
    initial begin #10000000; $fatal(1,"graphics UART top watchdog"); end
endmodule
