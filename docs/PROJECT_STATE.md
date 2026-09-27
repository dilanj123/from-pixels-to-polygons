# Project state

## GFX-000 — bootstrap evidence

- Current phase: Phase 0 — Repository / environment bootstrap.
- Current gate: Gate 0 — Contract and Environment; not closed.
- Repository path: `/Users/Dilan/Projects/from-pixels-to-polygons`.
- Branch: `main`.
- Known-good commit: recorded after the bootstrap commit is created.
- Current architecture: specified by the master plan only; no implementation.
- Parent Sobel commit: `ad35514c990f6e1c9eb9fa18aee9d906f9df7721` at tag `v1.0.1-dependency-ready`.
- Selected parent top: `rtl_to_pixels_top_pipelined`.

### Host evidence

- macOS: `26.4.1` (`25E253`).
- Kernel/architecture: Darwin `25.4.0`, `arm64`.
- Git: `/opt/homebrew/bin/git`, version `2.44.0`.
- GitHub CLI: `/opt/homebrew/bin/gh`, version `2.101.0`; authentication status failed because the stored token is invalid.
- Python: `/Library/Frameworks/Python.framework/Versions/3.14/bin/python3`, version `3.14.0`.
- Make: `/usr/bin/make`, GNU Make `3.81`.
- Verilator: `/opt/homebrew/bin/verilator`, version `5.052`.
- Yosys, SBY, nextpnr-ecp5, and discovered formal solvers: missing at bootstrap inspection.
- Board/programming utilities checked: `fujprog`, `openFPGALoader`, `dfu-util`, `ecpprog`, `ujprog`; missing.

### Evidence classification

- Repository and host/tool facts: DERIVED from local command output.
- Dependency metadata: SPECIFIED and recorded; not imported or revalidated by this task.
- `make doctor`: to be recorded after execution.
- Graphics, reference-model, RTL simulation, formal, synthesis, timing, and hardware: no evidence.

### Open items

- Finalize all source-level contracts in GFX-001.
- Re-authenticate GitHub only if a future task explicitly authorizes remote creation.
- Establish the dependency mechanism only when the authoritative plan requires it.
- All later Gate-0 and Gate-1 checklist items remain open unless directly evidenced.
