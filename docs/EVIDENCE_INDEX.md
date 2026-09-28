# Evidence index

## GFX-001 source-level contract evidence

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| D-001–D-029 are recorded | `GFX-008-SPEC-FREEZE commit` | `docs/DECISIONS.md` and cross-document review | specified source input only | SPECIFIED |
| Exact dependency is admitted | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | `docs/PROJECT_STATE.md`, `docs/REQUIREMENTS.md` | URL/tag/commit/top exact; no source import | SPECIFIED |
| Gate numbering is canonical | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | Master Plan and `04_MASTER_CHECKLIST.md` review | Gate 0–12 mapping from D-001 | SPECIFIED |
| Requirement-to-verification coverage is planned | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | `docs/VERIFICATION_PLAN.md` | planned methods only; no tests run | SPECIFIED |
| Combined memory feasibility is a hard early gate | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | Master Plan, checklist, GFX-004, microarchitecture | actual resource evidence still required | SPECIFIED |
| No graphics implementation was added | `111fe6f9bc7116f7007aaf89e781ddd3d8871f42` | file scan and allowed-file review | documentation-only task | LOCAL OBSERVATION |

## Gate-0 closure milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Gate 0 is closed | `ca915a918c85bfe3e85602d6a93e4644c74f3cfd` | final Gate-0 review, `make doctor`, `make bootstrap-smoke`, clean repository audit | missing future tools are documented prerequisites, not Gate-0 blockers | SPECIFIED / LOCAL OBSERVATION |
| GFX-000 and GFX-001 are accepted | `ca915a918c85bfe3e85602d6a93e4644c74f3cfd` | `docs/PROJECT_STATE.md`, accepted task evidence | no later gate implied | SPECIFIED |
| Tool availability and missing states are known | `ca915a918c85bfe3e85602d6a93e4644c74f3cfd` | `make doctor` | no tool installation performed | LOCAL OBSERVATION |

## Dependency record

```text
Repository: https://github.com/dilanj123/from-rtl-to-pixels.git
Tag: v1.0.1-dependency-ready
Commit: ad35514c990f6e1c9eb9fa18aee9d906f9df7721
Selected top: rtl_to_pixels_top_pipelined
```

The parent record is an immutable dependency boundary, not graphics
implementation, simulation, synthesis, timing, or hardware evidence.

## Evidence deliberately absent

No reference-model, RTL simulation, formal, synthesis, timing, P&R, physical
framebuffer, display, resource-count, Fmax, or performance claim is entered by
GFX-001.

## GFX-002 primitive milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Independent fixed-point/raster primitives pass focused tests | `268c04680cae0c5f17d268c54faa4f5cc960b64b` | `python3 -m unittest discover -s sw/reference -p 'test_*.py' -v` | 19 tests passed; no full framebuffer/Z renderer | REFERENCE-MODEL VERIFIED |
| Signed42 attribute bound is satisfied | `268c04680cae0c5f17d268c54faa4f5cc960b64b` | `DerivationTests.test_signed42_attribute_bound` | mathematical bound only | DERIVED |
| No functional graphics RTL was added | `268c04680cae0c5f17d268c54faa4f5cc960b64b` | functional HDL scan and bootstrap smoke check | RTL/reference primitive scope only | LOCAL OBSERVATION |

GFX-002 does not claim a complete reference renderer, framebuffer/Z behavior,
RTL simulation, formal, synthesis, timing, or hardware evidence.

## GFX-003 complete reference-renderer milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Quantized command parser/encoder and frame reference pass | `6a9dbe1c4eaa71697ca2a13db3892bc93116eb3b` | `python3 -m unittest discover -s sw/reference -p 'test_*.py' -v` | 31 tests passed, including all 19 GFX-002 tests | REFERENCE-MODEL VERIFIED |
| Fixed-seed regression is repeatable | `6a9dbe1c4eaa71697ca2a13db3892bc93116eb3b` | standalone two-run `random_regression` command | seeds 1, 7, 42; identical framebuffer/Z hashes | REFERENCE-MODEL VERIFIED |
| Gate-1 reference-model requirements are evidenced | `6a9dbe1c4eaa71697ca2a13db3892bc93116eb3b` | directed tests, multi-triangle frame, empty frame, depth/order tests | no RTL or hardware claim | REFERENCE-MODEL VERIFIED |

### GFX-003 random regression records

| Seed | Framebuffer SHA-256 | Z-buffer SHA-256 |
|---:|---|---|
| 1 | `f5be4ccae05fe568fbca3a12102ad03344636f90d2898f90caa6cfc55e9ac7eb` | `e29287f671fb7c0855a121f9c7f1bdf324922242f7ab47454e3375d5a6af7` |
| 7 | `c3891205ae7eaaa4be78267d6f0e15245c16f55bec767fa96c1ffb5007771f72` | `44883795c9dbeb15059834fbd4e84d26d3d3d8a3cccd690a73e5cf9488f7bae4` |
| 42 | `8ff44bcb78e1a5c7518867f0ed7be6c184c7a4690799597a8c09384a65366472` | `df8ae0a8c1152f0b82b8f9ff6172e6b20af58cb3a2152600e479161196b60cca` |

The seed records were identical across two independent executions. Hashes are
regression conveniences; later RTL comparison remains byte-level.

## GFX-004 memory-feasibility milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| One 76800x8 framebuffer inferred as ECP5 block RAM | GFX-004 synthesis commit | `make synth-memory`; `reports/memory_spike/memory_spike_one_framebuffer_top.log` | 38 `DP16KD`; independent `clk_pix`/`clk_sys` synchronous ports; no placement or timing claim | SYNTHESISED |
| Z memory inferred as ECP5 block RAM | GFX-004 synthesis commit | `make synth-memory`; `reports/memory_spike/memory_spike_zbuffer_top.log` | 38 `DP16KD`; synchronous system read/write; no placement or timing claim | SYNTHESISED |
| 1024x32 FIFO memory inferred as ECP5 block RAM | GFX-004 synthesis commit | `make synth-memory`; `reports/memory_spike/memory_spike_fifo_top.log` | 2 `DP16KD`; representative memory only, not production FIFO behavior | SYNTHESISED |
| Combined memory spike retained all five memories | GFX-004 synthesis commit | `make synth-memory`; `reports/memory_spike/memory_spike_top.log` | 154 `DP16KD`, zero generic memories in final hierarchy, 0 Yosys check problems | SYNTHESISED |
| Reference regression remains passing | GFX-004 synthesis commit | `python3 -m unittest discover -s sw/reference -p 'test_*.py' -v` | 31 tests passed | REFERENCE-MODEL VERIFIED |
| LFE5U-85F capacity comparison | GFX-004 synthesis commit | [Lattice ECP5 family selection table](https://www.latticesemi.com/en/Products/FPGAandCPLD/ECP5.aspx) | 208 sysMEM blocks, 84K LUTs, 156 multipliers; comparison only, not integrated utilization | EXTERNAL SPECIFICATION |

The admitted parent resource record remains separate from GFX-004 synthesis:
`v1.0.1-dependency-ready`, commit
`ad35514c990f6e1c9eb9fa18aee9d906f9df7721`, top
`rtl_to_pixels_top_pipelined`, with supplied evidence of 2 `DP16KD`, 3
`MULT18X18D`, 775 `LUT4`, and 223 `TRELLIS_FF`.

GFX-004 does not claim full integrated utilization, placement, routing,
timing closure, formal proof, or hardware evidence.

## GFX-005 package/FIFO milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Frozen synthesizable package constants and protocol enums compile | GFX-005 commit | `make lint-fifo`; `make test-fifo`; `tb/tests/gfx_pkg_tb.sv` | Includes 320×240, 76800 pixels, 17-bit address, Q4/Q8/42-bit widths, 1024 depth, opcodes, responses, and errors | RTL SIMULATION VERIFIED |
| Production command FIFO behavior passes directed and randomized simulation | GFX-005 commit | `make test-fifo`; `tb/tests/cmd_fifo_tb.sv` | 11,677 cycles, seed `0x005005`, 6,999 accepted pushes and pops; exact 1024-word fill/drain and scoreboard ordering | RTL SIMULATION VERIFIED |
| Selected FIFO safety properties pass formal | GFX-005 commit | `make formal-fifo`; `formal/cmd_fifo.sby` | SBY 0.69, Z3, depth 12 bounded run, depth-4 structural harness; reset assumptions documented in harness | FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS |
| Gate transition recorded | GFX-005 commit | `docs/PROJECT_STATE.md`, `04_MASTER_CHECKLIST.md` | Gate 2 CLOSED; Gate 3 OPEN; later Gate-3 components remain open | LOCAL OBSERVATION |

GFX-005 does not claim command-decoder, clear, triangle, raster, renderer,
display, Sobel, P&R, timing, or hardware evidence. The formal harness uses
depth 4 to avoid expanding the production 1024×32 RAM into an intractable
symbolic register array; production capacity is separately linted and tested.

## GFX-006 command-decoder milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Frozen command packet collection and syntax validation pass | GFX-006 commit | `make lint-decoder`; `make test-decoder` | 80 self-checking checks; all fixed packet lengths, payload preservation, reserved/coordinate errors, stalls, reset, truncation, randomized malformed input, and resynchronization covered | RTL SIMULATION VERIFIED |
| Decoder formal properties pass | GFX-006 commit | `sby -f formal/cmd_decoder.sby` | SBY 0.69, Z3, BMC depth 25; packet atomicity, partial silence, reset discard, output stability, unknown-opcode one-word handling, bounded length, and output mutual exclusion | FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS |
| FIFO and reference regressions remain passing | GFX-006 commit | `make test-fifo`; `python3 -m unittest discover -s sw/reference -p 'test_*.py' -v` | Production FIFO unchanged; 31 Python tests passed | RTL SIMULATION VERIFIED / REFERENCE-MODEL VERIFIED |
| Gate-3 decoder scope recorded | GFX-006 commit | `docs/PROJECT_STATE.md`; `04_MASTER_CHECKLIST.md` | Decoder emits transactions/errors only; no command execution or later graphics engine is claimed | LOCAL OBSERVATION |

The decoder formal harness uses bounded BMC and does not claim whole command
protocol proof. Runtime state legality remains deferred to the controller or
integration layer, and decoder evidence does not imply command execution,
rendering, display, Sobel, P&R, timing, or hardware evidence.

## GFX-007 clear-engine milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Production-default clear stream is exact | GFX-007 commit | `make test-clear` | 76,800 colour writes and 76,800 Z writes per uninterrupted clear; address scoreboard found zero duplicates, skips, or out-of-range writes | RTL SIMULATION VERIFIED |
| Clear values and parallelism are correct | GFX-007 commit | `make test-clear` | Tested `0x00`, `0xFF`, `0xA5`, deterministic random byte, repeated clears, captured-input stability, and coincident address/write enables | RTL SIMULATION VERIFIED |
| Reset abort and restart behavior passes | GFX-007 commit | `make test-clear` | Beginning, middle, and final-address-near reset cases; no stale writes or done pulse; post-reset clear restarts at address 0 | RTL SIMULATION VERIFIED |
| Parameterized control/address properties pass | GFX-007 commit | `sby -f formal/clear_engine.sby` | 8-pixel/4-bit reduced instance, SBY 0.69, Z3, BMC depth 20; not a literal 76,800-cycle proof | FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS |

GFX-007 is standalone clear-stream evidence only. It does not claim command
controller integration, framebuffer ownership, synthesis, timing, P&R, or
hardware evidence.

## GFX-008-SPEC-FREEZE milestone

| Claim | Evidence | Conditions | Classification |
|---|---|---|---|
| D-029 freezes the synthesizable triangle-setup result representation | `docs/DECISIONS.md`, `docs/MICROARCHITECTURE.md`, `docs/FIXED_POINT.md` | Four classifications, canonical non-raster bbox/initial edges, universally valid fields, walker admission, and coordinate-error ownership are explicit | SPECIFIED |
| Python empty-bbox semantics remain independent | `docs/FIXED_POINT.md` | Python `None` maps to RTL `TRI_SETUP_EMPTY` only in the verification adapter; reference mathematics is unchanged | SPECIFIED |

This D-029 milestone contains no RTL or functional verification evidence. The
subsequent GFX-008 triangle-setup implementation is recorded below.

## GFX-008 triangle-setup milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Triangle setup matches the independent reference adapter | `1d1ae57fbe7a27ab5862e52f72c7d03f1ddb7aca` | `make test-triangle-setup` | 160 legal vectors; 80 RASTER, 2 EMPTY, 1 DEGENERATE, 77 BACKFACE; 5,474 fields compared; zero mismatches | RTL-SIMULATED |
| Setup arithmetic and payload compile/lint cleanly | `1d1ae57fbe7a27ab5862e52f72c7d03f1ddb7aca` | `make lint-triangle-setup` | Verilator 5.053 lint passed; D-029 packed payload and explicit signed widths | RTL-SIMULATED |
| Triangle-setup RTL passes Yosys component elaboration/check sanity | `1d1ae57fbe7a27ab5862e52f72c7d03f1ddb7aca` | qualified Yosys `read_verilog/hierarchy/proc/opt/check` | Component elaboration/check only; zero reported problems; no mapped resource result, ECP5 implementation result, P&R, or timing implication | LOCAL OBSERVATION |
| Preserved regressions remain passing | `1d1ae57fbe7a27ab5862e52f72c7d03f1ddb7aca` | `make test-clear`; `make test-decoder`; `make test-fifo`; Python unittest discovery | Clear, decoder, FIFO, and 31 Python reference tests passed | RTL-SIMULATED / REFERENCE-MODEL VERIFIED |

GFX-008 does not claim raster coverage, attribute stepping, fragment/Z,
framebuffer, controller, display, Sobel, timing, P&R, or hardware evidence.

## GFX-009-SPEC-FREEZE milestone

| Claim | Evidence | Conditions | Classification |
|---|---|---|---|
| D-030 freezes the coverage-only walker contract | `docs/DECISIONS.md`, `docs/MICROARCHITECTURE.md` | RASTER-only input, covered-output handshake, candidate retirement, row-major advancement, completion, reset, and GFX-009/GFX-010 boundary are explicit | SPECIFIED |
| GFX-009 verification and formal plan is recorded | `docs/VERIFICATION_PLAN.md` | Reference sequence comparison, stall/reset/completion cases, and future formal properties are planned only | SPECIFIED |

This milestone contains no raster-walker RTL or functional verification evidence.

## GFX-009 raster-walker milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Coverage sequence matches the independent Python oracle | `5e7d116e18cc6bd21ec82e09a88509b84ee0ad9a` | `make test-raster-walk` | 48 RASTER vectors, geometry seed `0x9009`, 39,207 candidates, 11,801 covered transfers, 3 zero-covered cases, maximum covered output 1,104, zero mismatches | RTL-SIMULATED |
| Backpressure, final-covered stalls, and reset abort are verified | `5e7d116e18cc6bd21ec82e09a88509b84ee0ad9a` | `tb/tests/raster_walk_tb.sv` | Deterministic ready seeds `1`, `7`, `19`; stalled payload stability and first/middle/row-boundary/final/stalled reset abort checks passed | RTL-SIMULATED |
| Shared-edge and subpixel/boundary coverage remains exact | `5e7d116e18cc6bd21ec82e09a88509b84ee0ad9a` | focused vector suite and Python oracle | Rectangle triangles produced 66 and 78 pixels; overlap 0, missing rectangle pixels 0; thin, tiny, left/top/right/bottom cases included | RTL-SIMULATED |
| GFX-009 formal properties | — | not run | No formal raster-walker proof is claimed | NOT RUN |

GFX-009 does not claim attribute stepping, fragment/Z, framebuffer,
controller, complete renderer, synthesis, P&R, timing, throughput, or hardware
evidence.

## GFX-010-SPEC-FREEZE milestone

| Claim | Evidence | Conditions | Classification |
|---|---|---|---|
| D-031 freezes signed42 raw attribute stepping and output | `docs/DECISIONS.md`, `docs/MICROARCHITECTURE.md`, `docs/FIXED_POINT.md` | Signed32 setup fields are sign-extended to signed42; raw R/G/B/Z output widths, initialization, X/Y stepping, stall, reset, and no-truncation rules are explicit | SPECIFIED |
| GFX-010 verification and formal plan is recorded | `docs/VERIFICATION_PLAN.md` | Direct mathematical comparison and future formal properties are planned only | SPECIFIED |

This milestone contains no attribute RTL or functional verification evidence.

## GFX-010 attribute-stepping milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Raw signed42 R/G/B/Z values match the mathematical oracle | `d7b6f60b7bcf4a10da0c23d39ba202b9d43a3e99` | `make test-raster-walk` | 48 RASTER vectors, geometry seed `0x9009`, 47,716 accepted raw fields, coordinate/R/G/B/Z mismatches all zero | RTL-SIMULATED |
| Signed42 expansion, stalls, reset, row transitions, and shared-edge association pass | `d7b6f60b7bcf4a10da0c23d39ba202b9d43a3e99` | `tb/tests/raster_walk_tb.sv` | Signed extrema and width-expansion cases, ready seeds `1/7/19`, reset cases, and shared-edge raw planes passed | RTL-SIMULATED |
| Gate 3 primitive requirements are evidenced | `d7b6f60b7bcf4a10da0c23d39ba202b9d43a3e99` | Master Plan Gate 3 review and `04_MASTER_CHECKLIST.md` | Triangle setup, coverage, and attribute stepping verified; no Gate-4 claim | LOCAL OBSERVATION |
| GFX-010 formal properties | — | not run | No attribute formal proof is claimed | NOT RUN |

GFX-010 does not claim quantization, RGB332, framebuffer address, Z stage,
complete renderer, synthesis, P&R, timing, or hardware evidence.

## GFX-011-SPEC-FREEZE milestone

| Claim | Evidence | Conditions | Classification |
|---|---|---|---|
| D-032 freezes the fragment/Z contract | `docs/DECISIONS.md`, `docs/MICROARCHITECTURE.md`, `docs/FIXED_POINT.md` | Fixed F0–F3 timing, signed42 Q8 conversion, RGB332/Z clamp, unsigned17 address, synchronous Z timing, strict depth, pass/fail writes, drain, reset, and hazard rule are explicit | SPECIFIED |
| GFX-011 verification and formal plan is recorded | `docs/VERIFICATION_PLAN.md` | Quantization, alignment, depth, write, drain, hazard, and reset cases are planned only | SPECIFIED |

This milestone contains no fragment/Z RTL or functional verification evidence.

## GFX-011 fragment/Z milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Fragment/Z production RTL exists | `338d6c3bf7fb0ccda3d7062d31ae0310a587fe1a` | `rtl/fragment_z.sv` | Standalone fixed-latency F0–F3 stage; no physical memory/controller integration | LOCAL OBSERVATION |
| Fragment quantization, RGB332 packing, and address calculation match the independent oracle | `2181ef8c5c30a2898efd4c3632a2ce8cc224bbc1` | `make test-fragment-z` | Signed arithmetic-shift/clamp boundaries, RGB332 colours, signed42 expansion, and address extrema passed | RTL-SIMULATED |
| Synchronous Z alignment and strict depth writes are verified | `2181ef8c5c30a2898efd4c3632a2ce8cc224bbc1` | `make test-fragment-z` | Genuine one-cycle 76,800-byte Z model; 61 accepted, 61 reads, 60 decisions with one reset abort, 28 passes, 32 fails, 28 coincident writes, zero mismatches/hazards/stale writes | RTL-SIMULATED |
| GFX-011 formal properties | — | not run | No fragment/Z formal proof is claimed | NOT RUN |

GFX-011 does not claim complete renderer integration, physical memory wrappers,
synthesis, P&R, timing, throughput, or hardware evidence.

## GFX-012-SPEC-FREEZE milestone

| Claim | Evidence | Conditions | Classification |
|---|---|---|---|
| D-033 freezes the baseline renderer integration boundary | `docs/DECISIONS.md`, `docs/MICROARCHITECTURE.md` | Decoded-command boundary, NOP/BEGIN_FRAME/DRAW subset, local execution FSM, setup-class handling, TRI_DRAIN, and no command-parser duplication are explicit | SPECIFIED |
| D-033 freezes production memory-wrapper contracts and ownership | `docs/MICROARCHITECTURE.md` | Original framebuffer/Z wrapper interfaces, unreset RAM arrays, mutually exclusive clear/fragment ownership, and D-032 hazard preservation are explicit; no RTL wrappers are implemented by this task | SPECIFIED |
| D-033 freezes quiescent-frame verification | `docs/VERIFICATION_PLAN.md`, `docs/MICROARCHITECTURE.md` | Verification-local `renderer_quiescent`, full 76800-byte colour/Z comparison, directed/random frame requirements, and future formal properties are defined; no GFX-012 simulation or formal result is claimed | SPECIFIED |

This milestone changes documentation only. GFX-012 implementation, complete
renderer integration, physical memory-wrapper verification, synthesis, P&R,
timing, and hardware evidence remain outstanding. GFX-013 counters and
GFX-014 framebuffer readback remain deferred.

## GFX-012 — baseline renderer integration milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Baseline renderer RTL and production memory wrappers exist | `e4aac734d42dc2966c526125290cb0351192ec26` | `rtl/renderer_core.sv`, `rtl/framebuffer_dp.sv`, `rtl/zbuffer.sv` | Reuses the verified GFX-007 through GFX-011 primitives; decoded-command renderer supports NOP/BEGIN_FRAME/DRAW only | LOCAL OBSERVATION |
| Full framebuffer and Z results match the independent renderer | `e4aac734d42dc2966c526125290cb0351192ec26` | `make test-renderer` | 9 directed/deterministic frames; 691,200 colour bytes and 691,200 Z bytes compared; zero mismatches in both memories | RTL SIMULATION VERIFIED |
| Memory wrappers, reset recovery, and ownership/drain behavior pass | `e4aac734d42dc2966c526125290cb0351192ec26` | `make test-memory-wrappers`, `make test-renderer-reset` | Synchronous wrapper timing, reset in active phases, full clear counts, TRI_DRAIN, ownership, and same-address hazard monitors pass with zero violations | RTL SIMULATION VERIFIED |
| Raw command decoder smoke reaches the same renderer result | `e4aac734d42dc2966c526125290cb0351192ec26` | `make test-renderer-decoder` | Existing `cmd_decoder` composed ahead of the renderer; no decoder reimplementation | RTL SIMULATION VERIFIED |
| GFX-012 formal properties | — | not run | No GFX-012 formal claim; synthesis/P&R/timing/hardware are also not claimed | NOT RUN |

GFX-012 does not claim presentation, FRAME_DONE, triple-buffer role rotation,
display, counters, readback, Sobel, UART, synthesis, P&R, timing, or hardware
evidence. The independent Python renderer remains REFERENCE-MODEL VERIFIED.

## GFX-005-FORMAL-ORDERING corrective milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Tracked-token ordering passes | GFX-005-FORMAL-ORDERING commit | `sby -f formal/cmd_fifo.sby` | Scalar ghost queue compares every legal dequeue with the oldest accepted token; depth-4 DUT, bounded depth 12 | FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS |
| Two-token relative ordering is covered by a stronger invariant | GFX-005-FORMAL-ORDERING commit | same ghost-queue head property | Any later accepted token cannot transfer before all earlier ghost tokens; data values need not be globally unique | FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS |
| Accepted-minus-consumed conservation passes | GFX-005-FORMAL-ORDERING commit | same SBY run | Ghost count equals DUT level throughout the bounded formal epoch | FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS |
| Production FIFO regression remains passing | GFX-005-FORMAL-ORDERING commit | `make test-fifo` | Default 1024×32 FIFO; 11,677 cycles, seed `0x005005`, 6,999 pushes and pops | RTL SIMULATION VERIFIED |
| Full Python reference regression remains passing | GFX-005-FORMAL-ORDERING commit | `python3 -m unittest discover -s sw/reference -p 'test_*.py' -v` | 31 tests passed | REFERENCE-MODEL VERIFIED |

The corrective formal run is bounded rather than a literal 1024-entry RAM
proof. Earlier GFX-005 safety properties were proven with depth-25
k-induction; this milestone adds explicit bounded ordering/conservation
evidence without changing production RTL.
