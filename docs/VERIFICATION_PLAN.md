# Verification plan

This is planned coverage, not executed evidence. Every later claim must record
the command, result, conditions, and evidence path.

| Contract area | Planned verification |
|---|---|
| Q4 quantization, signed Q8 rounding, signed32/signed42 ranges | Python helper tests, extrema tests, negative tie cases, and fixed-point range review |
| Edge equation, AREA, winding, top-left rule | Independent edge tests, shared-edge rectangle, reversed winding, degenerate and backface tests |
| Exact bbox and empty interval | Directed vertices on/off sample centres, clipped/extreme coordinates, AREA>0 empty-bbox case |
| Command packets and atomicity | Encoder/parser unit tests, truncation/reset tests, reserved-field and unknown-opcode tests |
| Command legality and errors | State-machine directed tests, sticky-error tests, fatal recovery tests, response scoreboard |
| FIFO and response stability | Random valid/ready gaps, backpressure tests, token/order scoreboard, selected formal FIFO properties |
| Colour/depth interpolation | Reference-model comparison, quantization tests, equal-depth and draw-order tests |
| F0–F3 Z pipeline | Focused latency/hazard tests, write implication properties, inter-triangle drain tests |
| Framebuffer/Z addresses and roles | Address-bound checks, role-uniqueness simulation/formal, reset and role-rotation sequences |
| Reset | Per-domain reset matrix with asynchronous assertion and synchronous release assumptions |
| Presentation CDC | Random clock phase simulation and selected formal mailbox properties; boundary-only FRONT changes |
| 2× display and RAM latency | Deterministic scanout pattern, exact source-pixel mapping, delayed control alignment test |
| Counters | Reference scoreboard proving counters do not alter output; reset/lifetime/per-frame tests |
| READ_FRONT | Exact 19206-word framing, packing, snapshot/rotation exclusion, checksum calculation |
| Parent dependency boundary | Verify exact tag/commit/top, run documented parent regression before import, preserve evidence separately |
| Sobel reader/writer | Ready/valid stall tests, two-entry read accounting, exact 76800 counts, SOF/EOL checks |
| W+1/final drain/APB | Accepted-stream index comparison, final-EOL/drain test, APB-before-SOF and shadow timing tests |
| Memory feasibility | GFX-004 synthesis spike plus separate admitted-parent resource evidence and combined target budget |
| Third-party boundary | Manifest review for every reused file; no copied core graphics implementation |
| GFX-009 coverage-only walker | Exact accepted covered-coordinate sequence versus `triangle_coverage()`/`iter_bbox_pixels()`, exact candidate count, shared-edge union/no-overlap, flat-top/flat-bottom, thin, tiny/subpixel, screen boundaries, zero-covered RASTER, deterministic random RASTER triangles, randomized output backpressure, final-covered-pixel stall, reset at first/middle/final candidate, no output outside bbox, and exact completion timing |
| GFX-010 attribute stepping | Direct mathematical comparison of signed42 raw R/G/B/Z for every accepted covered coordinate, including zero/positive/negative X/Y gradients, signed starts and extrema, long rows, row transitions, one-pixel and zero-covered cases, mixed coverage, output stalls/final stalls, reset/restart, deterministic randomized planes, and continued GFX-009 coordinate-sequence equality |
| GFX-011 fragment/Z stage | Arithmetic signed42 Q8 shift and clamp boundaries, exact RGB332 packing, unsigned17 address extrema/range, one-cycle synchronous Z-read alignment, strict-less-than and equal-depth rejection, coincident pass writes, fail no-write, valid gaps, back-to-back fragments, pipeline drain, forbidden equal-address Z read/write, and reset flushing |
| GFX-012 baseline renderer integration | Decoded NOP/BEGIN_FRAME/DRAW execution, clear/setup/walk/drain orchestration, production framebuffer/Z wrappers, renderer quiescence, full 76800-byte colour/Z comparison, depth/order/rejection cases, reset recovery, deterministic random frames, and raw decoder smoke composition |

## Verification sequence

1. Freeze and review this contract set.
2. Build the independent fixed-point and raster primitives.
3. Build the reference framebuffer/Z renderer and deterministic random frames.
4. Run the memory feasibility spike before deep raster RTL.
5. Verify primitive RTL against the independent model, then the complete
   colour/Z path.
6. Verify display/presentation and CDC independently.
7. Import only the admitted parent dependency and verify the Sobel bridge.
8. Run deep regression and selected formal properties.

The monitor is not the correctness oracle. The primary functional comparison is
the same quantized command stream rendered by an independent model versus the
RTL framebuffer/Z result. Formal results must state assumptions and vacuity or
coverage limitations. No simulation, formal, synthesis, timing, or hardware
result is claimed by this plan.

## GFX-009 formal plan

Future focused formal checks shall include: x/y remain within the accepted bbox
while busy; traversal cannot step beyond xmax/ymax; covered output equals the
current candidate; output payload and walker state remain stable while a covered
output is stalled; row transitions return x to xmin; `walk_complete` occurs only
after final-candidate retirement; reset-abort cannot produce completion; and a
finite non-empty bbox eventually terminates under an assumption that
`covered_ready` is eventually asserted. These are planned properties only and
are not claimed as proved by this specification task.

## GFX-010 formal plan

Future focused formal checks shall include: raw output stability under stall;
row/current attribute stability on a covered stall; initialization equal to
sign-extended starts; horizontal advance equal to prior current plus
sign-extended dX; row advance equal to prior row plus sign-extended dY; current
equal to the updated row after row transition; no X-gradient application at a
row boundary; and reset suppression of stale raw attribute output. These are
planned properties only.

## GFX-011 verification plan

Focused GFX-011 verification shall compare every observable result against the
mathematical reference semantics. Directed quantization cases shall include
raw values around `-257,-256,-255,-1,0,1,255,256,257`, the Z boundaries
`254*256`, `255*256`, and `256*256`, plus large signed42 positive and negative
values. RGB tests shall cover black, white, primary colours, mixed channels,
and clamp underflow/overflow with exact RGB332 bit checks. Address tests shall
cover `(0,0)->0`, `(319,0)->319`, `(0,239)->76480`, `(319,239)->76799`, and
deterministic legal random coordinates.

The synchronous-memory model shall verify the registered F0/F1/F2/F3 latency
and old-Z association for single fragments, back-to-back fragments, arbitrary
valid gaps, alternating pass/fail sequences, and distinct metadata every
cycle. Depth tests shall include near/far ordering, strict equal-depth reject,
Z clamp before comparison, coincident colour/Z pass writes, and no-write fail
cases. After `pipeline_empty`, sequential same-address tests shall cover near
then far, far then near, and repeated equal depth without creating a
same-address read/write hazard.

The reset matrix shall cover idle, each in-flight stage, multiple in-flight
fragments, and post-reset restart; it shall require no stale write and
`pipeline_empty=1`. Verification shall also check the forbidden equal-address
Z read/write condition and the inter-triangle drain boundary.

Future focused formal properties shall include address `<76800`, coincident
write enables and addresses, Z write data `0..254`, fail/equal-depth no-write,
pipeline-empty correspondence, reset clearing all valid state, suppression of
pre-reset writes, and no equal-address Z read/write under the documented
integration assumption. These are planned properties only and are not claimed
as proved by this specification task.

## GFX-012 verification plan

Focused GFX-012 verification shall drive already decoded legal `NOP`,
`BEGIN_FRAME`, and `DRAW_TRIANGLE` transactions through the local renderer FSM.
It shall verify clear completion before the first DRAW, exact setup-class
handling, direct walker-to-Fragment/Z ready/valid composition, and the
`TRI_WALK -> TRI_DRAIN -> FRAME_ACTIVE` barrier. `PRESENT` and display
completion are not part of this task.

The framebuffer and Z wrappers shall be tested independently for their
specified synchronous read/write timing, including pixel-domain framebuffer
read timing where practical, and without assuming reset clears their arrays.
Renderer tests shall inspect memories only after the verification-local
`renderer_quiescent` condition. Each frame must compare all 76,800 RGB332
bytes and all 76,800 Z bytes against the independent Python renderer; checksums
are supplemental and zero mismatches are required.

Directed frames shall include clear-only colours `0x00`, `0xFF`, and `0xA5`,
ordinary, flat-top, flat-bottom, thin, tiny/subpixel, boundary, shared-edge,
non-overlapping, far-then-near, near-then-far, equal-depth, reversed-order,
degenerate, backface, positive-area EMPTY, mixed accepted/rejected, and
zero-covered RASTER cases. Sequential triangles shall demonstrate the drain
barrier. Reset shall be exercised in `IDLE`, `CLEAR`, `TRI_SETUP`, `TRI_WALK`,
and `TRI_DRAIN`, followed by a fresh BEGIN_FRAME recovery.

Deterministic random frames shall contain 1..48 legal triangles with valid,
degenerate, reversed, empty, boundary, and signed32 attribute-plane cases,
plus random clear colours. The report shall include seed, triangle count,
expected/actual framebuffer and Z checksums, colour/Z mismatch counts, and the
first mismatch coordinate/value when nonzero. A raw command smoke test may feed
the existing decoder's BEGIN_FRAME/DRAW packets into the same renderer path;
it does not replace the direct renderer comparison.

Planned formal properties shall cover one active local phase, mutually
exclusive clear/fragment memory ownership, RASTER-only walker admission,
TRI_DRAIN waiting for `pipeline_empty`, renderer-quiescent implies no pending
write-producing work, address bounds, no writes before clear completion, and
reset clearing active control state. These are planned properties only; this
specification task claims no GFX-012 formal execution.

## GFX-013 performance-counter verification plan

Focused counter verification shall use an independent event scoreboard rather
than DUT counter values. It shall verify all counters start at zero after
global reset; per-frame counters clear on each accepted BEGIN_FRAME; lifetime
`frames_completed` and `command_fifo_high_watermark` survive BEGIN_FRAME; and
reset during active work produces no stale event counts.

The scoreboard shall cover DRAW acceptance independent of classification,
exact RASTER/EMPTY/DEGENERATE/BACKFACE counts, candidate retirement including
uncovered candidates, covered transfers under stalls, completed Z pass/fail
decisions including equal-depth fails, uninterrupted `clear_cycles == 76800`,
exact TRI_SETUP and TRI_WALK/TRI_DRAIN cycle counts, synthetic presentation and
Sobel events, FIFO-level sequences with repeated/falling/full-depth peaks, and
modulo-2^32 wraparound using controlled preload or a reduced verification
model. Counter-bank integration shall rerun identical GFX-012 frame streams and
compare framebuffer/Z memories byte-for-byte to prove passive behavior.

Cross-counter checks at quiescence require:

```text
triangles_submitted == RASTER + EMPTY + DEGENERATE + BACKFACE
z_pass + z_fail == covered_fragments
triangle_setup_cycles <= render_cycles
```

The plan shall explicitly exercise `candidate_retired`,
`depth_result_valid/depth_pass`, reset priority over same-cycle BEGIN_FRAME
events, and future-event inputs without implementing presentation or Sobel.

Future formal properties include global-reset clearing, BEGIN_FRAME-only
per-frame reset, lifetime-counter persistence, event-implied increments,
candidate one-pulse accounting, mutually exclusive depth results,
nondecreasing high watermark except reset, high watermark dominance over the
sampled FIFO level, and passive integration with no renderer-control feedback.
These properties are planned only and are not claimed as proved.
