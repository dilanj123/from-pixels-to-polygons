.PHONY: help doctor bootstrap-smoke synth-memory

help:
	@printf '%s\n' 'Available targets:' '  make doctor          Report bootstrap environment status' '  make bootstrap-smoke Run read-only Phase-0 checks' '  make synth-memory    Run the GFX-004 ECP5 memory inference spike'

doctor:
	@python3 scripts/doctor.py

bootstrap-smoke: doctor
	@set -eu; test -f 00_MASTER_PROJECT_PLAN.md; test -f 01_CHATGPT_PROJECT_OPERATING_INSTRUCTIONS.md; test -f 04_MASTER_CHECKLIST.md; test -f docs/PROJECT_STATE.md; test -f docs/EVIDENCE_INDEX.md; if find rtl ip sw tb formal -type f \( -name '*.sv' -o -name '*.v' -o -name '*.vhd' \) ! -path 'rtl/memory_spike/*' -print -quit | grep -q .; then echo 'ERROR: functional implementation HDL found in bootstrap smoke scope' >&2; exit 1; fi; echo 'bootstrap-smoke: PASS (structure, no functional graphics HDL; memory spike excluded)'

synth-memory:
	@scripts/synth/run_memory_spike.sh
