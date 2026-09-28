# Project state

## Current state

- Current phase: Gate 4 — Complete Colour/Z Renderer.
- Gate 2: CLOSED. Gate 3: CLOSED. Gate 4: OPEN.
- Current known-good commit: `ebafcb69dcd44cabafaec81ccca493608cd6cb89`.
- Repository: `https://github.com/dilanj123/from-pixels-to-polygons`.
- Branch: `main`; local HEAD equals `origin/main`.
- GFX-005 command FIFO: RTL SIMULATION VERIFIED; selected FIFO properties
  FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS.
- GFX-006 command decoder: RTL SIMULATION VERIFIED; selected decoder
  properties FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS.
- GFX-007 clear engine: RTL SIMULATION VERIFIED; selected clear properties
  FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS.
- GFX-008 triangle setup: RTL SIMULATION VERIFIED; triangle-setup formal was
  NOT RUN / NOT CLAIMED.
- Python reference: REFERENCE-MODEL VERIFIED.
- GFX-010 attribute stepping: RTL SIMULATION VERIFIED; no attribute formal
  proof is claimed.
- GFX-011 fragment/Z contract: SPECIFIED by D-032; implementation NOT STARTED.
- No fragment/Z integration, complete renderer, full graphics synthesis/P&R,
  timing, or physical hardware evidence exists yet.
- Current next task: `GFX-011 — Fragment/Z stage`.
- Historical GFX-008/GFX-009 state-sync notes are retained in their milestone
  sections below; the current Gate-4 state is authoritative here.

## GFX-006 — command decoder

- Current phase: Gate 3 — Raster Primitive / command infrastructure.
- Current task: GFX-006 complete; the production command decoder collects and
  validates frozen fixed-length packets, emits one atomic decoded transaction
  or one syntactic error event, and performs no command execution.
- Decoder simulation: PASS, 80 self-checking assertions, including all frozen
  opcodes, reserved-field and coordinate errors, unknown-opcode resynchronization,
  malformed known-packet alignment, truncation, reset, and output stalls.
- Decoder formal: PASS under the documented bounded BMC harness, SBY 0.69,
  Z3, depth 25. The harness checks packet atomicity, partial-packet silence,
  reset discard, stalled-output stability, unknown-opcode one-word handling,
  bounded packet length, and mutually exclusive decoded/error outputs. This is
  not a whole-protocol proof.
- Runtime state legality remains owned by the later controller/integration
  layer. The decoder validates syntax only and does not implement command
  side effects. Decoder-generated syntax errors own the exposed sticky
  `cmd_error`; runtime legality errors remain deferred.
- Existing FIFO simulation and 31-test Python reference regression remain
  passing. GFX-007 adds only the standalone clear stream; triangle setup is
  now complete, while raster, fragment/Z, display, Sobel, and
  command-execution integration remain unimplemented.

## Historical next task at GFX-008 state synchronization

`GFX-010 — Attribute stepping`

## GFX-008 — triangle setup

- GFX-008 complete. The standalone triangle-setup block consumes a legal
  decoded DRAW transaction and emits one registered immutable setup payload
  through ready/valid handshaking.
- D-029 classifications are implemented exactly: RASTER, EMPTY, DEGENERATE,
  and BACKFACE. Non-RASTER bbox and initial-edge fields use canonical zero.
- The independent Python vector adapter generated 160 legal vectors: 80
  RASTER, 2 EMPTY, 1 DEGENERATE, and 77 BACKFACE. RTL simulation compared
  5,474 setup fields with zero mismatches.
- Verilator lint and Yosys component sanity passed. No formal setup proof was
  added; no raster traversal, attribute accumulation, fragment/Z, framebuffer,
  or controller integration was implemented.
- Gate 3 remains OPEN. Next task: `GFX-009 — Raster walker coverage only`.

## GFX-008-SPEC-FREEZE — D-029

- GFX-008 implementation was previously blocked by an undefined
  synthesizable representation for empty/rejected setup results.
- D-029 resolves that gap: four explicit setup classifications, canonical-zero
  non-raster bbox/initial-edge fields, universally valid edge/AREA/step and
  attribute fields, and decoder-owned coordinate-range validation are now
  specified.
- GFX-007 remains accepted. Gate 3 remains OPEN.
- No RTL, testbench, formal, synthesis, or reference implementation changed.
- Next task: `GFX-008 — Triangle setup`.

## GFX-009-SPEC-FREEZE — D-030

- D-030 specifies the coverage-only walker input/output handshakes, RASTER-only
  precondition, candidate retirement under covered-output backpressure,
  row-major horizontal/row advancement, final-candidate completion, zero-cover
  RASTER behavior, reset abort, and the GFX-009/GFX-010 boundary.
- This is specification evidence only. No raster-walker RTL, simulation, formal,
  synthesis, timing, or hardware evidence is claimed.
- Gate 3 remains OPEN. Next task: `GFX-009 — Raster walker coverage only`.

## GFX-009 — raster walker coverage only

- GFX-009 is accepted as RTL SIMULATION VERIFIED. The standalone walker
  consumes D-029 RASTER setup payloads, traverses every bbox candidate in
  row-major order, applies the top-left rule, and emits covered coordinates
  matching the independent Python oracle.
- The deterministic suite used 48 RASTER vectors from geometry seed `0x9009`,
  covering 39,207 candidates and 11,801 covered transfers, including 3
  zero-covered RASTER cases, with maximum covered output count 1,104. It
  passed no-stall, randomized backpressure, final-covered-output stalls, reset
  abort/restart, and shared-edge union/no-overlap tests.
- GFX-009 did not add attributes, fragment/Z, framebuffer writes, controller
  integration, display, Sobel, or optimization. No raster-walker formal proof
  was run or claimed.
- Gate 3 remains OPEN. Next task: `GFX-010 — Attribute stepping`.

## GFX-010-SPEC-FREEZE — D-031

- D-031 freezes signed42 Q8 row/current R/G/B/Z accumulators, sign-extended
  signed32 starts/gradients, raw signed42 covered-fragment fields, stall and
  uncovered-candidate behavior, row transitions, reset, and the GFX-010/GFX-011
  boundary.
- This is specification evidence only. No attribute RTL, simulation, formal,
  synthesis, timing, or hardware evidence is claimed.
- Gate 3 remains OPEN. Next task: `GFX-010 — Attribute stepping`.

## GFX-010 — attribute stepping

- GFX-010 is accepted as RTL SIMULATION VERIFIED. The existing GFX-009 walker
  now maintains signed42 Q8 row/current R/G/B/Z state and emits raw signed42
  attributes with the corresponding covered coordinate.
- The independent vector suite compared 47,716 accepted raw fields across
  deterministic geometry, attribute extrema, signed42 width expansion,
  randomized backpressure, final stalls, reset/restart, and shared-edge cases.
  Coordinate and R/G/B/Z mismatch counts were all zero.
- No quantization, RGB332 packing, framebuffer address, depth, framebuffer,
  controller, display, or Sobel logic was added. No attribute formal proof is
  claimed.
- Gate 3 is CLOSED. Gate 4 is OPEN. Next task: `GFX-011 — Fragment/Z stage`.

## GFX-007 — clear engine

- GFX-007 complete. The standalone clear engine accepts one request while
  idle, captures RGB332, and emits coincident colour/Z writes for exactly
  addresses `0..76799` at one address per active `clk_sys` cycle.
- Full-depth simulation passed 210 self-checking assertions across clear
  values `0x00`, `0xFF`, `0xA5`, one deterministic randomized byte, repeated
  clears, and reset-abort/restart cases. Each uninterrupted clear produced
  76,800 colour writes and 76,800 Z writes with no duplicates, skips, or
  out-of-range addresses.
- Reduced formal instance: 8 pixels, 4-bit address, SBY 0.69/Z3 BMC depth
  20. Address range/increment, coincident writes, captured colour, Z value,
  idle/reset suppression, and completion properties passed. This does not
  prove every cycle of the 76,800-pixel production instance.
- No controller integration, framebuffer-role ownership, triangle setup,
  raster, fragment/Z, display, Sobel, or command execution was added.

## GFX-005 — package and command FIFO

- Current phase: Gate 3 — Raster Primitive / command infrastructure.
- At the GFX-005 milestone, the task was complete; `gfx_pkg` constants/types and the production
  1024×32 single-clock command FIFO are implemented and verified.
- Starting known-good HEAD: `abcb0a8a2858a85c5ed4bc0664a19901a9622824`.
- Gate 2: CLOSED. Gate 3: OPEN.
- Checklist audit: the prior GFX-004 `04_MASTER_CHECKLIST.md` change only
  records measured Gate-2 synthesis evidence and its representative-evidence
  limitation; no unrelated checklist content was found.
- FIFO simulation: 11,677 cycles, deterministic seed `0x005005`, 6,999
  accepted pushes and 6,999 accepted pops; exact-full, backpressure, drain,
  stall, simultaneous replacement, wraparound, repeated fill/drain, and
  randomized scoreboard cases passed.
- FIFO formal: the GFX-005-FORMAL-ORDERING correction uses SBY 0.69 with Z3,
  bounded mode at depth 12, and a structurally identical depth-4 instance
  while production defaults remain 1024×32. Its scalar ghost queue checks
  oldest-token output ordering and accepted-minus-consumed conservation; reset,
  level bounds, empty/full handshaking, stalled output stability, first-token
  delivery, and full-state reachability passed with no counterexample. The
  earlier GFX-005 safety proof used depth 25 k-induction; the new ordering
  abstraction is reported as bounded formal evidence, not induction over the
  literal 1024-entry RAM.
- No command decoder, clear engine, triangle setup, raster walker,
  framebuffer renderer, Z pipeline, display, or Sobel RTL was added.

## GFX-005-FORMAL-ORDERING status

- Explicit tracked-token ordering and token-conservation properties are
  present in `formal/cmd_fifo_formal.sv` and pass the recorded bounded SBY run.
- The ghost queue head comparison is a stronger FIFO-order check than a
  separate two-token assertion within the formal epoch: every accepted token
  must be the next token on a legal output transfer. Duplicate consumption or
  disappearance would violate the ghost-count/head invariants.
- The reduced-depth proof does not prove every storage bit of the literal
  1024-entry RAM. Production 1024-depth ordering, wraparound, and stress
  remain covered by `make test-fifo` simulation.

## GFX-004 — memory feasibility spike

- Previous phase: Gate 2 — Memory Feasibility.
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

- D-001 through D-029: recorded in `docs/DECISIONS.md` and incorporated into
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
- Historical pre-GFX-005 state: RTL simulation had not been run; subsequent
  GFX-005 through GFX-008 RTL simulation evidence is recorded above.
- Historical pre-formal state: graphics formal had not been run; selected FIFO,
  decoder, and clear properties are now formally checked under documented
  assumptions, while triangle-setup formal remains not run/not claimed.
- Graphics synthesis/P&R: GFX-004 memory spike synthesized; no full graphics
  synthesis, placement, routing, timing, or hardware evidence.
- Physical graphics hardware: not run; no evidence.
- Full integrated graphics resources, timing/Fmax, and display platform
  implementation details remain unresolved as allowed by the contract.
- No raster coverage walker or complete renderer RTL has been added. GFX-005
  added only package/FIFO infrastructure; GFX-006 through GFX-008 added the
  decoder, clear engine, and triangle-setup blocks authorized by their tasks.

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

- Gate 2: CLOSED based on the GFX-004 representative ECP5 synthesis
  evidence. All three colour framebuffers and the Z buffer inferred as
  `DP16KD`; the FIFO inferred as 2 `DP16KD`; the combined spike used 154 of
  the 208 LFE5U-85F sysMEM blocks listed by Lattice. No large memory mapped to
  LUT/FF storage, and the dual-clock framebuffer style was accepted by the
  Yosys ECP5 memory mapping.
- The result is not full integrated synthesis and does not establish timing,
  placement, routing, display, Sobel, formal, or hardware behavior.

## Next task

`GFX-010 — Attribute stepping`

## Historical Gate-0 closure interpretation

- Missing Yosys, SBY, nextpnr-ecp5, formal solvers, and board utilities are
  explicitly detected and documented; they do not block Gate 0.
- At the historical Gate-0 review point, GitHub authentication was invalid and
  no remote existed; remote creation was conditional on authentication and
  authorization and did not block Gate 0.
- The repository was subsequently published at
  `https://github.com/dilanj123/from-pixels-to-polygons`; current publication
  state is recorded in the Current state section above.
- No later implementation gate is complete. Raster coverage, attribute
  stepping, full graphics synthesis/P&R, timing, and physical graphics
  hardware evidence remain absent.
