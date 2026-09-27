.PHONY: help doctor bootstrap-smoke synth-memory lint-fifo test-fifo formal-fifo

help:
	@printf '%s\n' 'Available targets:' '  make doctor          Report bootstrap environment status' '  make bootstrap-smoke Run read-only Phase-0 checks' '  make synth-memory    Run the GFX-004 ECP5 memory inference spike'

doctor:
	@python3 scripts/doctor.py

bootstrap-smoke: doctor
	@set -eu; test -f 00_MASTER_PROJECT_PLAN.md; test -f 01_CHATGPT_PROJECT_OPERATING_INSTRUCTIONS.md; test -f 04_MASTER_CHECKLIST.md; test -f docs/PROJECT_STATE.md; test -f docs/EVIDENCE_INDEX.md; if find rtl ip sw tb formal -type f \( -name '*.sv' -o -name '*.v' -o -name '*.vhd' \) ! -path 'rtl/memory_spike/*' ! -path 'rtl/gfx_pkg.sv' ! -path 'rtl/cmd_fifo.sv' ! -path 'tb/tests/gfx_pkg_tb.sv' ! -path 'tb/tests/cmd_fifo_tb.sv' ! -path 'formal/cmd_fifo_formal.sv' ! -path 'formal/cmd_fifo.sby' ! -path 'formal/cmd_fifo/*' -print -quit | grep -q .; then echo 'ERROR: out-of-scope functional implementation HDL found in bootstrap smoke scope' >&2; exit 1; fi; echo 'bootstrap-smoke: PASS (structure; only authorized memory/package/FIFO HDL excluded)'

synth-memory:
	@scripts/synth/run_memory_spike.sh

lint-fifo:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module cmd_fifo rtl/gfx_pkg.sv rtl/cmd_fifo.sv

test-fifo:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -o /tmp/gfx_pkg_tb rtl/gfx_pkg.sv tb/tests/gfx_pkg_tb.sv && vvp /tmp/gfx_pkg_tb && iverilog -g2012 -o /tmp/cmd_fifo_tb rtl/cmd_fifo.sv tb/tests/cmd_fifo_tb.sv && vvp /tmp/cmd_fifo_tb

formal-fifo:
	@source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && sby -f formal/cmd_fifo.sby
