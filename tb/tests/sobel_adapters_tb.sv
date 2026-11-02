module sobel_adapters_tb;
    localparam integer N = 76800;
    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    logic reader_start, reader_start_ready, reader_busy, reader_done;
    logic fb_rd_en;
    logic [16:0] fb_rd_addr;
    logic [7:0] fb_rd_data;
    logic [23:0] reader_data;
    logic reader_valid, reader_ready, reader_sof, reader_eol;

    logic mock_valid;
    logic mock_ready;
    logic [7:0] mock_data;
    logic mock_sof, mock_eol;
    logic writer_start, writer_start_ready, writer_busy, writer_done, writer_error;
    logic writer_ready, fb_wr_en;
    logic [16:0] fb_wr_addr;
    logic [7:0] fb_wr_data;

    logic apb_start, apb_start_ready, apb_enable, apb_bypass;
    logic [7:0] apb_threshold;
    logic apb_busy, apb_done, apb_error, psel, penable, pwrite;
    logic [7:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata = 0;
    logic pready = 1;
    logic pslverr = 0;

    logic [7:0] source_mem [0:N-1];
    logic [7:0] dest_mem [0:N-1];
    integer read_count = 0;
    integer write_count = 0;
    integer stream_count = 0;
    integer mock_count = 0;
    integer cycle_count = 0;
    integer stall_count = 0;
    integer apb_write_count = 0;
    integer full_frame_writes = 0;
    logic monitor_frame = 1'b1;
    integer i;
    integer expected_edge;
    integer expected_rgb;
    logic stalled_q = 0;
    logic [23:0] stalled_data_q;
    logic stalled_sof_q, stalled_eol_q;
    logic mock_enable;

    sobel_fb_reader reader (
        .clk_sys(clk), .rst(rst), .start_valid(reader_start),
        .start_ready(reader_start_ready), .busy(reader_busy), .done(reader_done),
        .fb_rd_en(fb_rd_en), .fb_rd_addr(fb_rd_addr), .fb_rd_data(fb_rd_data),
        .m_tdata(reader_data), .m_tvalid(reader_valid), .m_tready(reader_ready),
        .m_tuser(reader_sof), .m_tlast(reader_eol)
    );

    sobel_fb_writer writer (
        .clk_sys(clk), .rst(rst), .start_valid(writer_start),
        .start_ready(writer_start_ready), .busy(writer_busy), .done(writer_done),
        .error(writer_error), .s_tdata(mock_data), .s_tvalid(mock_valid),
        .s_tready(writer_ready), .s_tuser(mock_sof), .s_tlast(mock_eol),
        .fb_wr_en(fb_wr_en), .fb_wr_addr(fb_wr_addr), .fb_wr_data(fb_wr_data)
    );

    sobel_apb_master apb (
        .clk_sys(clk), .rst(rst), .start_valid(apb_start),
        .start_ready(apb_start_ready), .cfg_enable(apb_enable),
        .cfg_threshold(apb_threshold), .cfg_bypass(apb_bypass),
        .busy(apb_busy), .config_done(apb_done), .config_error(apb_error),
        .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr),
        .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(pslverr)
    );

    function automatic [7:0] source_pixel(input integer addr);
        source_pixel = (addr * 37 + (addr >> 8) * 19 + 8'h53) & 8'hff;
    endfunction

    function automatic [23:0] rgb_expand(input logic [7:0] pixel);
        rgb_expand = {{pixel[7:5], pixel[7:5], pixel[7:6]},
                      {pixel[4:2], pixel[4:2], pixel[4:3]},
                      {pixel[1:0], pixel[1:0], pixel[1:0], pixel[1:0]}};
    endfunction

    function automatic [7:0] edge_model(input logic [23:0] rgb);
        edge_model = rgb[23:16] ^ rgb[15:8] ^ rgb[7:0];
    endfunction

    function automatic [7:0] edge_to_rgb332(input logic [7:0] edge_value);
        edge_to_rgb332 = {edge_value[7:5], edge_value[7:5], edge_value[7:6]};
    endfunction

    always_ff @(posedge clk) begin
        if (fb_rd_en)
            fb_rd_data <= source_mem[fb_rd_addr];
        if (fb_wr_en)
            dest_mem[fb_wr_addr] <= fb_wr_data;
    end

    always @(negedge clk) begin
        if (rst)
            reader_ready <= 1'b0;
        else
            reader_ready <= !mock_valid && ((cycle_count % 11) != 2) && ((cycle_count % 11) != 3);
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            mock_valid <= 1'b0;
            mock_data <= 0;
            mock_sof <= 0;
            mock_eol <= 0;
            cycle_count <= 0;
        end else if (mock_enable) begin
            cycle_count <= cycle_count + 1;
            if (mock_valid && writer_ready) begin
                mock_valid <= 1'b0;
            end else if (reader_valid && reader_ready) begin
                mock_valid <= 1'b1;
                mock_data <= edge_model(reader_data);
                mock_sof <= reader_sof;
                mock_eol <= reader_eol;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            stalled_q <= 1'b0;
        end else begin
            stalled_q <= reader_valid && !reader_ready;
            if (reader_valid && !reader_ready) begin
                stalled_data_q <= reader_data;
                stalled_sof_q <= reader_sof;
                stalled_eol_q <= reader_eol;
                stall_count <= stall_count + 1;
            end
            if (fb_rd_en) begin
                if (fb_rd_addr !== read_count[16:0])
                    $fatal(1, "read address mismatch expected=%0d got=%0d", read_count, fb_rd_addr);
                read_count <= read_count + 1;
            end
            if (reader_valid && reader_ready) begin
                expected_rgb = rgb_expand(source_mem[stream_count]);
                if (reader_data !== expected_rgb[23:0])
                    $fatal(1, "reader pixel mismatch at %0d src=%02x got=%06x expected=%06x", stream_count, source_mem[stream_count], reader_data, expected_rgb[23:0]);
                if (reader_sof !== (stream_count == 0))
                    $fatal(1, "reader SOF mismatch at %0d", stream_count);
                if (reader_eol !== ((stream_count % 320) == 319))
                    $fatal(1, "reader EOL mismatch at %0d", stream_count);
                stream_count <= stream_count + 1;
            end
            if (reader_valid && reader_ready)
                mock_count <= mock_count + 1;
            if (fb_wr_en) begin
                if (monitor_frame) begin
                    if (fb_wr_addr !== write_count[16:0])
                        $fatal(1, "write address mismatch expected=%0d got=%0d", write_count, fb_wr_addr);
                    expected_edge = edge_model(rgb_expand(source_mem[write_count]));
                    if (fb_wr_data !== edge_to_rgb332(expected_edge[7:0]))
                        $fatal(1, "writer data mismatch at %0d", write_count);
                    if (mock_sof !== (write_count == 0) || mock_eol !== ((write_count % 320) == 319))
                        $fatal(1, "mock metadata mismatch at %0d", write_count);
                    write_count <= write_count + 1;
                end
            end
            if (psel && penable && pwrite && pready) begin
                apb_write_count <= apb_write_count + 1;
                if (apb_write_count == 0 && (paddr != 0 || pwdata != 3))
                    $fatal(1, "CONTROL APB write mismatch");
                if (apb_write_count == 1 && (paddr != 4 || pwdata != 8'h5a))
                    $fatal(1, "THRESHOLD APB write mismatch");
                if (apb_write_count == 2 && (paddr != 0 || pwdata != 1))
                    $fatal(1, "CONTROL bypass-clear APB write mismatch");
                if (apb_write_count == 3 && (paddr != 4 || pwdata != 8'hc3))
                    $fatal(1, "second THRESHOLD APB write mismatch");
                if (apb_write_count == 4 && (paddr != 0 || pwdata != 1))
                    $fatal(1, "error-injected CONTROL APB write mismatch");
            end
        end
    end

    always @(negedge clk) begin
        if (!rst && stalled_q && (!reader_valid || reader_data !== stalled_data_q ||
                                  reader_sof !== stalled_sof_q || reader_eol !== stalled_eol_q))
            $fatal(1, "reader changed payload during stall old=%06x/%b/%b new=%06x/%b/%b ready=%b count=%0d", stalled_data_q, stalled_sof_q, stalled_eol_q, reader_data, reader_sof, reader_eol, reader_ready, reader.fifo_count_q);
    end

    task automatic tick;
        begin @(posedge clk); #1; end
    endtask

    initial begin
        reader_start = 0;
        writer_start = 0;
        apb_start = 0;
        apb_enable = 1;
        apb_bypass = 1;
        apb_threshold = 8'h5a;
        mock_valid = 0;
        mock_data = 0;
        mock_sof = 0;
        mock_eol = 0;
        mock_enable = 1;
        reader_ready = 0;
        fb_rd_data = 0;
        stall_count = 0;
        for (i = 0; i < N; i = i + 1) begin
            source_mem[i] = source_pixel(i);
            dest_mem[i] = 0;
        end

        repeat (3) tick();
        rst = 0;
        tick();

        pready = 0;
        apb_start = 1;
        tick();
        apb_start = 0;
        wait (psel && penable);
        repeat (3) tick();
        if (!apb_busy || paddr != 0 || pwdata != 3 || !psel || !penable)
            $fatal(1, "APB access did not hold while PREADY was low");
        pready = 1;
        wait (apb_done);
        tick();
        if (apb_error || apb_write_count != 2)
            $fatal(1, "APB configuration failed");

        apb_bypass = 0;
        apb_threshold = 8'hc3;
        apb_start = 1;
        tick();
        apb_start = 0;
        wait (apb_done);
        #1;
        if (apb_error || apb_write_count != 4)
            $fatal(1, "APB bypass-clear configuration failed");

        pslverr = 1;
        apb_start = 1;
        tick();
        apb_start = 0;
        wait (apb_error);
        #1;
        if (apb_done || apb_busy)
            $fatal(1, "APB error result mismatch done=%b busy=%b error=%b", apb_done, apb_busy, apb_error);
        pslverr = 0;

        // Abort a short read to check that pending synchronous data is discarded.
        reader_start = 1;
        tick();
        reader_start = 0;
        repeat (8) tick();
        rst = 1;
        repeat (2) tick();
        if (reader_busy || reader_done || reader_valid)
            $fatal(1, "reader reset did not abort cleanly");
        if (apb_busy || apb_done || apb_error)
            $fatal(1, "APB reset did not clear control state");
        rst = 0;
        read_count = 0;
        stream_count = 0;
        write_count = 0;
        mock_count = 0;
        stall_count = 0;

        writer_start = 1;
        reader_start = 1;
        tick();
        writer_start = 0;
        reader_start = 0;
        wait (reader_done);
        wait (writer_done);
        tick();

        if (read_count != N || stream_count != N || mock_count != N || write_count != N)
            $fatal(1, "count mismatch reads=%0d stream=%0d mock=%0d writes=%0d",
                   read_count, stream_count, mock_count, write_count);
        if (stall_count < 1000)
            $fatal(1, "reader backpressure not exercised");
        for (i = 0; i < N; i = i + 1) begin
            expected_rgb = rgb_expand(source_mem[i]);
            expected_edge = edge_model(expected_rgb[23:0]);
            if (dest_mem[i] !== edge_to_rgb332(expected_edge[7:0]))
                $fatal(1, "full-frame mock mismatch at %0d", i);
        end
        full_frame_writes = write_count;
        monitor_frame = 0;
        mock_enable = 0;
        rst = 1;
        repeat (2) tick();
        rst = 0;
        write_count = 0;
        writer_start = 1;
        tick();
        writer_start = 0;
        mock_data = 8'hA5;
        mock_sof = 1;
        mock_eol = 0;
        mock_valid = 1;
        tick();
        mock_valid = 0;
        if (dest_mem[0] !== edge_to_rgb332(8'hA5) || !writer_busy)
            $fatal(1, "writer setup for active-reset test failed");
        rst = 1;
        repeat (2) tick();
        if (writer_busy || writer_error || fb_wr_en)
            $fatal(1, "writer reset did not clear active operation");
        rst = 0;
        write_count = 0;
        writer_start = 1;
        tick();
        writer_start = 0;
        mock_data = 8'hA5;
        mock_sof = 0;
        mock_eol = 0;
        mock_valid = 1;
        tick();
        mock_valid = 0;
        if (!writer_error || writer_busy || fb_wr_en || write_count != 0)
            $fatal(1, "malformed writer metadata was not rejected before write");
        $display("SOBEL_ADAPTERS_PASS reads=%0d reader_transfers=%0d writer_frame_writes=%0d stalls=%0d apb_writes=%0d malformed_rejected=1 active_reset=1", read_count, stream_count, full_frame_writes, stall_count, apb_write_count);
        $finish;
    end
endmodule
