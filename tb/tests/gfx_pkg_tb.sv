module gfx_pkg_tb;
    import gfx_pkg::*;
    initial begin
        assert (RENDER_WIDTH == 320 && RENDER_HEIGHT == 240 && PIXEL_COUNT == 76800);
        assert (COMMAND_FIFO_DEPTH == 1024 && COORD_WIDTH == 13 && COORD_FRAC_BITS == 4);
        assert (ATTRIBUTE_CMD_WIDTH == 32 && ATTRIBUTE_FRAC_BITS == 8 && ATTRIBUTE_ACCUM_WIDTH == 42);
        assert (CMD_NOP == 4'h0 && CMD_BEGIN_FRAME == 4'h1 && CMD_DRAW_TRIANGLE == 4'h2);
        assert (CMD_SET_SOBEL == 4'h3 && CMD_PRESENT == 4'h4 && CMD_READ_FRONT == 4'h5);
        assert (CMD_GET_STATUS == 4'h6 && CMD_GET_COUNTERS == 4'h7);
        $display("gfx_pkg_tb: PASS"); $finish;
    end
endmodule
