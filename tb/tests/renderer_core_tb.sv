`timescale 1ns/1ps
module renderer_core_tb;
    localparam int PIXELS = 76800;
    logic clk = 1'b0;
    logic rst = 1'b1;
    always #5 clk = ~clk;

    logic render_cmd_valid;
    logic render_cmd_ready;
    gfx_pkg::decoded_command_t render_cmd;
    logic renderer_quiescent;
    integer frame_count, fd, rc, frame, i, mismatches;
    integer v [0:20];
    integer expected_fb [0:PIXELS-1];
    integer expected_z [0:PIXELS-1];
    integer clear_fb_count, clear_z_count, hazard_count, owner_conflict_count;
    string vec_dir;
    string path;

    renderer_core dut (
        .clk_sys(clk), .rst(rst),
        .render_cmd_valid(render_cmd_valid), .render_cmd_ready(render_cmd_ready),
        .render_cmd(render_cmd), .renderer_quiescent(renderer_quiescent)
    );

    always @(posedge clk) begin
        if (!rst) begin
            if (dut.clear_owner && dut.clear_fb_we) clear_fb_count = clear_fb_count + 1;
            if (dut.clear_owner && dut.clear_z_we) clear_z_count = clear_z_count + 1;
            if (dut.clear_owner && dut.fragment_owner) owner_conflict_count = owner_conflict_count + 1;
            if (dut.fragment_owner && dut.fragment_i.z_rd_en && dut.fragment_i.z_wr_en &&
                dut.fragment_i.z_rd_addr == dut.fragment_i.z_wr_addr) hazard_count = hazard_count + 1;
        end
    end

    task automatic drive_command;
        begin
            while (!render_cmd_ready) @(posedge clk);
            @(negedge clk);
            render_cmd.opcode = v[0][3:0];
            render_cmd.tag = v[1][15:0];
            render_cmd.clear_rgb332 = v[2][7:0];
            render_cmd.v0_x = v[3][12:0]; render_cmd.v0_y = v[4][12:0];
            render_cmd.v1_x = v[5][12:0]; render_cmd.v1_y = v[6][12:0];
            render_cmd.v2_x = v[7][12:0]; render_cmd.v2_y = v[8][12:0];
            render_cmd.r_start = v[9]; render_cmd.g_start = v[10];
            render_cmd.b_start = v[11]; render_cmd.z_start = v[12];
            render_cmd.r_dx = v[13]; render_cmd.g_dx = v[14];
            render_cmd.b_dx = v[15]; render_cmd.z_dx = v[16];
            render_cmd.r_dy = v[17]; render_cmd.g_dy = v[18];
            render_cmd.b_dy = v[19]; render_cmd.z_dy = v[20];
            render_cmd_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            render_cmd_valid = 1'b0;
        end
    endtask

    task automatic wait_quiescent;
        integer guard;
        begin
            guard = 0;
            while (!renderer_quiescent) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 2000000) begin
                    $display("timeout state=%0d clear_busy=%b setup_v=%b walk_busy=%b walk_done=%b frag_empty=%b covered_v=%b", dut.state_q, dut.clear_busy, dut.setup_out_valid, dut.walk_busy, dut.walk_complete, dut.fragment_empty, dut.covered_valid);
                    $fatal(1, "quiescent timeout");
                end
            end
            @(posedge clk);
        end
    endtask

    task automatic compare_frame(input integer index);
        begin
            path = $sformatf("%s/frame_%0d_fb.hex", vec_dir, index);
            $readmemh(path, expected_fb);
            path = $sformatf("%s/frame_%0d_z.hex", vec_dir, index);
            $readmemh(path, expected_z);
            mismatches = 0;
            for (i = 0; i < PIXELS; i = i + 1) begin
                if (dut.framebuffer_i.mem[i] !== expected_fb[i][7:0]) begin
                    if (mismatches == 0) $display("FB mismatch frame=%0d addr=%0d exp=%02x act=%02x", index, i, expected_fb[i], dut.framebuffer_i.mem[i]);
                    mismatches = mismatches + 1;
                end
                if (dut.zbuffer_i.mem[i] !== expected_z[i][7:0]) begin
                    if (mismatches == 0) $display("Z mismatch frame=%0d addr=%0d exp=%02x act=%02x", index, i, expected_z[i], dut.zbuffer_i.mem[i]);
                    mismatches = mismatches + 1;
                end
            end
            if (mismatches != 0) $fatal(1, "frame %0d mismatches=%0d", index, mismatches);
        end
    endtask

    initial begin
        render_cmd_valid = 1'b0;
        render_cmd = '0;
        clear_fb_count = 0;
        clear_z_count = 0;
        hazard_count = 0;
        owner_conflict_count = 0;
        if (!$value$plusargs("VEC_DIR=%s", vec_dir)) vec_dir = "/tmp/gfx012_vectors";
        fd = 0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        fd = $fopen({vec_dir, "/frame_count.txt"}, "r");
        rc = $fscanf(fd, "%d", frame_count);
        $fclose(fd);
        for (frame = 0; frame < frame_count; frame = frame + 1) begin
            if (frame != 0) begin
                rst = 1'b1;
                repeat (2) @(posedge clk);
                rst = 1'b0;
            end
            fd = $fopen($sformatf("%s/frame_%0d.cmd", vec_dir, frame), "r");
            while (!$feof(fd)) begin
                rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
                    v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],v[9],v[10],v[11],v[12],v[13],v[14],v[15],v[16],v[17],v[18],v[19],v[20]);
                if (rc == 21) drive_command();
            end
            $fclose(fd);
            wait_quiescent();
            if (clear_fb_count != 76800 || clear_z_count != 76800)
                $fatal(1, "frame %0d clear counts fb=%0d z=%0d", frame, clear_fb_count, clear_z_count);
            compare_frame(frame);
            $display("FRAME %0d PASS clear_fb=%0d clear_z=%0d", frame, clear_fb_count, clear_z_count);
            clear_fb_count = 0;
            clear_z_count = 0;
        end
        $display("RENDERER CORE PASS frames=%0d", frame_count);
        if (hazard_count != 0 || owner_conflict_count != 0)
            $fatal(1, "ownership/hazard conflicts hazard=%0d owner=%0d", hazard_count, owner_conflict_count);
        $finish;
    end
endmodule
