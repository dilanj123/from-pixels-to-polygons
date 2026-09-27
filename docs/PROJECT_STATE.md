# Project state

## GFX-000 — bootstrap evidence

- Current phase: Phase 0 — Repository / environment bootstrap.
- Current gate: Gate 0 — Contract and Environment; not closed.
- Repository path: `/Users/Dilan/Projects/from-pixels-to-polygons`.
- Branch: `main`.
- Bootstrap known-good commit: `7beabb84a5f66a1f2cba252f3e88cf0647102cf2` (`Bootstrap from-pixels-to-polygons repository`).
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
- Git remotes: none configured.
- Initial repository status: empty Git repository on `main`, no commits, all bootstrap files untracked.
- Final status at the end of the bootstrap commit: clean; no remote configured.

### Evidence classification

- Repository and host/tool facts: DERIVED from local command output.
- Dependency metadata: SPECIFIED and recorded; not imported or revalidated by this task.
- `make doctor`: exit 0; core bootstrap commands available; future-phase EDA and hardware tools reported as informational.
- `make bootstrap-smoke`: exit 0; required authoritative files present and zero implementation HDL files found under `rtl/`, `ip/`, `sw/`, `tb/`, and `formal/`.
- `git diff --check`: exit 0 after non-semantic trailing Markdown whitespace normalization.
- Graphics, reference-model, RTL simulation, formal, synthesis, timing, and hardware: no evidence.

### Open items

- Finalize all source-level contracts in GFX-001.
- Re-authenticate GitHub only if a future task explicitly authorizes remote creation.
- Establish the dependency mechanism only when the authoritative plan requires it.
- All later Gate-0 and Gate-1 checklist items remain open unless directly evidenced.
