# Project state

## GFX-004 — memory feasibility spike

- Current phase: Gate 2 — Memory Feasibility.
- Current task: GFX-004 complete; the representative memory spike was
  synthesized with the qualified OSS CAD Suite ECP5 flow.
- Starting known-good HEAD: `22e45177c2c1b63b7ae773dd0b313c48a421a088`.
- GFX-004 synthesis commit: this documentation and evidence commit (`Run GFX-004 memory feasibility synthesis spike`).
- Toolchain activation: `source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment`.
- Yosys: `0.69+154`, nextpnr-ecp5: `0.11.1-34-gc4fbb55a`, and ecppack:
  `1.4-83-g65fe191` were resolved from that suite. SBY and formal solvers
  were present but not used by this memory-only task.
- Combined spike result: 154 `DP16KD`, with 0 generic memories remaining in
  the final Yosys hierarchy; one framebuffer and Z each used 38 `DP16KD`, and
  the 1024x32 FIFO used 2 `DP16KD`.
- The framebuffer style with independent `clk_pix` and `clk_sys` synchronous
  ports mapped to `DP16KD` without synthesis errors or memory-inference
  warnings. This is inference evidence only; no placement, routing, timing,
  or hardware evidence is claimed.
- The LFE5U-85F family reference capacity is 208 18-Kbit sysMEM blocks, 84K
  LUTs, and 156 18x18 multipliers, from the Lattice ECP5 family selection
  table. The 154-block spike therefore fits the sysMEM-block count comparison;
  this is not full integrated utilization.
- Admitted parent context remains separate and unchanged: parent evidence
  records 2 `DP16KD`, 3 `MULT18X18D`, 775 `LUT4`, and 223 `TRELLIS_FF` for
  `rtl_to_pixels_top_pipelined` at the pinned dependency commit.

## GFX-003 — independent quantized-command reference renderer

- Previous phase: Gate 1 — Independent Reference Renderer.
- Current task: GFX-003 complete; complete quantized-command framebuffer/Z reference implemented.
- Starting known-good HEAD: `b2833d173c64f4f3620af81d7db893883803ee6e`.
- GFX-001 contract commit: `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` (`Freeze GFX-001 source-level contracts`).
- GFX-002 implementation commit: `268c04680cae0c5f17d268c54faa4f5cc960b64b` (`Implement GFX-002 reference raster primitives`).
- GFX-003 implementation commit: `6a9dbe1c4eaa71697ca2a13db3892bc93116eb3b` (`Implement GFX-003 quantized reference renderer`).
- Starting branch: `main`; working tree was clean.
- GFX-000: ACCEPTED.
- Gate 0: CLOSED.
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

- Reference renderer: 31/31 standard-library unit tests passed; quantized
  command parsing, clear, multiple triangles, RGB332/Z output, strict depth,
  and deterministic random regression verified.
- GFX-002 primitives: 19/19 standard-library unit tests passed; independent
  quantization, edge, bbox, and single-triangle coverage primitives verified.
- RTL simulation: not run; no evidence.
- Graphics formal: not run; no evidence.
- Graphics synthesis/P&R: GFX-004 memory spike synthesized; no full graphics
  synthesis, placement, routing, timing, or hardware evidence.
- Physical graphics hardware: not run; no evidence.
- Full integrated graphics resources, timing/Fmax, and display platform
  implementation details remain unresolved as allowed by the contract.
- No functional graphics RTL was added.

## Gate-1 status

- Evidenced by GFX-002: fixed-point helpers, edge/AREA/winding/top-left
  mathematics, exact bbox, pixel centres, shared-edge coverage, accepted
  empty-bbox behavior, and signed42 bound derivation.
- Evidenced by GFX-003: command encoder/parser, exact BEGIN_FRAME clear,
  direct R/G/B/Z plane evaluation, RGB332 packing, strict-less-than Z,
  multiple-triangle frames, rejected-geometry no-write behavior, empty frames,
  and fixed-seed repeatability.
- Gate-1 reference-model requirements are evidenced. No RTL, formal, synthesis,
  timing, display, Sobel, or hardware evidence is implied.

## Gate-2 status

- Gate 2: READY TO CLOSE based on the GFX-004 representative ECP5 synthesis
  evidence. All three colour framebuffers and the Z buffer inferred as
  `DP16KD`; the FIFO inferred as 2 `DP16KD`; the combined spike used 154 of
  the 208 LFE5U-85F sysMEM blocks listed by Lattice. No large memory mapped to
  LUT/FF storage, and the dual-clock framebuffer style was accepted by the
  Yosys ECP5 memory mapping.
- The result is not full integrated synthesis and does not establish timing,
  placement, routing, display, Sobel, formal, or hardware behavior.

## Next task

`GFX-005 — Triangle setup and raster RTL, only after Gate 2 closure review`

## Gate-0 closure interpretation

- Missing Yosys, SBY, nextpnr-ecp5, formal solvers, and board utilities are
  explicitly detected and documented; they do not block Gate 0.
- GitHub authentication is invalid and no remote exists; remote creation was
  conditional on authentication/authorization and does not block Gate 0.
- No later implementation gate is complete. Graphics RTL simulation, graphics
  formal, full graphics synthesis/P&R, timing, and physical graphics hardware
  evidence remain absent.
