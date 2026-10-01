`timescale 1ns/1ps

module scanout_2x_tb;
    localparam int unsigned PIXELS = 76800;
    localparam int unsigned LINE_CLOCKS = 800;
    localparam int unsigned FRAME_LINES = 525;
    localparam int unsigned FRAME_CLOCKS = LINE_CLOCKS * FRAME_LINES;

    logic clk_pix = 1'b0;
    logic rst_pix = 1'b1;
    logic front_valid = 1'b0;
    logic fb_pix_valid;
    logic [16:0] fb_pix_addr;
    logic [7:0] fb_pix_rdata;
    logic [7:0] red, green, blue;
    logic hsync, vsync, active_video, frame_start, line_start;
    logic signed [15:0] raster_x, raster_y, pixel_x, pixel_y;
    int unsigned active_count;
    int unsigned line_count;
    int unsigned y;
    int unsigned x;
    int unsigned slot;
    int unsigned source_address;
    bit [255:0] seen_rgb332;
    logic [7:0] expected_byte;
    logic [7:0] expected_red, expected_green, expected_blue;

    always #19.841269 clk_pix = ~clk_pix;

    framebuffer_dp framebuffer_i (
        .clk_pix(clk_pix), .pix_addr(fb_pix_addr), .pix_rdata(fb_pix_rdata),
        .clk_sys(clk_pix), .sys_addr(17'd0), .sys_we(1'b0),
        .sys_wdata(8'd0), .sys_rdata()
    );

    scanout_2x dut (
        .clk_pix(clk_pix), .rst_pix(rst_pix), .front_valid(front_valid),
        .fb_pix_valid(fb_pix_valid), .fb_pix_addr(fb_pix_addr),
        .fb_pix_rdata(fb_pix_rdata),
        .red(red), .green(green), .blue(blue),
        .hsync(hsync), .vsync(vsync), .active_video(active_video),
        .frame_start(frame_start), .line_start(line_start),
        .raster_x(raster_x), .raster_y(raster_y),
        .pixel_x(pixel_x), .pixel_y(pixel_y)
    );

    function automatic [7:0] pattern(input int unsigned addr);
        int unsigned sx;
        int unsigned sy;
        begin
            sx = addr % 320;
            sy = addr / 320;
            pattern = (addr * 73 + sx * 19 + sy * 47 + (sx ^ sy)) & 8'hff;
        end
    endfunction

    function automatic [7:0] expand_red(input logic [7:0] value);
        expand_red = {value[7:5], value[7:5], value[7:6]};
    endfunction

    function automatic [7:0] expand_green(input logic [7:0] value);
        expand_green = {value[4:2], value[4:2], value[4:3]};
    endfunction

    function automatic [7:0] expand_blue(input logic [7:0] value);
        expand_blue = {value[1:0], value[1:0], value[1:0], value[1:0]};
    endfunction

    task automatic check_aligned_video;
        logic expected_active;
        logic expected_hsync;
        logic expected_vsync;
        begin
            expected_active = (pixel_x >= 0 && pixel_x <= 639 &&
                               pixel_y >= 0 && pixel_y <= 479);
            expected_hsync = !(pixel_x >= -144 && pixel_x <= -49);
            expected_vsync = !(pixel_y >= -35 && pixel_y <= -34);
            if (active_video !== expected_active)
                $fatal(1, "DE alignment mismatch at pixel coordinate (%0d,%0d)", pixel_x, pixel_y);
            if (hsync !== expected_hsync)
                $fatal(1, "HSYNC alignment/polarity mismatch at (%0d,%0d): %b", pixel_x, pixel_y, hsync);
            if (vsync !== expected_vsync)
                $fatal(1, "VSYNC alignment/polarity mismatch at (%0d,%0d): %b", pixel_x, pixel_y, vsync);
        end
    endtask

    initial begin
        active_count = 0;
        line_count = 0;
        seen_rgb332 = '0;
        for (int unsigned i = 0; i < PIXELS; i++)
            framebuffer_i.mem[i] = pattern(i);

        repeat (3) @(posedge clk_pix);
        @(negedge clk_pix);
        rst_pix = 1'b0;

        // The first registered frame marker is D-036's (-160,-45) boundary.
        do begin
            @(posedge clk_pix);
            #1;
        end while (!frame_start);

        // Verify every timing slot in one complete raster and the delayed
        // DE/sync tuple throughout it. The end boundary contributes the final
        // registered pixel from the frame just completed.
        for (slot = 0; slot < FRAME_CLOCKS; slot++) begin
            #0;
            x = slot % LINE_CLOCKS;
            y = slot / LINE_CLOCKS;
            if (raster_x !== ($signed(x) - 160) || raster_y !== ($signed(y) - 45))
                $fatal(1, "raster slot %0d expected (%0d,%0d), got (%0d,%0d)",
                       slot, $signed(x)-160, $signed(y)-45, raster_x, raster_y);
            if (frame_start !== (slot == 0))
                $fatal(1, "frame_start mismatch at raster slot %0d", slot);
            if (line_start !== (x == 0))
                $fatal(1, "line_start mismatch at raster slot %0d", slot);
            if (fb_pix_valid !== (raster_x >= 0 && raster_y >= 0))
                $fatal(1, "framebuffer read-valid mismatch at raster (%0d,%0d)", raster_x, raster_y);
            if (fb_pix_valid) begin
                source_address = (raster_y >> 1) * 320 + (raster_x >> 1);
                if (fb_pix_addr !== source_address[16:0])
                    $fatal(1, "source address mismatch at (%0d,%0d): got %0d expected %0d",
                           raster_x, raster_y, fb_pix_addr, source_address);
                if (fb_pix_addr >= PIXELS)
                    $fatal(1, "out-of-range source address %0d", fb_pix_addr);
            end else if (fb_pix_addr !== 17'd0) begin
                $fatal(1, "blanking address is not canonical zero");
            end

            check_aligned_video();
            if ({red, green, blue} !== 24'd0)
                $fatal(1, "front_valid=0 did not force black at (%0d,%0d)", pixel_x, pixel_y);
            if (active_video)
                active_count++;
            if (line_start)
                line_count++;

            if (slot != FRAME_CLOCKS-1) begin
                @(posedge clk_pix);
                #1;
            end
        end

        @(posedge clk_pix);
        #1;
        if (!frame_start || raster_x != -160 || raster_y != -45)
            $fatal(1, "frame period did not end at the D-036 safe boundary");
        check_aligned_video();
        if (!active_video || pixel_x != 639 || pixel_y != 479)
            $fatal(1, "last active output pixel is not aligned to frame wrap");
        active_count++;

        if (active_count != 307200)
            $fatal(1, "expected 307200 active output pixels in frame, got %0d", active_count);
        if (line_count != FRAME_LINES)
            $fatal(1, "expected 525 line starts, got %0d", line_count);

        // Turn on the valid front while the timing is still in blanking, then
        // compare one whole active image against an independent address model.
        front_valid = 1'b1;

        active_count = 0;
        seen_rgb332 = '0;
        do begin
            @(posedge clk_pix);
            #1;
            check_aligned_video();
        end while (!(active_video && pixel_x == 0 && pixel_y == 0));

        for (active_count = 0; active_count < 307200; active_count++) begin
            if (pixel_x != (active_count % 640) || pixel_y != (active_count / 640))
                $fatal(1, "active pixel order mismatch index=%0d got=(%0d,%0d) active=%b timing=(%0d,%0d,%b) raw=(%0d,%0d)",
                       active_count, pixel_x, pixel_y, active_video,
                       dut.timing_x, dut.timing_y, dut.timing_de, raster_x, raster_y);
            source_address = (pixel_y >> 1) * 320 + (pixel_x >> 1);
            expected_byte = pattern(source_address);
            expected_red = expand_red(expected_byte);
            expected_green = expand_green(expected_byte);
            expected_blue = expand_blue(expected_byte);
            if ({red, green, blue} !== {expected_red, expected_green, expected_blue})
                $fatal(1, "pixel mismatch display=(%0d,%0d) source=%0d byte=%02x rgb=%02x%02x%02x expected=%02x%02x%02x",
                       pixel_x, pixel_y, source_address, expected_byte,
                       red, green, blue, expected_red, expected_green, expected_blue);
            seen_rgb332[expected_byte] = 1'b1;
            if (active_count != 307199) begin
                do begin
                    @(posedge clk_pix);
                    #1;
                    check_aligned_video();
                    if (!active_video && {red, green, blue} !== 24'd0)
                        $fatal(1, "blanking output is not black");
                end while (!active_video);
            end
        end

        if (active_count != 307200)
            $fatal(1, "active output count mismatch: %0d", active_count);
        for (int unsigned code = 0; code < 256; code++) begin
            if (!seen_rgb332[code])
                $fatal(1, "deterministic source pattern did not exercise RGB332 value %02x", code);
        end

        // Explicitly guard the four 2x corners and representative RGB codes.
        if ({expand_red(8'h00), expand_green(8'h00), expand_blue(8'h00)} !== 24'h000000 ||
            {expand_red(8'hff), expand_green(8'hff), expand_blue(8'hff)} !== 24'hffffff)
            $fatal(1, "RGB332 expansion endpoint mismatch");
        if (pattern(PIXELS-1) !== framebuffer_i.mem[PIXELS-1])
            $fatal(1, "bottom-right source corner mismatch");

        $display("PASS scanout_2x_tb: 1 full 800x525 raster, 525 line starts, 307200 active pixels, 76800 source addresses, all 256 RGB332 codes; front-invalid black and synchronous latency aligned");
        $finish;
    end
endmodule
