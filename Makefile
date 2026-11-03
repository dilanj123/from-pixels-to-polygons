.PHONY: help doctor bootstrap-smoke synth-memory lint-fifo test-fifo formal-fifo lint-decoder test-decoder formal-decoder lint-clear test-clear formal-clear lint-triangle-setup test-triangle-setup lint-raster-walk test-raster-walk lint-fragment-z test-fragment-z lint-perf-counters test-perf-counters lint-renderer test-renderer test-memory-wrappers test-renderer-decoder test-renderer-reset test-renderer-counters lint-readback test-readback test-readback-framebuffer lint-presentation test-presentation test-graphics-core lint-sobel-adapters test-sobel-adapters lint-sobel-integration test-sobel-integration test-sobel-modes test-sobel-controller lint-command-system test-command-system lint-uart test-uart test-host test-uart-system formal-buffer-manager formal-fragment-depth formal-sobel-addresses formal-raster-bounds formal-gate8

SOBEL_PARENT_RTL = ip/rtl-to-pixels/rtl/pixel_pkg.sv ip/rtl-to-pixels/rtl/rgb_to_gray.sv \
	ip/rtl-to-pixels/rtl/elastic_stage.sv ip/rtl-to-pixels/rtl/apb_regs.sv \
	ip/rtl-to-pixels/rtl/pixel_control.sv ip/rtl-to-pixels/rtl/line_buffer.sv \
	ip/rtl-to-pixels/rtl/window_3x3.sv ip/rtl-to-pixels/rtl/sobel_compact.sv \
	ip/rtl-to-pixels/rtl/magnitude_clamp.sv ip/rtl-to-pixels/rtl/threshold_stage.sv \
	ip/rtl-to-pixels/rtl/output_control.sv ip/rtl-to-pixels/rtl/rtl_to_pixels_top_pipelined.sv
SOBEL_PYTHON ?= python3
SOBEL_GRAPHICS_RTL = rtl/gfx_pkg.sv third_party/projectf/lib/display/display_480p.sv \
	rtl/scanout_2x.sv rtl/clear_engine.sv rtl/triangle_setup.sv rtl/raster_walk.sv \
	rtl/fragment_z.sv rtl/perf_counters.sv rtl/zbuffer.sv rtl/framebuffer_dp.sv \
	rtl/renderer_core.sv rtl/readback_engine.sv rtl/present_cdc.sv rtl/buffer_manager.sv \
	rtl/sobel_fb_reader.sv rtl/sobel_fb_writer.sv rtl/sobel_apb_master.sv rtl/sobel_controller.sv \
	$(SOBEL_PARENT_RTL) rtl/graphics_core.sv
SYSTEM_COMMAND_RTL = rtl/gfx_pkg.sv rtl/cmd_fifo.sv rtl/cmd_decoder.sv $(filter-out rtl/gfx_pkg.sv,$(SOBEL_GRAPHICS_RTL)) rtl/graphics_command_top.sv

help:
	@printf '%s\n' 'Available targets:' '  make doctor             Report bootstrap environment status' '  make bootstrap-smoke    Run read-only Phase-0 checks' '  make synth-memory       Run the GFX-004 ECP5 memory inference spike' '  make lint-command-system Lint host command/response integration' '  make test-command-system Run command-path protocol regression' '  make lint-uart          Lint UART word bridge' '  make test-uart          Run UART serial loopback regression' '  make test-host          Run host protocol helper tests' '  make lint-presentation  Lint Gate-5 renderer/display composition' '  make test-presentation  Check mailbox/role CDC at three clock phases' '  make test-graphics-core Run three NORMAL reference-rendered frames' '  make lint-sobel-adapters Lint GFX-018/019/020 adapters' '  make test-sobel-adapters Run full-frame adapter/mock regression' '  make lint-sobel-integration Lint real Sobel graphics composition' '  make test-sobel-integration Run renderer-to-Sobel full composition' '  make test-sobel-controller Compare five parent frames to Python oracle' '  make test-sobel-modes Check NORMAL/SOBEL role transitions'

doctor:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && python3 scripts/doctor.py

bootstrap-smoke: doctor
	@set -eu; test -f 00_MASTER_PROJECT_PLAN.md; test -f 01_CHATGPT_PROJECT_OPERATING_INSTRUCTIONS.md; test -f 04_MASTER_CHECKLIST.md; test -f docs/PROJECT_STATE.md; test -f docs/EVIDENCE_INDEX.md; if find rtl ip sw tb formal -type f \( -name '*.sv' -o -name '*.v' -o -name '*.vhd' \) ! -path 'rtl/memory_spike/*' ! -path 'ip/rtl-to-pixels/*' ! -path 'rtl/gfx_pkg.sv' ! -path 'rtl/cmd_fifo.sv' ! -path 'rtl/cmd_decoder.sv' ! -path 'rtl/clear_engine.sv' ! -path 'rtl/triangle_setup.sv' ! -path 'rtl/raster_walk.sv' ! -path 'rtl/fragment_z.sv' ! -path 'rtl/perf_counters.sv' ! -path 'rtl/framebuffer_dp.sv' ! -path 'rtl/zbuffer.sv' ! -path 'rtl/renderer_core.sv' ! -path 'rtl/readback_engine.sv' ! -path 'rtl/present_cdc.sv' ! -path 'rtl/buffer_manager.sv' ! -path 'rtl/graphics_core.sv' ! -path 'rtl/scanout_2x.sv' ! -path 'rtl/sobel_fb_reader.sv' ! -path 'rtl/sobel_fb_writer.sv' ! -path 'rtl/sobel_apb_master.sv' ! -path 'rtl/sobel_controller.sv' ! -path 'rtl/graphics_command_top.sv' ! -path 'rtl/uart_word_bridge.sv' ! -path 'rtl/graphics_uart_top.sv' ! -path 'tb/tests/graphics_command_top_tb.sv' ! -path 'tb/tests/graphics_uart_top_tb.sv' ! -path 'tb/tests/uart_word_bridge_tb.sv' ! -path 'tb/tests/gfx_pkg_tb.sv' ! -path 'tb/tests/cmd_fifo_tb.sv' ! -path 'tb/tests/cmd_decoder_tb.sv' ! -path 'tb/tests/clear_engine_tb.sv' ! -path 'tb/tests/triangle_setup_tb.sv' ! -path 'tb/tests/raster_walk_tb.sv' ! -path 'tb/tests/fragment_z_tb.sv' ! -path 'tb/tests/memory_wrappers_tb.sv' ! -path 'tb/tests/renderer_core_tb.sv' ! -path 'tb/tests/renderer_decoder_smoke_tb.sv' ! -path 'tb/tests/renderer_reset_tb.sv' ! -path 'tb/tests/perf_counters_tb.sv' ! -path 'tb/tests/renderer_counter_tb.sv' ! -path 'tb/tests/readback_engine_tb.sv' ! -path 'tb/tests/readback_framebuffer_tb.sv' ! -path 'tb/tests/buffer_manager_tb.sv' ! -path 'tb/tests/graphics_core_tb.sv' ! -path 'tb/tests/scanout_2x_tb.sv' ! -path 'tb/tests/sobel_adapters_tb.sv' ! -path 'tb/tests/sobel_modes_tb.sv' ! -path 'tb/tests/sobel_integration_tb.sv' ! -path 'tb/tests/sobel_controller_tb.sv' ! -path 'formal/cmd_fifo_formal.sv' ! -path 'formal/cmd_fifo.sby' ! -path 'formal/cmd_fifo/*' ! -path 'formal/cmd_decoder_formal.sv' ! -path 'formal/cmd_decoder.sby' ! -path 'formal/cmd_decoder/*' ! -path 'formal/clear_engine_formal.sv' ! -path 'formal/clear_engine.sby' ! -path 'formal/clear_engine/*' ! -path 'formal/buffer_manager_formal.sv' ! -path 'formal/buffer_manager.sby' ! -path 'formal/fragment_depth_formal.sv' ! -path 'formal/fragment_depth.sby' ! -path 'formal/sobel_reader_bounds_formal.sv' ! -path 'formal/sobel_reader_bounds.sby' ! -path 'formal/sobel_writer_bounds_formal.sv' ! -path 'formal/sobel_writer_bounds.sby' ! -path 'formal/raster_bounds_formal.sv' ! -path 'formal/raster_bounds.sby' ! -path 'formal/buffer_manager/*' ! -path 'formal/fragment_depth/*' ! -path 'formal/sobel_reader_bounds/*' ! -path 'formal/sobel_writer_bounds/*' ! -path 'formal/raster_bounds/*' -print -quit | grep -q .; then echo 'ERROR: out-of-scope functional implementation HDL found in bootstrap smoke scope' >&2; exit 1; fi; echo 'bootstrap-smoke: PASS (structure; authorized GFX primitive, renderer, readback, Gate-5 and GFX-018/019/020/021/022 HDL excluded)'

synth-memory:
	@scripts/synth/run_memory_spike.sh

lint-fifo:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module cmd_fifo rtl/gfx_pkg.sv rtl/cmd_fifo.sv

test-fifo:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -o /tmp/gfx_pkg_tb rtl/gfx_pkg.sv tb/tests/gfx_pkg_tb.sv && vvp /tmp/gfx_pkg_tb && iverilog -g2012 -o /tmp/cmd_fifo_tb rtl/cmd_fifo.sv tb/tests/cmd_fifo_tb.sv && vvp /tmp/cmd_fifo_tb

formal-fifo:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && sby -f formal/cmd_fifo.sby

lint-decoder:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module cmd_decoder rtl/gfx_pkg.sv rtl/cmd_decoder.sv

test-decoder:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -o /tmp/cmd_decoder_tb rtl/gfx_pkg.sv rtl/cmd_decoder.sv tb/tests/cmd_decoder_tb.sv && vvp /tmp/cmd_decoder_tb

formal-decoder:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && sby -f formal/cmd_decoder.sby

lint-clear:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module clear_engine rtl/gfx_pkg.sv rtl/clear_engine.sv

test-clear:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -o /tmp/clear_engine_tb rtl/gfx_pkg.sv rtl/clear_engine.sv tb/tests/clear_engine_tb.sv && vvp /tmp/clear_engine_tb

formal-clear:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && sby -f formal/clear_engine.sby

lint-triangle-setup:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module triangle_setup rtl/gfx_pkg.sv rtl/triangle_setup.sv

test-triangle-setup:
	@python3 tb/tests/generate_triangle_setup_vectors.py
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -o /tmp/triangle_setup_tb rtl/gfx_pkg.sv rtl/triangle_setup.sv tb/tests/triangle_setup_tb.sv && vvp /tmp/triangle_setup_tb

lint-raster-walk:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module raster_walk rtl/gfx_pkg.sv rtl/raster_walk.sv

test-raster-walk:
	@python3 tb/tests/generate_raster_walk_vectors.py
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -I tb/tests -o /tmp/raster_walk_tb rtl/gfx_pkg.sv rtl/raster_walk.sv tb/tests/raster_walk_tb.sv && vvp /tmp/raster_walk_tb

lint-fragment-z:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module fragment_z rtl/gfx_pkg.sv rtl/fragment_z.sv

test-fragment-z:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -o /tmp/fragment_z_tb rtl/gfx_pkg.sv rtl/fragment_z.sv tb/tests/fragment_z_tb.sv && vvp /tmp/fragment_z_tb

lint-perf-counters:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module perf_counters rtl/gfx_pkg.sv rtl/perf_counters.sv

test-perf-counters:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s perf_counters_tb -o /tmp/perf_counters_tb rtl/gfx_pkg.sv rtl/perf_counters.sv tb/tests/perf_counters_tb.sv && vvp /tmp/perf_counters_tb

lint-renderer:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module renderer_core rtl/gfx_pkg.sv rtl/clear_engine.sv rtl/triangle_setup.sv rtl/raster_walk.sv rtl/fragment_z.sv rtl/perf_counters.sv rtl/framebuffer_dp.sv rtl/zbuffer.sv rtl/renderer_core.sv

test-memory-wrappers:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -o /tmp/memory_wrappers_tb rtl/gfx_pkg.sv rtl/framebuffer_dp.sv rtl/zbuffer.sv tb/tests/memory_wrappers_tb.sv && vvp /tmp/memory_wrappers_tb

test-renderer:
	@python3 tb/tests/generate_renderer_vectors.py
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s renderer_core_tb -o /tmp/renderer_core_tb rtl/gfx_pkg.sv rtl/clear_engine.sv rtl/triangle_setup.sv rtl/raster_walk.sv rtl/fragment_z.sv rtl/perf_counters.sv rtl/framebuffer_dp.sv rtl/zbuffer.sv rtl/renderer_core.sv rtl/readback_engine.sv tb/tests/renderer_core_tb.sv && vvp /tmp/renderer_core_tb +VEC_DIR=/tmp/gfx012_vectors

test-renderer-decoder: test-renderer
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s renderer_decoder_smoke_tb -o /tmp/renderer_decoder_smoke_tb rtl/gfx_pkg.sv rtl/cmd_decoder.sv rtl/clear_engine.sv rtl/triangle_setup.sv rtl/raster_walk.sv rtl/fragment_z.sv rtl/perf_counters.sv rtl/framebuffer_dp.sv rtl/zbuffer.sv rtl/renderer_core.sv tb/tests/renderer_decoder_smoke_tb.sv && vvp /tmp/renderer_decoder_smoke_tb +VEC_DIR=/tmp/gfx012_vectors

test-renderer-reset:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s renderer_reset_tb -o /tmp/renderer_reset_tb rtl/gfx_pkg.sv rtl/clear_engine.sv rtl/triangle_setup.sv rtl/raster_walk.sv rtl/fragment_z.sv rtl/perf_counters.sv rtl/framebuffer_dp.sv rtl/zbuffer.sv rtl/renderer_core.sv tb/tests/renderer_reset_tb.sv && vvp /tmp/renderer_reset_tb

test-renderer-counters:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s renderer_counter_tb -o /tmp/renderer_counter_tb rtl/gfx_pkg.sv rtl/clear_engine.sv rtl/triangle_setup.sv rtl/raster_walk.sv rtl/fragment_z.sv rtl/perf_counters.sv rtl/framebuffer_dp.sv rtl/zbuffer.sv rtl/renderer_core.sv tb/tests/renderer_counter_tb.sv && vvp /tmp/renderer_counter_tb

lint-readback:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module readback_engine rtl/readback_engine.sv

test-readback:
	@python3 tb/tests/generate_renderer_vectors.py
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s readback_engine_tb -o /tmp/readback_engine_tb rtl/readback_engine.sv tb/tests/readback_engine_tb.sv && vvp /tmp/readback_engine_tb +VEC_DIR=/tmp/gfx012_vectors

test-readback-framebuffer:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s readback_framebuffer_tb -o /tmp/readback_framebuffer_tb rtl/gfx_pkg.sv rtl/framebuffer_dp.sv rtl/readback_engine.sv tb/tests/readback_framebuffer_tb.sv && vvp /tmp/readback_framebuffer_tb


lint-presentation:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 -Wno-TIMESCALEMOD --top-module graphics_core $(SOBEL_GRAPHICS_RTL)

test-presentation:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && for spec in '5 7 1' '4 9 3' '7 5 2'; do set -- $$spec; iverilog -g2012 -s buffer_manager_tb -Pbuffer_manager_tb.SYS_HALF=$$1 -Pbuffer_manager_tb.PIX_HALF=$$2 -Pbuffer_manager_tb.PIX_PHASE=$$3 -o /tmp/buffer_manager_tb rtl/present_cdc.sv rtl/buffer_manager.sv tb/tests/buffer_manager_tb.sv && vvp /tmp/buffer_manager_tb || exit $$?; done

test-graphics-core:
	@python3 tb/tests/generate_renderer_vectors.py
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s graphics_core_tb -o /tmp/graphics_core_tb $(SOBEL_GRAPHICS_RTL) tb/tests/graphics_core_tb.sv && vvp /tmp/graphics_core_tb +VEC_DIR=/tmp/gfx012_vectors

lint-sobel-adapters:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module sobel_fb_reader rtl/sobel_fb_reader.sv && verilator --lint-only --language 1800-2012 --top-module sobel_fb_writer rtl/sobel_fb_writer.sv && verilator --lint-only --language 1800-2012 --top-module sobel_apb_master rtl/sobel_apb_master.sv

test-sobel-adapters:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s sobel_adapters_tb -o /tmp/sobel_adapters_tb rtl/sobel_fb_reader.sv rtl/sobel_fb_writer.sv rtl/sobel_apb_master.sv tb/tests/sobel_adapters_tb.sv && vvp /tmp/sobel_adapters_tb

lint-sobel-integration:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 -Wno-TIMESCALEMOD --top-module graphics_core $(SOBEL_GRAPHICS_RTL)

test-sobel-integration:
	@python3 tb/tests/generate_renderer_vectors.py
	@$(SOBEL_PYTHON) tb/tests/generate_sobel_vectors.py /tmp/gfx021_vectors /tmp/gfx012_vectors
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s sobel_integration_tb -o /tmp/sobel_integration_tb $(SOBEL_GRAPHICS_RTL) tb/tests/sobel_integration_tb.sv && vvp /tmp/sobel_integration_tb +VEC_DIR=/tmp/gfx012_vectors

test-sobel-controller:
	@$(SOBEL_PYTHON) tb/tests/generate_sobel_vectors.py /tmp/gfx021_vectors /tmp/gfx012_vectors
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s sobel_controller_tb -o /tmp/sobel_controller_tb $(SOBEL_GRAPHICS_RTL) tb/tests/sobel_controller_tb.sv && vvp /tmp/sobel_controller_tb +VEC_DIR=/tmp/gfx021_vectors

test-sobel-modes:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s sobel_modes_tb -o /tmp/sobel_modes_tb rtl/present_cdc.sv rtl/buffer_manager.sv tb/tests/sobel_modes_tb.sv && vvp /tmp/sobel_modes_tb

lint-command-system:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 -Wno-TIMESCALEMOD --top-module graphics_command_top $(SYSTEM_COMMAND_RTL) && verilator --lint-only --language 1800-2012 -Wno-TIMESCALEMOD --top-module graphics_uart_top $(SYSTEM_COMMAND_RTL) rtl/uart_word_bridge.sv rtl/graphics_uart_top.sv

test-command-system:
	@python3 tb/tests/generate_command_system_vectors.py
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s graphics_command_top_tb -o /tmp/graphics_command_top_tb $(SYSTEM_COMMAND_RTL) tb/tests/graphics_command_top_tb.sv && vvp /tmp/graphics_command_top_tb

lint-uart:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module uart_word_bridge rtl/uart_word_bridge.sv

test-uart:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s uart_word_bridge_tb -o /tmp/uart_word_bridge_tb rtl/uart_word_bridge.sv tb/tests/uart_word_bridge_tb.sv && vvp /tmp/uart_word_bridge_tb

test-uart-system:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s graphics_uart_top_tb -o /tmp/graphics_uart_top_tb $(SYSTEM_COMMAND_RTL) rtl/uart_word_bridge.sv rtl/graphics_uart_top.sv tb/tests/graphics_uart_top_tb.sv && vvp /tmp/graphics_uart_top_tb

test-host:
	@PYTHONPATH=sw/host python3 -m unittest -v test_gfx_host

formal-buffer-manager:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && sby -f formal/buffer_manager.sby

formal-fragment-depth:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && sby -f formal/fragment_depth.sby

formal-sobel-addresses:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && sby -f formal/sobel_reader_bounds.sby && sby -f formal/sobel_writer_bounds.sby

formal-raster-bounds:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && sby -f formal/raster_bounds.sby

formal-gate8: formal-fifo formal-buffer-manager formal-raster-bounds formal-fragment-depth formal-sobel-addresses
