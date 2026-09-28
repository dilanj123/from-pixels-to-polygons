`timescale 1ns/1ps
module memory_wrappers_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic [16:0] pix_addr, sys_addr;
    logic [7:0] pix_rdata, sys_rdata, sys_wdata;
    logic sys_we;
    logic [16:0] z_rd_addr, z_wr_addr;
    logic [7:0] z_rd_data, z_wr_data;
    logic z_wr_en;

    framebuffer_dp fb (.clk_pix(clk), .pix_addr(pix_addr), .pix_rdata(pix_rdata),
                       .clk_sys(clk), .sys_addr(sys_addr), .sys_we(sys_we),
                       .sys_wdata(sys_wdata), .sys_rdata(sys_rdata));
    zbuffer zb (.clk_sys(clk), .rd_addr(z_rd_addr), .rd_data(z_rd_data),
                .wr_en(z_wr_en), .wr_addr(z_wr_addr), .wr_data(z_wr_data));

    initial begin
        pix_addr = 0; sys_addr = 17'd123; sys_we = 0; sys_wdata = 0;
        z_rd_addr = 17'd77; z_wr_addr = 17'd77; z_wr_data = 8'h5A; z_wr_en = 0;
        repeat (2) @(posedge clk);
        @(negedge clk); sys_wdata = 8'hA5; sys_we = 1;
        @(posedge clk); @(negedge clk); sys_we = 0;
        @(posedge clk); #1;
        if (sys_rdata !== 8'hA5) $fatal(1, "framebuffer sys read mismatch");
        pix_addr = 17'd123;
        @(posedge clk); #1;
        if (pix_rdata !== 8'hA5) $fatal(1, "framebuffer pixel read mismatch");
        @(negedge clk); z_wr_en = 1; z_wr_data = 8'h5A;
        @(posedge clk); @(negedge clk); z_wr_en = 0;
        @(posedge clk); #1;
        if (z_rd_data !== 8'h5A) $fatal(1, "zbuffer read mismatch");
        $display("MEMORY WRAPPERS PASS");
        $finish;
    end
endmodule
