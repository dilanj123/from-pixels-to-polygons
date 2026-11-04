#!/usr/bin/env bash
set -euo pipefail

stage="${1:-all}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment
yosys_datdir="$(yosys-config --datdir)"

build_dir="build/ecp5"
report_dir="reports/gfx026"
mkdir -p "$build_dir" "$report_dir"

sources=(
  rtl/gfx_pkg.sv
  third_party/projectf/lib/display/display_480p.sv
  third_party/projectf/lib/clock/ecp5/clock2_gen.v
  third_party/projectf/lib/display/tmds_encoder_dvi.sv
  third_party/projectf/lib/display/ecp5/dvi_generator.sv
  rtl/clear_engine.sv
  rtl/triangle_setup.sv
  rtl/raster_walk.sv
  rtl/fragment_z.sv
  rtl/perf_counters.sv
  rtl/zbuffer.sv
  rtl/framebuffer_dp.sv
  rtl/scanout_2x.sv
  rtl/renderer_core.sv
  rtl/readback_engine.sv
  rtl/present_cdc.sv
  rtl/buffer_manager.sv
  rtl/sobel_fb_reader.sv
  rtl/sobel_fb_writer.sv
  rtl/sobel_apb_master.sv
  rtl/sobel_controller.sv
  ip/rtl-to-pixels/rtl/pixel_pkg.sv
  ip/rtl-to-pixels/rtl/rgb_to_gray.sv
  ip/rtl-to-pixels/rtl/elastic_stage.sv
  ip/rtl-to-pixels/rtl/apb_regs.sv
  ip/rtl-to-pixels/rtl/pixel_control.sv
  ip/rtl-to-pixels/rtl/line_buffer.sv
  ip/rtl-to-pixels/rtl/window_3x3.sv
  ip/rtl-to-pixels/rtl/sobel_compact.sv
  ip/rtl-to-pixels/rtl/magnitude_clamp.sv
  ip/rtl-to-pixels/rtl/threshold_stage.sv
  ip/rtl-to-pixels/rtl/output_control.sv
  ip/rtl-to-pixels/rtl/rtl_to_pixels_top_pipelined.sv
  rtl/graphics_core.sv
  rtl/cmd_fifo.sv
  rtl/cmd_decoder.sv
  rtl/graphics_command_top.sv
  rtl/uart_word_bridge.sv
  rtl/graphics_uart_top.sv
  rtl/board/ulx3s_graphics_top.sv
)

case "$stage" in
  synth|all)
    source_args="${sources[*]}"
    yosys -ql "$report_dir/yosys_synth.txt" -p \
      "read_verilog -lib ${yosys_datdir}/ecp5/cells_bb.v; read_verilog -sv ${source_args}; hierarchy -check -top ulx3s_graphics_top; synth_ecp5 -top ulx3s_graphics_top -json ${build_dir}/ulx3s_graphics.json; check -assert" \
      || { tail -100 "$report_dir/yosys_synth.txt"; exit 1; }
    ;;
esac

case "$stage" in
  route|all)
    nextpnr-ecp5 --85k --package CABGA381 --speed 6 \
      --json "$build_dir/ulx3s_graphics.json" \
      --lpf third_party/projectf/graphics/fpga-graphics/ecp5/ulx3s.lpf \
      --lpf constraints/ulx3s_ftdi.lpf \
      --textcfg "$build_dir/ulx3s_graphics.config" \
      --report "$build_dir/nextpnr_report.json" \
      --detailed-timing-report --placer static --router router1 --seed 1 --freq 60 \
      --log "$report_dir/nextpnr_route.txt" \
      || { tail -120 "$report_dir/nextpnr_route.txt"; exit 1; }
    ;;
esac

case "$stage" in
  bitstream|all)
    ecppack --compress "$build_dir/ulx3s_graphics.config" \
      "$build_dir/ulx3s_graphics.bit" \
      2>&1 | tee "$report_dir/ecppack.txt"
    ;;
esac

if [[ "$stage" != synth && "$stage" != route && "$stage" != bitstream && "$stage" != all ]]; then
  echo "usage: $0 [synth|route|bitstream|all]" >&2
  exit 2
fi
