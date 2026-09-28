.PHONY: help doctor bootstrap-smoke synth-memory lint-fifo test-fifo formal-fifo lint-decoder test-decoder formal-decoder lint-clear test-clear formal-clear lint-triangle-setup test-triangle-setup lint-raster-walk test-raster-walk lint-fragment-z test-fragment-z

help:
	@printf '%s\n' 'Available targets:' '  make doctor          Report bootstrap environment status' '  make bootstrap-smoke Run read-only Phase-0 checks' '  make synth-memory    Run the GFX-004 ECP5 memory inference spike'

doctor:
	@python3 scripts/doctor.py

bootstrap-smoke: doctor
	@set -eu; test -f 00_MASTER_PROJECT_PLAN.md; test -f 01_CHATGPT_PROJECT_OPERATING_INSTRUCTIONS.md; test -f 04_MASTER_CHECKLIST.md; test -f docs/PROJECT_STATE.md; test -f docs/EVIDENCE_INDEX.md; if find rtl ip sw tb formal -type f \( -name '*.sv' -o -name '*.v' -o -name '*.vhd' \) ! -path 'rtl/memory_spike/*' ! -path 'rtl/gfx_pkg.sv' ! -path 'rtl/cmd_fifo.sv' ! -path 'rtl/cmd_decoder.sv' ! -path 'rtl/clear_engine.sv' ! -path 'rtl/triangle_setup.sv' ! -path 'rtl/raster_walk.sv' ! -path 'rtl/fragment_z.sv' ! -path 'tb/tests/gfx_pkg_tb.sv' ! -path 'tb/tests/cmd_fifo_tb.sv' ! -path 'tb/tests/cmd_decoder_tb.sv' ! -path 'tb/tests/clear_engine_tb.sv' ! -path 'tb/tests/triangle_setup_tb.sv' ! -path 'tb/tests/raster_walk_tb.sv' ! -path 'tb/tests/fragment_z_tb.sv' ! -path 'formal/cmd_fifo_formal.sv' ! -path 'formal/cmd_fifo.sby' ! -path 'formal/cmd_fifo/*' ! -path 'formal/cmd_decoder_formal.sv' ! -path 'formal/cmd_decoder.sby' ! -path 'formal/cmd_decoder/*' ! -path 'formal/clear_engine_formal.sv' ! -path 'formal/clear_engine.sby' ! -path 'formal/clear_engine/*' -print -quit | grep -q .; then echo 'ERROR: out-of-scope functional implementation HDL found in bootstrap smoke scope' >&2; exit 1; fi; echo 'bootstrap-smoke: PASS (structure; only authorized memory/package/FIFO/decoder/clear/setup/walker/fragment-z HDL excluded)'

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
