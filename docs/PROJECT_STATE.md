# Project state

## GFX-001 — source-level contract freeze

- Current phase: Phase 1 — Source-level contract freeze.
- Current task: GFX-001 documentation/specification only.
- Starting known-good HEAD: `b2833d173c64f4f3620af81d7db893883803ee6e`.
- GFX-001 contract commit: `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` (`Freeze GFX-001 source-level contracts`).
- Starting branch: `main`; working tree was clean.
- GFX-000: ACCEPTED.
- Current gate: Gate 0 — CLOSED.
- Gate 0 closure commit: pending current commit.
- Current known-good pre-closure commit: `9c7478a7302e5da5a9f19043be772223d93d3abe`.
- GFX-001: ACCEPTED.
- Repository path: `/Users/Dilan/Projects/from-pixels-to-polygons`.
- Dependency repository: `https://github.com/dilanj123/from-rtl-to-pixels.git`.
- Dependency tag: `v1.0.1-dependency-ready`.
- Dependency commit: `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`.
- Selected parent top: `rtl_to_pixels_top_pipelined`.
- Dependency admission: SATISFIED for this project; no source import or upstream modification performed.

## Contract status

- D-001 through D-028: recorded in `docs/DECISIONS.md` and incorporated into
  the requirements, microarchitecture, command, fixed-point, verification,
  checklist, Master Plan, and Operating Instructions documents.
- Master Plan Gate 0–12 numbering is canonical and reflected in
  `04_MASTER_CHECKLIST.md`.
- The parent dependency hold is satisfied, but future consumers must still
  verify the immutable tag/commit and its documented interface evidence before
  import.
- GFX-004/Gate 2 explicitly requires separate graphics memory-spike and exact
  admitted-parent resource evidence plus a combined target-device assessment.

## Evidence state

- Reference renderer: not implemented; no evidence.
- RTL simulation: not run; no evidence.
- Graphics formal: not run; no evidence.
- Graphics synthesis/P&R: not run; no evidence.
- Physical graphics hardware: not run; no evidence.
- Actual graphics EBR inference, integrated resources, timing/Fmax, and display
  platform implementation details remain unresolved as allowed by the contract.
- No functional graphics RTL or reference-renderer implementation was added.

## Next task

`GFX-002 — Python fixed-point/reference primitives`

## Gate-0 closure interpretation

- Missing Yosys, SBY, nextpnr-ecp5, formal solvers, and board utilities are
  explicitly detected and documented; they do not block Gate 0.
- GitHub authentication is invalid and no remote exists; remote creation was
  conditional on authentication/authorization and does not block Gate 0.
- No later gate is complete. The reference renderer, graphics RTL simulation,
  graphics formal, graphics synthesis/P&R, and physical graphics hardware
  evidence remain absent.
