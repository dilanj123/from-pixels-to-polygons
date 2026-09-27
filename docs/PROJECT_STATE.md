# Project state

## GFX-002 — independent reference primitives

- Current phase: Gate 1 — Independent Reference Renderer.
- Current task: GFX-002 complete; primitive/reference basis only.
- Starting known-good HEAD: `b2833d173c64f4f3620af81d7db893883803ee6e`.
- GFX-001 contract commit: `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` (`Freeze GFX-001 source-level contracts`).
- GFX-002 implementation commit: `268c04680cae0c5f17d268c54faa4f5cc960b64b` (`Implement GFX-002 reference raster primitives`).
- Starting branch: `main`; working tree was clean.
- GFX-000: ACCEPTED.
- Current gate: Gate 0 — CLOSED.
- Gate 0 closure decision recorded by commit: `ca915a918c85bfe3e85602d6a93e4644c74f3cfd`.
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
- GFX-002 primitives: 19/19 standard-library unit tests passed; independent
  quantization, edge, bbox, and single-triangle coverage primitives verified.
- RTL simulation: not run; no evidence.
- Graphics formal: not run; no evidence.
- Graphics synthesis/P&R: not run; no evidence.
- Physical graphics hardware: not run; no evidence.
- Actual graphics EBR inference, integrated resources, timing/Fmax, and display
  platform implementation details remain unresolved as allowed by the contract.
- No functional graphics RTL or reference-renderer implementation was added.

## Gate-1 status

- Evidenced by GFX-002: fixed-point helpers, edge/AREA/winding/top-left
  mathematics, exact bbox, pixel centres, shared-edge coverage, accepted
  empty-bbox behavior, and signed42 bound derivation.
- Still open: full framebuffer/Z reference renderer, command parser/encoder,
  multi-triangle frame model, depth reference, and random frame regression.

## Next task

`GFX-003 — Reference framebuffer/Z renderer`

## Gate-0 closure interpretation

- Missing Yosys, SBY, nextpnr-ecp5, formal solvers, and board utilities are
  explicitly detected and documented; they do not block Gate 0.
- GitHub authentication is invalid and no remote exists; remote creation was
  conditional on authentication/authorization and does not block Gate 0.
- No later gate is complete. The reference renderer, graphics RTL simulation,
  graphics formal, graphics synthesis/P&R, and physical graphics hardware
  evidence remain absent.
