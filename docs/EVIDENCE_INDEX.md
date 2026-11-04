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

## GFX-013-SPEC-FREEZE — D-034 milestone

| Claim | Evidence | Conditions | Classification |
|---|---|---|---|
| D-034 freezes all fourteen unsigned32 modulo counters and W1–W14 order | `docs/DECISIONS.md`, `docs/MICROARCHITECTURE.md` | Exact software order is retained; no GET_COUNTERS serializer is added | SPECIFIED |
| D-034 freezes lifetime/per-frame reset domains and increment events | `docs/MICROARCHITECTURE.md`, `docs/VERIFICATION_PLAN.md` | BEGIN_FRAME priority, renderer/depth/candidate events, future presentation/Sobel inputs, and FIFO level sampling are explicit | SPECIFIED |
| D-034 freezes passive instrumentation and counter invariants | `docs/MICROARCHITECTURE.md`, `docs/VERIFICATION_PLAN.md` | Counter integration must not alter GFX-012 behavior; future formal properties are planned only | SPECIFIED |

This milestone changes documentation only. The implementation evidence is
recorded below; no GET_COUNTERS response serializer, formal result, synthesis,
timing, or hardware evidence is claimed.

## GFX-013 — performance counters milestone

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Reusable D-034 performance counter bank exists | `7dca4584635ff4aa5c8f0b0f11ced5f4d47bd079` | `rtl/perf_counters.sv`, `rtl/gfx_pkg.sv` | Fourteen unsigned32 modulo counters, exact W1–W14 order, lifetime/per-frame reset split, future event inputs, and FIFO high-watermark sampling | LOCAL OBSERVATION |
| Standalone counter semantics pass | `7dca4584635ff4aa5c8f0b0f11ced5f4d47bd079` | `make lint-perf-counters`; `make test-perf-counters` | Reset, BEGIN_FRAME priority, lifetime persistence, synthetic present/Sobel events, FIFO peak 1024, and controlled FFFFFFFE→FFFFFFFF→00000000 wraparound | RTL SIMULATION VERIFIED |
| Passive walker/depth instrumentation passes | `7dca4584635ff4aa5c8f0b0f11ced5f4d47bd079` | `make test-raster-walk`; `make test-fragment-z` | Candidate retirement count matches bbox candidates; depth-result events match completed strict pass/fail decisions; existing coordinate/raw/depth/write checks remain zero-mismatch | RTL SIMULATION VERIFIED |
| Integrated renderer counter scoreboard passes | `7dca4584635ff4aa5c8f0b0f11ced5f4d47bd079` | `make test-renderer-counters` | 5 submitted draws, 9 candidates, 2 covered fragments, 1 Z pass, 1 equal-depth Z fail, 76,800 clear cycles; setup/render cycle relation and watermark 1024 pass | RTL SIMULATION VERIFIED |
| GFX-012 output invariance is preserved | `7dca4584635ff4aa5c8f0b0f11ced5f4d47bd079` | `make test-renderer`; `make test-renderer-reset`; `make test-renderer-decoder` | Existing 9-frame full framebuffer/Z comparisons, reset recovery, and raw decoder smoke remain passing; no renderer control/timing change observed | RTL SIMULATION VERIFIED |
| GFX-013 formal properties | — | not run | No formal proof is claimed | NOT RUN |

GFX-013 does not implement GET_COUNTERS serialization, PRESENT, FRAME_DONE,
role rotation, display, Sobel, READ_FRONT, UART, optimization, synthesis,
P&R, timing, or hardware behavior. Gate 4 remains OPEN; GFX-014 readback is
the next task.

## GFX-014-SPEC-FREEZE — D-035 milestone

| Claim | Evidence | Conditions | Classification |
|---|---|---|---|
| D-035 freezes the standalone READ_FRONT streamer boundary | `docs/DECISIONS.md`, `docs/MICROARCHITECTURE.md` | Legal-start responsibility, captured tag/FRONT ID, role lock, synchronous reads, source stability precondition, and later Gate-5 integration ownership are explicit | SPECIFIED |
| D-035 freezes framing, packing, checksum, stalls, completion, and reset | `docs/MICROARCHITECTURE.md`, `docs/VERIFICATION_PLAN.md`, `docs/COMMAND_PROTOCOL.md` | 19,206 words; 76,800 ordered pixel reads; four-byte little-endian packing; modulo-2^32 data-word checksum; accepted final checksum completion; abort/reset behavior | SPECIFIED |
| GFX-014 verification and formal plan is recorded | `docs/VERIFICATION_PLAN.md` | Synchronous source model, full byte reconstruction, three-buffer snapshot tests, response stalls, reset matrix, production wrapper/rendered-frame compositions, and future formal properties are planned only | SPECIFIED |

At the time of the GFX-014 specification freeze, implementation and
verification had not started. The later implementation and acceptance evidence
is recorded in the following GFX-014 section. D-035 remains classified
`SPECIFIED`; implementation evidence is classified separately.

## GFX-014 — framebuffer readback implementation

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Readback response framing, synchronous reads, packing, checksum, and completion pass | `01e0c728df3fc25ca20aa016925533b22156462c` | `make lint-readback`; `make test-readback` | 17 complete transfers; each emitted 19,206 accepted words and made 76,800 ordered requests (0..76799); 11 reset-abort points each followed by a successful full transfer; BEGIN/data/END word checks, response stability, and byte/checksum comparisons had zero mismatches | RTL SIMULATION VERIFIED |
| Full-frame patterns and captured three-buffer selection pass | `01e0c728df3fc25ca20aa016925533b22156462c` | `tb/tests/readback_engine_tb.sv` | All-zero, all-FF, address-derived, alternating, deterministic pseudorandom, and GFX-012 reference-rendered images; IDs 0/1/2; live tag/ID changed after start; deterministic ready seeds and forced stalls through BEGIN, first/middle/final data, and END | RTL SIMULATION VERIFIED |
| Production framebuffer synchronous-read composition passes | `01e0c728df3fc25ca20aa016925533b22156462c` | `make test-readback-framebuffer` | Actual `framebuffer_dp.sys_rdata` registered system read port; 76,800 source bytes reconstructed, zero mismatches; no memory-array reset added | RTL SIMULATION VERIFIED |
| Renderer-produced framebuffer readback passes | `01e0c728df3fc25ca20aa016925533b22156462c` | `make test-renderer` | GFX-012 rendered frame 4; 76,800 bytes; zero byte/word mismatches; checksum `c581ecbf`; this is not FRONT-role or presentation evidence | RTL SIMULATION VERIFIED |
| Reset abort while data and final checksum responses are stalled | `378addfa050deb3a791addceab16b5bd36a201ae` | `make test-readback` | Reset asserted only after multiple held cycles at the first data response and final END checksum response; no stale response/completion, followed by full successful recovery | RTL SIMULATION VERIFIED |
| Gate-4 requirements are evidenced and Gate 4 closes | `df4a881a12a0769e043815ed7a8f4f1af7d8b96e` | Gate-4 regression and `04_MASTER_CHECKLIST.md` audit | Readback item now evidenced; GFX-011/012/013 evidence retained; every Gate-4 checkbox is supported; no Gate-5, synthesis, P&R, timing, display, or hardware result is claimed | LOCAL OBSERVATION |
| GFX-014 formal properties | — | not run | No formal proof is claimed | NOT RUN |

The implementation commit above contains RTL/tests/Makefile only. The
verification-only reset-stall strengthening is recorded at
`378addfa050deb3a791addceab16b5bd36a201ae`. Gate-4 state/checklist evidence is
recorded in the documentation commit; bookkeeping commits are intentionally
not used as self-referential functional-baseline SHAs.

## GATE5-D036-SPEC-FREEZE — Gate-5 display and presentation contract

| Claim | Evidence | Conditions | Classification |
|---|---|---|---|
| D-036 freezes the Gate-5 simulation timing and presentation contract | `docs/DECISIONS.md`, `docs/MICROARCHITECTURE.md` | 640×480p60; 25.2 MHz logical `clk_pix`; H 640/16/96/48, V 480/10/2/33; negative sync; safe switch at raster origin `(-160,-45)` in vertical blank; one-cycle scanout metadata alignment after timing outputs; exact 2× and RGB332 expansion | SPECIFIED |
| D-036 freezes NORMAL roles, CDC/reset, readback lock, and renderer memory boundary | `docs/MICROARCHITECTURE.md` | One-outstanding stable-payload toggle mailbox; FRONT/RENDER/SPARE initial 0/1/2; post-ACK rotation; common reset assertion and per-domain synchronized release; external renderer logical colour-write port routes only to RENDER; Z pipeline remains internal | SPECIFIED |
| Project F timing support selected for future reviewed reuse | Project F `projf-explore`, commit `dd212c2e5e0e0d8bdcf93ba077630dbfd49ae708`, `lib/display/display_480p.sv` | SHA-256 `729b2a634735651925e37b02e3e51db035d149d035340c1c237c87e27ad68e50`; MIT root LICENSE at same commit; generic timing RTL only; no file imported by this task | SPECIFIED |
| Gate-5 simulation verification and selected formal properties are planned | `docs/VERIFICATION_PLAN.md` | Timing/scanout, exact 2× all-source-pixel mapping, RAM latency, black-invalid, CDC/roles, readback lock, reset, multi-frame NORMAL, and selected safety properties; no run claimed | SPECIFIED |

At the D-036 specification-freeze milestone, only documentation changed; no
Gate-5 implementation evidence was added by that milestone. Board revision,
physical connector, oscillator, PLL,
serializer, pins, programmer, monitor, and cable remain later physical
implementation decisions. The pinned From RTL to Pixels dependency remains a
Gate-6 dependency, not a Gate-5 prerequisite.

## GFX-015 — standalone 640×480 scanout simulation

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| D-036 timing, sync and frame geometry pass simulation | `45ae6cfb0bffe3cace5908e1b1778bd8ca39bcd1` | `source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && iverilog -g2012 -s scanout_2x_tb -o /tmp/scanout_2x_tb rtl/gfx_pkg.sv third_party/projectf/lib/display/display_480p.sv rtl/framebuffer_dp.sv rtl/scanout_2x.sv tb/tests/scanout_2x_tb.sv && vvp /tmp/scanout_2x_tb` | One full 800×525 frame: 420,000 raster slots, 525 line starts, exact D-036 `(-160,-45)` frame boundary, porch and sync coordinate/polarity checks; no mismatch | RTL SIMULATION VERIFIED |
| Full 2× scanout, registered RAM alignment and RGB332 expansion pass | `45ae6cfb0bffe3cace5908e1b1778bd8ca39bcd1` | Same self-checking test using production `rtl/framebuffer_dp.sv` and `rtl/scanout_2x.sv` | 307,200 active display pixels checked in row-major order, 76,800 source addresses represented four times each, all 256 RGB332 byte values, zero pixel/address/timing mismatches | RTL SIMULATION VERIFIED |
| Invalid FRONT produces black without disturbing timing | `45ae6cfb0bffe3cace5908e1b1778bd8ca39bcd1` | Same full-frame test | Nonblack framebuffer while `front_valid=0`; all active outputs black and DE/sync geometry still correct | RTL SIMULATION VERIFIED |
| Selected Project F timing source has recorded provenance | `45ae6cfb0bffe3cace5908e1b1778bd8ca39bcd1` | `third_party/projectf/lib/display/display_480p.sv`, `third_party/projectf/LICENSE`, `THIRD_PARTY_NOTICES.md`, `docs/THIRD_PARTY_MANIFEST.md` | Exact pinned commit; source SHA-256 recorded; upstream source unmodified | SPECIFIED |

Simulation used Icarus Verilog 14.0 development build and Verilator 5.053
development build. Standalone lint command:
`source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && verilator --lint-only --language 1800-2012 --top-module scanout_2x third_party/projectf/lib/display/display_480p.sv rtl/scanout_2x.sv`
and the Icarus simulation command above both exited 0.
The test's deterministic pixel pattern covers all byte values. No presentation
CDC, role manager, renderer-to-three-buffer composition, synthesis, timing
closure, or physical display evidence is claimed.

The following existing regressions also passed in this campaign: memory
wrappers, renderer (9 frames), renderer reset, decoder composition, renderer
counters, readback/framebuffer, readback engine, Fragment/Z, raster walker,
triangle setup, clear, decoder, FIFO, performance counters, and all 31 Python
reference tests. Existing Icarus `sorry: constant selects in always_*` notices
from triangle-setup/decoder compilation remain simulator sensitivity-analysis
notices; no new warning was emitted by the focused scanout compile or lint.

## GFX-016/GFX-017 — NORMAL presentation and three-buffer integration

| Claim | Commit | Command/evidence | Conditions | Classification |
|---|---|---|---|---|
| Renderer colour-write extraction preserves GFX-012 output | `03bb43786012a99bc268d179ad49bc680d8356e8` | `make test-renderer`, `make test-renderer-reset`, `make test-renderer-decoder`, `make test-renderer-counters` | Nine complete renderer/reference frames, clear/reset checks, decoder smoke, and counter scoreboard pass after replacing the internal colour RAM with the documented logical write port | RTL SIMULATION VERIFIED |
| NORMAL presentation mailbox and ownership checks pass | RTL `03bb43786012a99bc268d179ad49bc680d8356e8`; focused test refinement `6386ea7d00e067fd4265377f16852e4cdab367a3` | `make lint-presentation`; `make test-presentation` | Three independent clock period/phase configurations; initial IDs 0/1/2; FRONT/RENDER alternate; SPARE stays 2; before/after-boundary requests; readback lock; pending and post-pixel-switch reset; pre-ACK roles stable; zero role/early-switch errors | RTL SIMULATION VERIFIED |
| Three-frame renderer/scanout composition matches reference | `03bb43786012a99bc268d179ad49bc680d8356e8` | `make test-graphics-core` | Three generated Python-reference command frames; each full 76,800-byte colour and Z surface compared; all 307,200 active pixels per presented frame checked; 3 FRAME_DONE events after role update; zero out-of-boundary switches | RTL SIMULATION VERIFIED |
| GFX-014 reads the selected physical FRONT through the three-memory bank | `03bb43786012a99bc268d179ad49bc680d8356e8` | `make test-graphics-core` | 19,206 response words, 76,800 sequential synchronous reads, response stalls, presentation attempt blocked under the active readback lock, all reconstructed bytes and response words match | RTL SIMULATION VERIFIED |
| NORMAL-only role clarification resolves the lower-level verification contradiction | `03bb43786012a99bc268d179ad49bc680d8356e8` | `docs/VERIFICATION_PLAN.md` reviewed against the Master Plan and D-036 | NORMAL swaps FRONT/RENDER and leaves SPARE unchanged; three-way rotation remains Gate-6 SOBEL behavior | SPECIFIED |

`make test-presentation` used Icarus Verilog 14.0 development build. Its
configurations were `clk_sys/clk_pix` half-periods and pixel start phases
`5/7/1 ns`, `4/9/3 ns`, and `7/5/2 ns`; these are functional asynchronous-clock
simulation cases, not physical metastability evidence. `make test-graphics-core`
used the same Icarus build, and `make lint-presentation` used Verilator 5.053
development build. Selected Gate-5 formal properties were NOT RUN. No
synthesis, P&R, timing, board, serializer, physical display, or Sobel result is
claimed. `FRAME_DONE` is exposed as a tagged local event; response serialization
and the complete host command controller remain later work.

The relevant existing regressions passed: `make lint-perf-counters`,
`make test-perf-counters`, `make test-renderer-counters`, `make lint-renderer`,
`make test-renderer`, `make test-renderer-reset`, `make test-renderer-decoder`,
`make test-memory-wrappers`, `make lint-readback`, `make test-readback`,
`make test-readback-framebuffer`, `make lint-fragment-z`, `make test-fragment-z`,
`make lint-raster-walk`, `make test-raster-walk`, `make lint-triangle-setup`,
`make test-triangle-setup`, `make lint-clear`, `make test-clear`,
`make lint-decoder`, `make test-decoder`, `make lint-fifo`, `make test-fifo`,
the GFX-015 full-raster scanout command above, and all 31 Python reference
tests. `make doctor`, `make bootstrap-smoke`, and `git diff --check` passed.
The first bootstrap-smoke attempt exposed that its HDL allowlist omitted the
already-approved GFX-015 scanout files; the allowlist was corrected for those
files and the new Gate-5 files, then bootstrap-smoke passed.

Gate 5 is CLOSED by the Master Plan criteria. Gate 6 has not started. The
NORMAL presentation tests intentionally do not require all three IDs to enter
every role: the frozen NORMAL operation leaves SPARE unchanged; Gate-6 SOBEL
presentation owns the three-way rotation.

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

## G6-DEPENDENCY-ADAPTERS — GFX-018/019/020

| Claim | Command/evidence | Conditions | Classification |
|---|---|---|---|
| Exact upstream revision is pinned and unchanged | `ip/rtl-to-pixels` submodule at tag `v1.0.1-dependency-ready`, commit `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`; tag object peeled to that SHA | Selected `rtl_to_pixels_top_pipelined`; local inspection confirms RGB24 ready/valid + SOF/EOL, edge-byte ready/valid + SOF/EOL, APB. Upstream is not modified or copied into project RTL. | SPECIFIED / LOCAL OBSERVATION |
| Upstream regression passes | In dependency: `make doctor`; `make lint`; `make test-unit`; `make test`; raw logs `results/raw/gfx018-parent-doctor.log`, `results/raw/gfx018-parent-lint.log`, `results/raw/gfx018-parent-test-unit.log`, `results/raw/gfx018-parent-test-integration.log` | All exit 0. `make test-unit`: 13 Python tests plus 104 Cocotb tests. `make test`: 156 Cocotb tests spanning both architectures at 3×3, 5×4, and 8×5. No failure or warning lines in regression logs. | RTL SIMULATION VERIFIED (upstream baseline only) |
| 320×240 parameter compatibility and W+1/reference behavior pass | `IMG_WIDTH=320 IMG_HEIGHT=240 make -f tb/tests/Makefile.rtl_to_pixels_top_pipelined_dimension_image`; `IMG_WIDTH=320 IMG_HEIGHT=240 make -f tb/tests/Makefile.rtl_to_pixels_top_pipelined_streaming`; saved XML: `results/raw/gfx018-parent-320x240-dimension.xml`, `results/raw/gfx018-parent-320x240-streaming.xml` | First run: 1 cocotb test, 3 full frames, each 76,800 input and output transfers, 0 reference mismatches. Streaming run: 5 tests; source-gap, random backpressure, combined gaps/stalls, SOF/EOL stability, and drain-backpressure; each frame exact 76,800 count, zero reference mismatches. W+1 alignment is checked through full reference output correspondence; final drain is held under backpressure. | RTL SIMULATION VERIFIED (upstream baseline only) |
| Reader handles synchronous RGB332 memory and stream stalls | `make lint-sobel-adapters`; `make test-sobel-adapters`; log `results/raw/gfx018-020-adapter-lint.log`, `results/raw/gfx018-020-adapters.log` | Reader capacity is two results including the in-flight synchronous read; addresses 0..76799 once; 76,800 stream transfers; RGB332 expansion, one SOF, 240 EOLs, output payload stability during 92,159 deterministic stall cycles, and active reset abort checked. | RTL SIMULATION VERIFIED |
| Writer conversion, row-major writes, metadata rejection and reset pass | Same adapter test | 76,800 accepted mock outputs and ordered writes; every destination byte compared to an independent deterministic transform and RGB332 conversion; malformed first-pixel SOF rejected before write; active reset abort tested. | RTL SIMULATION VERIFIED |
| APB master configures the admitted register contract before streaming | Same adapter test plus upstream APB register regression | CONTROL enable/bypass and THRESHOLD writes checked for bypass=1 and bypass=0; PREADY-low access remains stable; PSLVERR sets config error; reset clears control state. Upstream register tests cover reset defaults, register readback/status, shadow-to-active SOF semantics, W1C, invalid accesses, and frame count. | RTL SIMULATION VERIFIED |

The selected upstream top is parameterized at `IMG_WIDTH=320` and
`IMG_HEIGHT=240`; these parameters were explicitly passed to both dedicated
full-frame cocotb runs. Upstream tools were Verilator 5.052 and cocotb 2.1.0;
the project adapter test used Icarus Verilog from the local OSS CAD Suite and
Verilator 5.053 for lint. `make doctor` exited 0 while reporting optional
formal and ECP5 implementation tools missing; no formal/synthesis/P&R/timing
claim is made.

The parent `COPYRIGHT.md` states all rights reserved and supplies no general
reuse license. The project records a Git submodule pointer only and claims no
redistribution or downstream product-use rights. Explicit permission remains
required before those uses. No Sobel integration, W+1 bridge datapath, parent
frame completion wiring, SPARE routing, or three-role Sobel rotation is
implemented by GFX-018/019/020; those belong to GFX-021/022.

## G6-SOBEL-CLOSE — GFX-021/022

| Claim | Command/evidence | Conditions | Classification |
|---|---|---|---|
| Real parent Sobel datapath with adapter/controller integration | `SOBEL_PYTHON=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 make test-sobel-controller` | Pinned submodule SHA `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`; `rtl_to_pixels_top_pipelined`, 320×240. Five complete cases: solid black, edge pattern, gradient, deterministic random, renderer-produced scene. Threshold and bypass settings exercised. Each case had 76,800 synchronous source reads and 76,800 destination writes, all bytes matched the independent parent Python Sobel reference. | RTL SIMULATION VERIFIED |
| Full graphics-core NORMAL→SOBEL→SOBEL→NORMAL composition | `SOBEL_PYTHON=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 make test-sobel-integration` | First/final NORMAL frames each compare all 307,200 active scanout pixels. Both real pinned-parent Sobel runs report 76,800 reads, input transfers, output transfers, and SPARE writes; one SOF and 240 EOLs per direction; zero full-frame reference mismatches; and a complete 19,206-word GFX-014 readback with zero byte/word mismatch. Roles progress `0/1/2 → 1/0/2 → 2/1/0 → 0/2/1 → 2/0/1`; four tagged FRAME_DONE events; no out-of-boundary front switch. Active reset abort after 10 reads produces no stale completion. | RTL SIMULATION VERIFIED |
| NORMAL/SOBEL role mode transitions | `make test-sobel-modes`; `make test-presentation` | NORMAL→SOBEL→SOBEL→NORMAL, expected IDs checked after each transition, all IDs remain pairwise distinct, FRONT does not change before safe-boundary event/ACK, one tagged done per accepted request, and readback lock blocks presentation. This focused role test uses a synthetic safe-boundary event; it is not a multi-frame parent-Sobel composition. | RTL SIMULATION VERIFIED |
| Existing NORMAL rendering/display behavior retained | `make test-graphics-core` | Three complete reference-rendered frames; 76,800 colour and Z bytes matched per rendered frame; 307,200 active pixels matched per scanout frame; no out-of-boundary FRONT switch. | RTL SIMULATION VERIFIED |
| Adapter and prior renderer/readback/primitive regressions | Commands listed in G6-SOBEL-CLOSE campaign report | Adapter mock, renderer, counters, readback, memory wrappers, Fragment/Z, raster, setup, clear, decoder, FIFO, and 31 Python reference tests passed. | RTL SIMULATION VERIFIED / REFERENCE-MODEL VERIFIED |

The focused project simulations used Icarus Verilog from the local OSS CAD
Suite; lint used Verilator 5.053. Icarus emitted its known `constant selects
in always_*` sensitivity notices in triangle setup, the pinned Sobel sources,
and the framebuffer-bank mux. The first repeated-mode run exposed a testbench
race: `rb_rsp_ready` remained asserted between readback transactions. On the
next transaction the final checksum handshook before the checker sampled it,
leaving the checker waiting at response word 19205 while the engine was idle
(`rb_active=0`, `rb_rsp_valid=0`). The checker now holds ready low until it
observes each word and pulses ready for that single transfer. Production RTL
was unchanged. The corrected full mode sequence and all listed regressions
pass. `make doctor` and `make bootstrap-smoke` passed. Formal, synthesis,
P&R, timing, hardware, and physical-display results are not claimed.

The parent source remains an unchanged submodule at the pinned commit. Its
all-rights-reserved notice is preserved; this evidence makes no general
redistribution or downstream-use permission claim. Gate 5 and Gate 6 are
CLOSED based on the checked simulation requirements. The earlier stalled run
is retained as debugging history; the corrected regression now passes the
complete graphics-core mode sequence. Next task: G7-G8-SYSTEM-VERIFY —
GFX-023 through GFX-025.

## G7-G8-SYSTEM-VERIFY — GFX-023/024/025

See `results/processed/G7-G8-SYSTEM-VERIFY.md` for exact scope, runs,
assumptions and remaining gates.

| Claim | Command/evidence | Conditions | Classification |
|---|---|---|---|
| Public 32-bit command controller traverses four NORMAL/SOBEL presentations | `make test-command-system` | Real FIFO/decoder/graphics core, pinned parent, presentation and readback; four tagged completions; 307,200 readback bytes compared; final triangle image compared to independent Python output | RTL SIMULATION VERIFIED |
| Public response backpressure | `make test-command-system` | FRAME_DONE/ERROR every word, STATUS all 3 words, COUNTERS all 15 words, READ_FRONT selected header/data/trailer words; stable tuple and exact transfers | RTL SIMULATION VERIFIED |
| Public STATUS and COUNTERS | `make test-command-system` | Frozen STATUS flags/roles and independent W1–W14 event/cycle scoreboard at three snapshots; live FIFO high-water rises during one stalled snapshot | RTL SIMULATION VERIFIED |
| Fatal Sobel public recovery and reset matrix | `make test-command-system`, `make test-presentation` | Testbench-only injection at existing Sobel error boundary; tagged ERROR stalls, no writes/rotation, rearm and subsequent NORMAL; reset partial packet/clear/presentation/Sobel/readback and post-pixel-switch CDC case | RTL SIMULATION VERIFIED |
| UART word link and command-top composition | `make test-uart`, `make test-uart-system` | CPB=16 digital simulation; little-endian word order; NOP+GET_STATUS; framing/overrun block behavior | RTL SIMULATION VERIFIED |
| Python host encoding/response helpers | `make test-host` | Four stdlib tests; includes exact 76,800-byte READ_FRONT reconstruction/checksum | HOST SOFTWARE UNIT TESTED |
| Selected FIFO/role/raster/depth/Sobel formal checks | `make formal-gate8`; `make formal-decoder formal-clear` | Exact bounded, reduced and PDR scopes are recorded in processed report | FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS |
| Presentation CDC mailbox / roles | `make formal-gate8` | Separate symbolic `clk_sys`/`clk_pix` event traces, common async assertion, per-domain two-stage reset release; BMC safety depth 32, covers depth 48; digital model only | FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS |

Gate 7 and Gate 8 are CLOSED for their checked requirements and documented
formal scopes. Gate 9 remains open. No synthesis, P&R, timing, physical UART,
analog CDC/MTBF, or hardware evidence is claimed.

## GFX-026 — ECP5 synthesis and route baseline attempt

| Claim | Command/evidence | Result and limits | Classification |
|---|---|---|---|
| Complete ULX3S reference top elaborates and maps to ECP5 cells | `make synth-ecp5`; `reports/gfx026/yosys_synth_fifo_ebr.txt`; top `ulx3s_graphics_top` | Exit 0; `hierarchy -check`, `synth_ecp5`, `check -assert`; full graphics/UART/320×240 Sobel hierarchy. Corrected resources: 9,822 pre-pack LUT4, 6,011 FF, 156 DP16KD, 11 MULT18X18D, 3 EHXPLLL. Original baseline resource mapping remains in the original `yosys_synth.txt`. | SYNTHESISED |
| PLL settings and board top are accepted by tools | `rtl/board/ulx3s_graphics_top.sv`; GFX-026 report | Tool calculation/smoke accepted nominal 60 MHz sys, 25.2 MHz pixel and 126 MHz serializer from nominal 25 MHz. Board revision v2.x.x/v3.0.x is an assumption only. | SYNTHESIS/TOOL-MODEL OBSERVATION |
| Production FIFO RAM inference | `cmd_fifo_original_map.txt`; `cmd_fifo_ebr_standalone.txt`; full Yosys logs | Starting source is mem2reg in frontend (1,024 32-bit register words); corrected standalone production FIFO maps to 2 DP16KD and 64 TRELLIS_FF. FIFO behavior simulation and depth-4 BMC pass. | SYNTHESIS / RTL SIMULATION / FORMAL EVIDENCE |
| Placement and routed timing | `nextpnr_placement_fifo_ebr.txt`; `nextpnr_route_fifo_ebr.txt`; compressed detailed report JSON | Same target/constraints/seed. Placement `clk_sys` estimate 38.92 MHz; route completed with 39.1896 MHz against 60 MHz, ~−8.851 ns slack. Pixel, serializer and intermediate report targets pass. Detailed routed start/end path is in the processed GFX-026 report. | PLACED/ROUTED — TIMING FAILING |
| Full route and bitstream | `nextpnr_route_fifo_ebr.txt`; `ulx3s_graphics_fifo_ebr.config.gz` | Router1 completed all arcs; routed config retained. No bitstream generated because required `clk_sys` timing fails. | PLACED/ROUTED — TIMING FAILING |
| Gate-9 functional/formal regression | `reports/gfx026/functional_regression.log`; `make formal-gate8`; Python unittest | Relevant simulation batch exit 0; reference suite 31/31; selected prior formal suite exit 0, including two-clock presentation BMC depth 32 and cover depth 48. These do not establish physical timing or hardware. | RTL SIMULATION VERIFIED / FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS |

Full logs, exact tool versions, warnings, pin/clock assumptions and route-attempt details are in `reports/gfx026/RESULTS.md`. Gate 9 remains OPEN because routed `clk_sys` timing fails the 60 MHz target and compliant-clock throughput is not established. No Fmax, bitstream or physical operation is claimed.
