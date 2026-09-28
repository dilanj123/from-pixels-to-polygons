# Microarchitecture

This is the frozen source-level baseline. It specifies interfaces and ordering,
not implementation evidence.

## Control and command path

The canonical core interfaces are `cmd_valid/cmd_ready/cmd_data[31:0]` and
`rsp_valid/rsp_ready/rsp_data[31:0]`. A 1024×32 FIFO collects fixed packets.
The controller states are RESET, IDLE, CLEAR, FRAME_ACTIVE, TRI_SETUP,
TRI_WALK, TRI_DRAIN, POSTPROCESS, PRESENT_WAIT, READBACK, and ERROR_RECOVERY.
Only legal state/command combinations dispatch; packet collection is atomic.

## Triangle path

Host-provided Q4 vertices and signed32 Q8 attribute planes enter triangle setup.
Setup computes signed16 deltas, signed32 AREA/edge terms, top-left flags, exact
clamped pixel-centre bounds, and initial edge values. AREA rejection, empty-bbox
success, and counters are distinct results.

### Triangle-setup result contract (D-029)

The setup result has one mutually exclusive 2-bit classification:

```text
TRI_SETUP_RASTER      = 2'b00
TRI_SETUP_EMPTY       = 2'b01
TRI_SETUP_DEGENERATE  = 2'b10
TRI_SETUP_BACKFACE    = 2'b11
```

Classification is exhaustive for legal decoded coordinates and has this
priority: `AREA == 0` is DEGENERATE; `AREA < 0` is BACKFACE; `AREA > 0` with
an empty exact candidate bbox is EMPTY; otherwise it is RASTER. EMPTY is
accepted positive-area geometry with no integer pixel-centre candidate. Only
RASTER may enter the raster walker; EMPTY, DEGENERATE, and BACKFACE produce no
raster candidates.

The future synthesizable setup payload contains at least:

```text
classification [1:0], tag [15:0], AREA signed [31:0]
edge0/1/2 dx/dy signed [15:0]
top_left[2:0]
edge0/1/2 step_x/step_y signed [31:0]
xmin/xmax [8:0], ymin/ymax [7:0]
E0_init/E1_init/E2_init signed [31:0]
R/G/B/Z start, dX, and dY fields, all signed [31:0]
```

For RASTER, bbox fields are valid with `xmin<=xmax` and `ymin<=ymax`, and the
initial edges are evaluated at the centre of `(xmin,ymin)`. For EMPTY,
DEGENERATE, and BACKFACE, `xmin=xmax=ymin=ymax=0` and `E0_init=E1_init=E2_init=0`.
These zeros are canonicalized fields controlled by classification, not sentinels
and not a one-pixel bbox. AREA, all edge dx/dy, top-left flags, edge steps, tag,
and all attributes remain valid for every legal input/classification.

| Field group | RASTER | EMPTY | DEGENERATE | BACKFACE |
|---|---|---|---|---|
| classification | valid | valid | valid | valid |
| tag/attributes | valid | valid | valid | valid |
| AREA | valid | valid | valid | valid |
| dx/dy | valid | valid | valid | valid |
| top-left flags | valid | valid | valid | valid |
| X/Y edge steps | valid | valid | valid | valid |
| bbox fields | valid | canonical zero | canonical zero | canonical zero |
| initial E0/E1/E2 | valid | canonical zero | canonical zero | canonical zero |
| may enter raster walker | yes | no | no | no |

GFX-006 is the architectural command syntax/range validator and emits
`COORD_RANGE`. Triangle setup receives an already-valid decoded DRAW
transaction. It may defensively assert `X<=5120` and `Y<=3840`, but it does not
emit a second protocol error, own sticky command-error state, or add a fifth
classification. Illegal setup-interface coordinates violate the integration
precondition.

D-029 changes only this synthesizable output representation. It does not change
the Q4, pixel-centre, edge, winding, bbox, top-left, empty-bbox, or Python
reference mathematics.

### Coverage-only raster walker contract (D-030)

GFX-009 consumes one already-produced `triangle_setup_result_t` through
`walk_in_valid`, `walk_in_ready`, and `walk_in_payload`. Transfer occurs only
on `walk_in_valid && walk_in_ready`. The payload classification must be
`TRI_SETUP_RASTER`; EMPTY, DEGENERATE, and BACKFACE are handled before the
walker. A non-RASTER input is an integration-contract violation, not a runtime
protocol error. The implementation may assert this precondition in
simulation/formal.

The baseline accepts a new triangle only while idle: `walk_in_ready = !busy`.
There is no same-cycle final-candidate completion/refill in v1; a new triangle
may be accepted no earlier than the cycle after the prior walk completes.

Coverage output is only `covered_valid`, `covered_ready`, `covered_x[8:0]`, and
`covered_y[7:0]`. An implementation may also carry `covered_tag[15:0]`; if so,
the tag is part of the stalled payload and remains stable with x/y. No colour,
depth, address, or attribute fields are emitted by GFX-009.

For current E0/E1/E2 values, coverage uses:

```text
inside0 = (E0 > 0) || (E0 == 0 && top_left[0])
inside1 = (E1 > 0) || (E1 == 0 && top_left[1])
inside2 = (E2 > 0) || (E2 == 0 && top_left[2])
covered = inside0 && inside1 && inside2
```

On setup acceptance, capture bbox, top-left flags, edge steps, and initialize
`x=xmin`, `y=ymin`, `row_E*=E*_init`, and `current_E*=E*_init`. No multiply or
division is performed in the walker.

A candidate retires exactly once. An uncovered candidate retires immediately
when evaluated and does not require `covered_ready`. A covered candidate retires
only on `covered_valid && covered_ready`. While a covered candidate is stalled,
`covered_valid`, its complete payload, x/y, current E0/E1/E2, row E0/E1/E2,
busy, and completion state remain unchanged; no candidate is retired again.

After retiring a candidate with `x < xmax`, advance x and add each edge's
`step_x`. After retiring `x==xmax && y<ymax`, set `x=xmin`, increment y, add
each `step_y` to the row values, and use those updated row values as the next
current E values. Traversal is exactly row-major:

```text
for y in ymin..ymax:
    for x in xmin..xmax:
        consider (x,y)
```

The walker emits a one-cycle system-domain `walk_complete` pulse when the final
candidate `(xmax,ymax)` retires. An uncovered final candidate completes on its
evaluation/retirement cycle; a covered final candidate completes only with its
accepted output transfer. A stalled final covered candidate cannot complete.
`walk_complete` means candidate generation is finished, not downstream pipeline
drain. The baseline registered convention is: final retirement occurs at edge
N, and during cycle N+1 `walk_complete=1`, `busy=0`, and the walker is idle;
`walk_in_ready` may reassert in that cycle without creating same-cycle refill
ambiguity. The pulse is exactly one cycle.

A RASTER triangle may have zero covered pixels. The walker still visits every
bbox candidate, emits no covered token, and completes after the final candidate
retires. Reset aborts a walk, clears pending output and busy/completion state,
suppresses stale output/completion, and permits a later legal RASTER input to
restart at its own `(xmin,ymin)`.

GFX-009 owns only candidate traversal, edge stepping, top-left coverage,
covered x/y output, and traversal completion. GFX-010 adds raw R/G/B/Z current
and row accumulation for covered samples. GFX-009 does not quantize attributes,
compute addresses, read/compare/write Z or colour, or manage downstream drain.

The baseline walker advances one candidate per `clk_sys` target cycle using
signed32 edge additions. Future attribute accumulation and complete downstream
fragment draining remain outside this coverage-only block.

### Raw attribute stepping contract (D-031)

GFX-010 extends the GFX-009 covered stream with the same candidate transaction:

```text
covered_valid
covered_ready
covered_x       [8:0]
covered_y       [7:0]
covered_r_raw   signed [41:0]
covered_g_raw   signed [41:0]
covered_b_raw   signed [41:0]
covered_z_raw   signed [41:0]
```

The four raw fields are signed Q8 values for the candidate represented by x/y.
They are meaningful only when `covered_valid=1`. No tag is required by this
contract. No raw field may be truncated to signed32, quantized, clamped,
packed to RGB332, or converted to a framebuffer address in GFX-010.

For each attribute A in R/G/B/Z, the state is:

```text
row_A     signed [41:0]
current_A signed [41:0]
```

The setup fields `A_start`, `dA_dx`, and `dA_dy` remain signed32 Q8. Each is
sign-extended to signed42 before use. On RASTER setup acceptance:

```text
row_A = sign_extend_42(A_start)
current_A = row_A
```

The start value is exactly the value at candidate `(xmin,ymin)`; no additional
coordinate offset is applied. The independent mathematical oracle for any
candidate `(x,y)` is:

```text
A(x,y) = sign_extend_42(A_start)
       + (x-xmin) * sign_extend_42(dA_dx)
       + (y-ymin) * sign_extend_42(dA_dy)
```

After retiring a candidate with `x<xmax`, update each `current_A` by its
sign-extended `dA_dx`; `row_A` is unchanged. After retiring
`x==xmax && y<ymax`, compute `next_row_A = row_A + sign_extend_42(dA_dy)`,
assign `row_A=next_row_A`, and assign `current_A=next_row_A`. No X-gradient is
applied across a row boundary. These updates occur for uncovered retired
candidates and for covered candidates only when their output transfer occurs.

When a covered output is stalled, x/y, all edge state, all row/current R/G/B/Z
state, and all raw output fields remain stable until transfer. `covered_ready`
does not stall or alter attribute progression for an uncovered candidate. A
zero-covered RASTER triangle advances the attributes internally across every
candidate and emits no raw transactions. D-030 final-candidate, completion,
and reset-abort semantics remain unchanged; reset also discards all attribute
state and suppresses stale raw output.

The D-005 range derivation remains authoritative:

```text
|A| < (1 + 319 + 239) * 2^31 < 2^41
```

Signed42 is sufficient for legal v1 traversal. No saturation or expected
wraparound occurs in the attribute walker. GFX-011 consumes the raw transaction
and owns arithmetic shift-right by 8, RGB/Z clamping, RGB332 packing, address
calculation, Z processing, and framebuffer writes.

## Fragment/Z path (D-032)

GFX-011 consumes one GFX-010 covered transaction through:

```text
frag_valid
frag_ready
frag_x       [8:0]
frag_y       [7:0]
frag_r_raw   signed [41:0]
frag_g_raw   signed [41:0]
frag_b_raw   signed [41:0]
frag_z_raw   signed [41:0]
```

Transfers occur only on `frag_valid && frag_ready`. Coordinates are assumed to
be legal walker coordinates (`x=0..319`, `y=0..239`); coordinate errors and
`CMD_ERROR` remain outside this block. The fixed baseline has no downstream
ready/valid memory interface and accepts one fragment per `clk_sys` whenever
reset is inactive and the pipeline is operational (`frag_ready=1`). This is an
interface capability, not a routed system-throughput claim.

The four-stage organization is:

```text
F0: accept fragment; arithmetic-shift raw RGB/Z by 8; clamp; pack RGB332;
    calculate unsigned17 address; register fragment metadata.
F1: issue the synchronous Z read for the registered fragment.
F2: consume the following-cycle old-Z response aligned with that fragment;
    calculate strict-less-than pass/fail.
F3: on pass, emit coincident Z and colour writes; on fail, emit no writes.
```

The selected register-valid convention is explicit: a fragment accepted at
edge N is registered in F0; its address/read request is presented by F1 in the
following cycle; the external synchronous Z memory samples that request at the
next rising edge and presents old Z during the following cycle; F2 consumes
that response for the same fragment; and F3 emits the corresponding write
transaction after the F2 decision. Empty valid slots propagate through every
stage, so arbitrary input gaps do not realign metadata with a neighboring
Z response. Back-to-back valid fragments remain ordered, with one read request
per accepted fragment.

Raw conversion is arithmetic shift-right by eight with no re-rounding and no
signed32 truncation. RGB channels clamp to `0..255`, then pack as
`{R8[7:5], G8[7:5], B8[7:6]}`. Z clamps to `0..254`; `255` remains the clear/
infinity value and is never produced by fragment quantization. The address is
unsigned17 and uses `(y << 8) + (y << 6) + x`, with legal range `0..76799`.

The external memory interfaces are:

```text
z_rd_en                 z_rd_addr [16:0]   z_rd_data [7:0]
z_wr_en                 z_wr_addr [16:0]   z_wr_data [7:0]
fb_wr_en                fb_wr_addr[16:0]   fb_wr_data[7:0]
pipeline_empty
```

`z_rd_en` samples the address at the rising edge and the corresponding old
`z_rd_data` is available during the following cycle. Writes are accepted at the
rising edge whenever their enable is asserted; there are no ready signals.
On a depth pass, `z_wr_en=fb_wr_en=1`, both addresses equal the fragment
address, and the data are the clamped Z and RGB332 values. On a fail
(`new_z >= old_z`), both enables are zero; equal depth therefore fails and
causes no side effect.

Legal integration must satisfy:

```text
!(z_rd_en && z_wr_en && (z_rd_addr == z_wr_addr))
```

No vendor read-first/write-first/no-change behavior is assumed. The assertion
is justified by the one-use-per-pixel walk and the controller's requirement to
wait for the prior fragment pipeline to drain before the next triangle.

`pipeline_empty` is one exactly when all internal F0/F1/F2/F3 valid state is
empty. It is zero from the first accepted fragment until that fragment's
depth decision and any pass write have retired. A failed depth test still
occupies the pipeline until F2 retirement. `walk_complete` remains candidate
generation completion only; the controller sequence is `TRI_WALK -> TRI_DRAIN
-> FRAME_ACTIVE`, with TRI_DRAIN waiting for `pipeline_empty` before another
triangle enters raster generation.

Reset clears all internal valid state and produces `z_rd_en=0`, `z_wr_en=0`,
`fb_wr_en=0`, and `pipeline_empty=1`. A stale external Z response after reset
is ignored because its associated valid state has been discarded. RAM arrays
are not reset. GFX-011 does not own clearing, triangle setup, traversal,
physical memory arrays, controller legality, counters, readback, display, or
Sobel integration; those boundaries belong to GFX-012 and later work.

## D-033 — Baseline renderer integration, production memory wrappers and quiescent-frame verification boundary

GFX-012 composes the already verified command decoder output, clear engine,
triangle setup, raster walker, Fragment/Z stage, and production render-memory
wrappers into one focused render path:

```text
decoded BEGIN_FRAME/DRAW
        -> clear/setup control
        -> clear_engine or triangle_setup
        -> raster_walk
        -> fragment_z
        -> render framebuffer and Z buffer
```

The renderer input is an already decoded transaction:

```text
render_cmd_valid
render_cmd_ready
gfx_pkg::decoded_command_t render_cmd
```

GFX-006 remains responsible for packet syntax and fixed-length collection.
GFX-012 executes only `NOP`, `BEGIN_FRAME`, and `DRAW_TRIANGLE` in its focused
path. `PRESENT`, `SET_SOBEL`, `READ_FRONT`, `GET_STATUS`, and `GET_COUNTERS`
remain outside this integration block. The focused path accepts syntactically
valid, state-legal command sequences: `NOP`/`BEGIN_FRAME` in `IDLE`, then
`NOP`/`DRAW_TRIANGLE` in `FRAME_ACTIVE`. Runtime legality and complete protocol
error responses remain owned by later top-level control; GFX-012 does not
duplicate decoder or error semantics.

The local execution states are:

```text
IDLE -> CLEAR -> FRAME_ACTIVE -> TRI_SETUP -> TRI_WALK -> TRI_DRAIN
```

`IDLE` accepts only legal `BEGIN_FRAME` or `NOP`. `BEGIN_FRAME` captures
`clear_rgb332` and starts the clear engine; colour and Z are cleared in parallel
to `clear_rgb332` and `8'hFF` across all 76800 addresses. No DRAW dispatches
until clear completion. `FRAME_ACTIVE` accepts legal `NOP` or `DRAW_TRIANGLE`.
During `TRI_SETUP`, exactly one DRAW is submitted and one setup result is
retired. `TRI_SETUP_RASTER` starts the walker. `TRI_SETUP_EMPTY`,
`TRI_SETUP_DEGENERATE`, and `TRI_SETUP_BACKFACE` produce no fragments or
memory writes and return to `FRAME_ACTIVE`; they are geometry results, not
protocol errors. `render_cmd_ready` is asserted only in `IDLE` and
`FRAME_ACTIVE`, with no speculative command execution or same-cycle refill.

During `TRI_WALK`, the existing covered transaction is wired directly from
`raster_walk` to `fragment_z`, including x/y and raw signed42 R/G/B/Z:

```text
raster_walk.covered_valid -> fragment_z.frag_valid
fragment_z.frag_ready     -> raster_walk.covered_ready
```

When `walk_complete` asserts, the renderer enters `TRI_DRAIN`, stops accepting
another DRAW, and waits for `fragment_z.pipeline_empty`. Only after that drain
barrier does it return to `FRAME_ACTIVE`, preventing the next triangle's Z
reads from colliding with prior-triangle writes.

GFX-012 adds original production wrappers, without resetting their arrays:

```text
framebuffer_dp.sv:
  one logical 76800x8 colour surface;
  clk_pix synchronous read-only address[16:0] -> data[7:0], one-cycle latency;
  clk_sys synchronous read/write address[16:0], write enable/data, read data,
  one-cycle read latency.

zbuffer.sv:
  clk_sys, synchronous read address[16:0] -> data[7:0], one-cycle latency;
  synchronous write enable/address[16:0]/data[7:0].
```

The wrappers follow the GFX-004 inference-compatible style as feasibility
evidence only; no vendor EBR mapping is claimed by this contract. GFX-012
instantiates only the logical render target. FRONT/RENDER/SPARE rotation is
deferred to later integration.

Memory ownership is mutually exclusive by renderer state. In `CLEAR`, the
clear engine owns both colour and Z writes. In `TRI_WALK` and `TRI_DRAIN`,
`fragment_z` owns pass colour/Z writes and Z reads. Planned assertions shall
ensure clear and fragment writes cannot be active together. D-032 remains
authoritative for the forbidden legal-operation hazard:

```text
!(z_rd_en && z_wr_en && (z_rd_addr == z_wr_addr))
```

GFX-012 exposes no architectural `FRAME_DONE` and fabricates no presentation
acknowledgement. For focused verification it may expose the local status
`renderer_quiescent`, defined as:

```text
state == FRAME_ACTIVE
&& triangle_setup has no pending output
&& raster walker is idle
&& fragment_z.pipeline_empty
&& clear_engine is inactive
```

This means that all accepted BEGIN_FRAME/DRAW work has affected the logical
render memories and no write-producing work remains. It is not FRAME_DONE,
PRESENT completion, or display completion. After quiescence, the testbench may
inspect instantiated production memory arrays through a verification-only
hierarchical/helper path. Architectural framebuffer readback remains GFX-014.

Reset in any local state aborts the operation, clears controller/valid state,
suppresses stale writes, leaves RAM contents partially modified or otherwise
unspecified, and requires a new BEGIN_FRAME before a DRAW. RAM arrays are not
reset.

Focused GFX-012 verification shall compare all 76800 RGB332 bytes and all
76800 Z bytes after `renderer_quiescent` against the independent Python
renderer, with zero mismatches required. Directed cases include clear-only,
ordinary/flat/thin/tiny/boundary/shared-edge geometry, non-overlap and depth
ordering (far/near/equal/reversed), degenerate/backface/EMPTY/mixed streams,
zero-covered RASTER, and sequential triangles separated by TRI_DRAIN. Random
legal frames contain 1..48 triangles, rejected geometry, boundary cases,
random signed32 attribute planes, and random clear colours. A decoder-fed raw
BEGIN_FRAME/DRAW smoke composition is allowed after renderer-engine tests;
packet parsing is not duplicated and FIFO composition is optional.

Future formal properties shall check one active execution phase, exclusive
clear/fragment ownership, RASTER-only walker admission, TRI_DRAIN exit only
after `pipeline_empty`, quiescence with no pending write-producing operation,
address bounds, no writes before clear completion, and reset clearing active
control state. These are planned properties only and are not claimed as proved
by this specification task.

## D-034 — Performance-counter lifetime, event and instrumentation contract

GFX-013 uses a reusable observational counter bank. Every architectural counter
is an unsigned 32-bit modulo-2^32 value with no saturation and no sticky
overflow bit. Global reset clears every counter. The future GET_COUNTERS
snapshot order remains exactly:

```text
W1  frames_completed
W2  triangles_submitted
W3  triangles_degenerate
W4  triangles_backface_rejected
W5  candidate_pixels
W6  covered_fragments
W7  z_pass
W8  z_fail
W9  clear_cycles
W10 render_cycles
W11 triangle_setup_cycles
W12 present_wait_cycles
W13 sobel_cycles
W14 command_fifo_high_watermark
```

### Counter reset domains

The lifetime counters are:

```text
frames_completed
command_fifo_high_watermark
```

They reset only on global reset. The remaining twelve counters are per-frame
counters and reset to zero on every accepted `BEGIN_FRAME`. BEGIN_FRAME reset
has priority over any same-cycle per-frame increment event. This is the event-
level interpretation of D-019 and does not change the command protocol.

### Exact events

`frames_completed` increments once on a future system-domain
`frame_completed_event`, meaning that presentation acknowledgment and role
rotation have committed and FRAME_DONE has been generated or queued. It does
not increment on BEGIN_FRAME, `renderer_quiescent`, final DRAW, `walk_complete`,
`pipeline_empty`, PRESENT acceptance, or response transfer/backpressure.
GFX-013 accepts this event synthetically; GFX-012 does not generate it.

`triangles_submitted` increments on exactly:

```text
render_cmd_valid && render_cmd_ready &&
render_cmd.opcode == CMD_DRAW_TRIANGLE
```

It counts RASTER, EMPTY, DEGENERATE, and BACKFACE outcomes. The rejection
counters increment once when a setup result is retired with the corresponding
DEGENERATE or BACKFACE classification. EMPTY increments neither rejection
counter.

`candidate_pixels` increments once on each exact D-030 candidate-retirement
event, including both covered and uncovered candidates. It does not count
stalled covered cycles, bbox size speculation, EMPTY, DEGENERATE, or BACKFACE.
GFX-013 may add the instrumentation-only `candidate_retired` pulse to
`raster_walk`; it must not alter traversal behavior.

`covered_fragments` increments once on the accepted walker-to-Fragment/Z
transfer:

```text
covered_valid && covered_ready
```

`z_pass` and `z_fail` count completed depth decisions, not reads. GFX-013 may
add instrumentation-only `depth_result_valid` and `depth_pass` outputs to
`fragment_z`:

```text
z_pass += depth_result_valid && depth_pass
z_fail += depth_result_valid && !depth_pass
```

Equal depth is therefore a Z fail. Reset-aborted fragments that do not complete
a decision increment neither counter. Existing primitive behavior must remain
unchanged.

`clear_cycles` increments once for every active clear write cycle, observed as
the coincident clear-engine colour write event. An uninterrupted clear has
`clear_cycles == 76800`; colour and Z writes are not counted separately.

`render_cycles` increments once per system cycle in renderer states
`TRI_SETUP`, `TRI_WALK`, or `TRI_DRAIN`. It excludes IDLE, CLEAR,
FRAME_ACTIVE, command-wait idle time, and future PRESENT waiting.
`triangle_setup_cycles` increments once per cycle in `TRI_SETUP`, including the
complete submit/retire interval, and is a subset of `render_cycles`.

`present_wait_cycles` increments once per future system cycle in
`PRESENT_WAIT`. `sobel_cycles` increments once per future system-domain cycle
in which Sobel processing is active. These are explicit future event inputs;
GFX-013 does not fabricate presentation or Sobel logic.

`command_fifo_high_watermark` is lifetime state. On every system cycle it
updates as:

```text
max(command_fifo_high_watermark, zero_extend(command_fifo_level))
```

The FIFO's authoritative `level` signal is sampled directly. The exported
width is 32 bits; the required full-depth observed peak is 1024.

### Instrumentation and integration boundary

The recommended reusable bank is `rtl/perf_counters.sv`. It consumes explicit
event pulses/levels for current renderer events (`BEGIN_FRAME`, DRAW acceptance,
setup classifications, candidate retirement, covered transfer, depth result,
clear cycle, render cycle, and setup cycle) and future events
(`frame_completed_event`, `present_wait_cycle`, `sobel_cycle`, and
`command_fifo_level`). It does not derive counters from framebuffer contents or
reimplement renderer logic.

Instrumentation is passive. Adding event outputs or the counter bank must not
change command readiness, clear/setup/walker/attribute/depth behavior,
fragment ordering, memory results, or `renderer_quiescent` timing. Future
GET_COUNTERS serialization remains outside GFX-013; the bank exposes only the
current 32-bit values in W1–W14 order.

At renderer quiescence after a non-reset frame, verification shall require:

```text
triangles_submitted == RASTER + EMPTY + DEGENERATE + BACKFACE
z_pass + z_fail == covered_fragments
triangle_setup_cycles <= render_cycles
```

The first equality uses independent classification scoreboard values. No
requirement equates candidate and covered counts because uncovered candidates
are valid.

## Memories and roles

Each colour framebuffer is 76800×8 with a `clk_pix` synchronous read-only port
and a `clk_sys` synchronous read/write port, each with one architectural cycle
of read latency. Rendering reads FRONT and writes RENDER; Sobel reads RENDER and
writes SPARE; readback reads FRONT. Z is 76800×8, `clk_sys`, one synchronous
read and one synchronous write port with one-cycle read latency.

Roles are initially FRONT=0, RENDER=1, SPARE=2, with `front_valid=0`. Roles
remain pairwise distinct. RAM contents are unspecified after reset.

## Reset and presentation CDC

Global reset is asserted asynchronously and deasserted synchronously in each
functional clock domain using at least two release-synchronizer stages. Reset
clears control state, valids, FIFO logical state, responses, counters, error,
Sobel configuration validity, and pending presentation; it does not clear RAM.

Presentation uses a one-outstanding stable-payload toggle mailbox. The pixel
domain synchronizes the request, waits for the first safe presentation-boundary
pulse after prior display latency has passed, changes FRONT, sets valid, and
acknowledges. System roles rotate and FRAME_DONE is emitted only after the
synchronized acknowledgment.

NORMAL rotates old RENDER to FRONT and old FRONT to RENDER. SOBEL streams
RENDER→SPARE, checks completion, presents SPARE, then rotates old SPARE to
FRONT, old FRONT to RENDER, and old RENDER to SPARE.

## Display and Sobel adapters

Display maps `(display_x,display_y)` to `(display_x>>1,display_y>>1)` and
accounts for synchronous memory latency in control metadata. RGB332 expands to
RGB888 with the frozen bit replication in `docs/FIXED_POINT.md` and
`docs/REQUIREMENTS.md`.

The Sobel source has two-entry elastic result capacity and only advances on
accepted input transfers; it accounts for in-flight synchronous reads. The
destination owns SPARE, uses `m_tready=1` while active except reset/fatal error,
and advances only on accepted output transfers. The wrapper enforces W+1
alignment by accepted stream order, exact 76800 counts, metadata positions,
and the admitted parent final-drain behavior.

## Feasibility boundary

GFX-004 must synthesize the three colour memories, Z, and command FIFO and must
also record separate actual resource evidence for the admitted 320×240 parent
at the pinned commit. Combined target-device feasibility is assessed before deep
raster RTL. No EBR packing, integrated resource, timing, or Fmax result is
claimed here.
