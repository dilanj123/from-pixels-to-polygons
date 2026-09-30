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

## GFX-014 standalone framebuffer readback

GFX-014 implements the standalone readback streamer. The later system
controller determines READ_FRONT legality (`IDLE`, `front_valid_sys`, and no
presentation outstanding) and issues a legal start. GFX-014 does not implement
the role manager, FRONT rotation, presentation CDC, `front_valid`, PRESENT,
FRAME_DONE, top-level command legality, or response arbitration.

### Start and snapshot

The start interface is:

```text
start_valid
start_ready
start_tag      [15:0]
start_front_id [1:0]
```

A start transfers only on `start_valid && start_ready`. The engine captures
the tag and FRONT ID at that edge. Live input changes afterward cannot affect
the transaction. IDs 0, 1, and 2 are the valid physical buffers; ID 3 is an
integration-precondition violation. The conservative ready rule is
`start_ready = !readback_active`, with no refill on the final response edge.

`readback_active` is asserted for the accepted transaction through every
header, source read, data word, trailer, and response stall. It clears only
when the final checksum response transfers. `role_lock` may be exposed as an
alias and, if present, equals `readback_active`. The captured FRONT ID stays
constant and selects every source read and descriptor field. The later role
manager must not rotate or reassign that physical buffer while active.

### Synchronous source reads and data packing

The source interface is:

```text
fb_rd_en
fb_rd_addr      [16:0]
fb_rd_buffer_id [1:0]
fb_rd_data      [7:0]
```

The source memory samples an enabled address on the rising edge and presents
its byte during the following cycle. The engine captures returned data only
when a corresponding one-cycle-delayed request is valid. Every request uses
the captured FRONT ID. A successful uninterrupted transaction issues exactly
76,800 requests, with addresses `0..76799` exactly once and in order. The
selected framebuffer is read-only for the transaction; the later role/control
layer guarantees that no writer targets the captured FRONT while active.
GFX-014 does not arbitrate or suppress those writes. The production
`framebuffer_dp` system read port has one-cycle latency and needs no physical
read-enable; integration may use `fb_rd_en` for ownership and response-valid
bookkeeping while driving its address to that port.

After the three BEGIN words have transferred, pixels are read and grouped in
four-byte words. For data word `n=0..19199`, addresses are `4*n+0` through
`4*n+3`, packed as:

```text
rsp_data[7:0]   = pixel[4*n+0]
rsp_data[15:8]  = pixel[4*n+1]
rsp_data[23:16] = pixel[4*n+2]
rsp_data[31:24] = pixel[4*n+3]
```

The baseline finishes one packed word, holds it until accepted, and only then
consumes the next four-pixel group. It uses only the fixed storage needed for
one packed word and read alignment; no deep prefetch queue or throughput
optimization is part of GFX-014.

### Response framing and checksum

The response interface is canonical ready/valid:

```text
rsp_valid
rsp_ready
rsp_data [31:0]
```

A stalled response (`rsp_valid && !rsp_ready`) keeps valid and all 32 data bits
stable. Its address/group index, logical response position, and checksum do
not advance twice or skip. A successful transfer is exactly 19,206 accepted
words, in this order:

| Position | Value |
|---|---|
| BEGIN W0 | `{4'hC, 12'h000, snapshot_tag}` |
| BEGIN W1 | `32'd19200` data-word count |
| BEGIN W2 | `{3'b000, 8'd1, snapshot_front_id, 9'd240, 10'd320}` |
| Data | 19,200 four-pixel words in ascending address order |
| END W0 | `{4'hD, 12'h000, snapshot_tag}` |
| END W1 | `32'h00000000` success status |
| END W2 | modulo-2^32 unsigned sum of the 19,200 data words |

No framebuffer read is issued before BEGIN W2 transfers. The checksum excludes
headers, descriptor, and trailer. It updates exactly once when each data word
transfers (`rsp_valid && rsp_ready`), never on assembly or while stalled.
There are no additional GFX-014 readback error codes; illegal READ_FRONT
dispatch is owned by outer control.

`readback_complete` is a one-cycle pulse on acceptance of the final END W2
checksum word. It does not pulse when the last pixel is sampled, the last data
word is assembled, or END begins. `readback_active` remains high through that
transfer and deasserts after it; no same-edge restart is accepted.

### Reset and integration boundary

Reset aborts any active transaction: it clears active and response valid,
pending read bookkeeping, partial packed data, checksum, and completion state.
It emits no synthetic END for an aborted request, and no pre-reset data or
completion may leak into a later transaction. RAM contents are not reset. A
new accepted request starts at address zero with its own captured tag/ID and a
zero checksum.

The later Gate-5/system integration verifies READ_FRONT legality, captures the
valid FRONT ID, connects the selected physical framebuffer system read port,
holds role assignments stable while active, forwards responses into shared
response arbitration, and releases the role lock after completion. Those
functions are outside GFX-014.

## D-036 — Gate-5 simulation timing, renderer memory boundary and reviewed display support

D-036 freezes the abstract Gate-5 presentation contract. It does not select a
physical board revision, connector, pinout, board oscillator, serializer,
programming tool, monitor, or cable. Those are board-specific implementation
decisions for the later synthesis/hardware gates. The Master Plan names
ECP5-85F-class hardware and a preferred ULX3S-85F candidate but explicitly
defers current board/tool selection; Gate-5 simulation does not require board
selection. No PLL or physical clock feasibility is claimed.

### Scanout timing and pixel contract

The logical pixel clock is `clk_pix = 25.2 MHz` (ideal simulation period
`39.682539... ns`). The frozen 640×480p60 raster is:

| Axis | Active | Front porch | Sync | Back porch | Total | Polarity |
|---|---:|---:|---:|---:|---:|---|
| Horizontal | 640 | 16 | 96 | 48 | 800 pixel clocks | active-low HSYNC |
| Vertical | 480 | 10 | 2 | 33 | 525 lines | active-low VSYNC |

The raster timing coordinates follow the selected Project F timing module:
horizontal `h=-160..639` (800 pixel slots) and vertical `v=-45..479`
(525 lines). The visible active region is exactly `h=0..639`, `v=0..479`;
`active_video` is true there and false throughout blanking. HSYNC is low for
`h=-144..-49`; VSYNC is low for `v=-35..-34`. The active-frame origin/first
pixel is `(h,v)=(0,0)`, and its last pixel is `(639,479)`. The timing frame
origin is `(-160,-45)`; raster wrap follows `(639,479)` to `(-160,-45)`.

The exact 2× mapping is unchanged:

```text
src_x = h >> 1
src_y = v >> 1
src_addr = src_y*320 + src_x
```

Each source pixel appears at `(2x,2y)`, `(2x+1,2y)`, `(2x,2y+1)`, and
`(2x+1,2y+1)`. There is no filtering. `src_addr` is in `0..76799` for every
active pixel. The selected timing module registers `de`, sync, frame/line
pulses, and screen coordinates together; the framebuffer then adds its
one-cycle synchronous pixel-read latency. The scanout adapter shall delay that
timing tuple (including selected FRONT ID) one additional `clk_pix` cycle to
align with returned framebuffer data. The RGB value and delayed control tuple
must refer to the same pixel slot, including first/last pixels and line/frame
transitions. Output RGB is black when delayed `active_video=0` or
`front_valid=0`.

The safe presentation boundary is the Project F timing module's registered
`frame` event for the raster origin `(-160,-45)`, the first slot of the
vertical blanking/frame interval. A pending request may switch pixel-domain
FRONT only on that event, never during active video. The display read pipeline
is outside the active region at this boundary; the new buffer is selected well
before the next active frame begins at `(0,0)`. `front_valid` becomes true at
the first such acknowledged switch. Before then, visible RGB remains black
regardless of RAM contents.

RGB332 expands to RGB888 by the already-frozen bit replication:

```text
R8 = {R3, R3, R3[2:1]}
G8 = {G3, G3, G3[2:1]}
B8 = {B2, B2, B2, B2}
```

Zero maps to zero, each channel maximum maps to 255, and no gamma correction
is applied. Gate-5 tests shall check all 256 RGB332 input bytes, not only
representative colours.

These numeric timing values adopt the Project F `display_480p.sv` candidate
parameters at the exact reviewed revision listed below. They freeze the
project contract; they do not establish monitor compatibility or physical
clock realizability.

### Logical clocks and reset

`clk_sys` is the command, renderer, role-control, and readback system domain;
the Master Plan's 60 MHz remains its target constraint, not a measured or
achieved frequency.
`clk_pix` is the scanout timing, pixel-memory-read, pixel-FRONT, and
presentation-boundary domain. For Gate-5 correctness and CDC verification,
these domains are treated as asynchronous: simulations use independent clock
periods and randomized initial phase, with no phase/ratio assumption. A future
board may derive them from related sources, but that does not alter this
contract or remove the mailbox.

There is one logical reset. Assertion is common and asynchronous; deassertion
is synchronized independently into each functional clock domain with at least
two stages. RAM arrays are never reset. Unilateral reset of only `clk_sys` or
only `clk_pix` is outside the v1 contract. Reset in either active domain is
therefore modeled as common assertion to both domains. Reset clears logical
roles to FRONT=0, RENDER=1, SPARE=2, `front_valid=0`, mailbox request/ack
state, pending completion, and scanout control state. No stale request,
acknowledgment, role rotation, or FRAME_DONE may survive reset.

### Presentation mailbox and role ownership

The system domain owns `front_id_sys`, `render_id`, `spare_id`, requested FRONT
payload, and request toggle. Initial IDs are FRONT=0, RENDER=1, SPARE=2; IDs
remain pairwise distinct. The pixel domain owns its local active scanout FRONT
selection and `front_valid`.

Only one presentation request may be outstanding. The system registers the
requested physical buffer ID before/with toggling the request and holds that
payload stable until the matching acknowledgment is synchronized back. Only
the one-bit request/ack toggles cross through synchronizers; the multi-bit ID
is a stable-payload mailbox sampled after request synchronization. The pixel
domain detects one new request, waits for the registered `frame` event at
raster origin `(-160,-45)`, adopts that ID, sets `front_valid`, and returns
exactly one matching acknowledgment. No second request is accepted while one
is outstanding. Reset
clears both sides under the common-reset rule and cannot synthesize a phantom
ack.

After the synchronized acknowledgment, and only after the role update, system
control may generate/queue FRAME_DONE. For NORMAL presentation:

```text
new FRONT  = old RENDER
new RENDER = old FRONT
SPARE      = unchanged
```

Presentation is legal only after the accepted frame's renderer work has
completed, `renderer_quiescent` is true (including Fragment/Z pipeline empty),
and the RENDER contents are the completed frame to publish. An incomplete or
aborted render is not presented. FRONT is never written; NORMAL rendering
writes only RENDER and does not write SPARE. The role manager is the sole owner
of role changes.

GFX-014's `readback_active` locks its captured FRONT ID against role
reassignment for the entire readback, including response stalls. System
control shall not start a presentation while readback is active, and the role
manager shall not rotate/reassign any role during the lock. The readback engine
and its interface are not redesigned by D-036.

### Renderer-to-three-framebuffer composition boundary

In the current GFX-012 implementation, `renderer_core` directly instantiates
one `framebuffer_dp` and connects its internal clear/fragment write mux to that
memory. This is sufficient for its accepted single-surface tests but does not
provide physical-buffer selection. D-036 freezes one narrow composition
interface change for Gate 5: replace that internal colour-memory instance
connection with a single logical system write port from `renderer_core`:

```systemverilog
output logic        render_fb_wr_en;
output logic [16:0] render_fb_wr_addr;
output logic [7:0]  render_fb_wr_data;
```

This port is the existing clear-versus-fragment ownership mux result. During
CLEAR it carries the clear engine's colour write; during TRI_WALK/TRI_DRAIN it
carries the passing Fragment/Z colour write; otherwise `render_fb_wr_en=0`.
No framebuffer address/data arithmetic or raster/depth algorithm moves out of
the existing renderer. The role manager does not enter the renderer datapath:
the external memory bank routes every enabled logical write only to the
physical instance selected by `render_id`.

The Gate-5 top owns three unchanged `framebuffer_dp` instances. Their pixel
ports receive the same scanout address; registered pixel data is selected
using the FRONT ID delayed with the one-cycle read. The system write port
routes the renderer's single logical write to RENDER only. The system read port
routes GFX-014 readback requests to the captured FRONT ID; readback and
render-write ownership are mutually exclusive under command-state legality.
All non-selected buffers have writes disabled. The existing single Z buffer
and its GFX-011 synchronous interface remain owned by `renderer_core`; no Z
algorithm or memory semantics change is required. GFX-012 tests may supply a
one-buffer memory shell around the new logical write port, preserving the same
renderer behavior and algorithm. The external port extraction is an interface
composition change, not permission for a renderer rewrite.

### Reviewed Project F source selection

The only Project F source selected for planned Gate-5 reuse is:

```text
Repository: https://github.com/projf/projf-explore.git
Commit:     dd212c2e5e0e0d8bdcf93ba077630dbfd49ae708
Path:       lib/display/display_480p.sv
SHA-256:    729b2a634735651925e37b02e3e51db035d149d035340c1c237c87e27ad68e50
License:    MIT, root LICENSE at the same commit
Copyright:  ©2022 Will Green
Destination: third_party/projectf/lib/display/display_480p.sv
Purpose:    generic 640×480 timing/counter generator for simulation and scanout
Disposition: planned unmodified copy; preserve source header and MIT LICENSE
```

This file is synthesizable generic timing RTL with no Xilinx or ECP5 primitive;
it is usable in an ECP5 design but does not establish ECP5 implementation
evidence. Its numeric timing parameters and signed raster-coordinate ranges
are the values frozen above. Import is not performed by this decision task.
When imported, both this file and its license shall be recorded in
`THIRD_PARTY_NOTICES.md` and
`docs/THIRD_PARTY_MANIFEST.md` with the exact commit and local hash.

No other Project F file is selected for Gate 5. In particular,
The source audit and dispositions are:

| Repository / exact commit | Exact candidate path | Licence / copyright | Purpose and compatibility | D-036 disposition / local destination |
|---|---|---|---|---|
| `projf/projf-explore`, `dd212c2e5e0e0d8bdcf93ba077630dbfd49ae708` | `lib/display/display_480p.sv` | MIT; ©2022 Will Green | Generic 640×480 timing, signed coordinates, registered DE/sync/frame/line; no vendor primitive, ECP5-compatible | **Selected**, planned unmodified at `third_party/projectf/lib/display/display_480p.sv`; Gate-5 timing and simulation |
| same | `graphics/fpga-graphics/simple_480p.sv` | MIT; ©2023 Will Green | Generic timing counter, but uses a different counter/porch convention and does not provide the selected registered frame/line tuple | Not selected; no local destination |
| same | `lib/clock/xc7/clock_480p.sv` | MIT; ©Will Green (header) | 25.2 MHz 640×480 clock reference using Xilinx `MMCME2_BASE`/`BUFG`; not ECP5-compatible | Inspected as frequency reference only; not copied; no local destination; physical clocking is later |
| same | `lib/clock/ecp5/clock2_gen.v` | MIT; ©Will Green | ECP5 `EHXPLLL` dual-clock generator; board/device clock implementation | Not selected without board/input-clock contract; later physical work; no local destination |
| same | `lib/display/ecp5/dvi_generator.sv` | MIT; ©Will Green | ECP5 ODDRX1F-based DVI/TMDS serialization | Not needed for Gate-5 simulation; later physical output; no local destination |
| same | `lib/display/tmds_encoder_dvi.sv` | MIT; ©Will Green | TMDS channel encoder for DVI output | Not needed for Gate-5 simulation; later physical output; no local destination |
| same | `graphics/fpga-graphics/ecp5/ulx3s.lpf` | MIT; ©Will Green | ULX3S-85F-specific pin locations and 25 MHz input-clock constraint | No board/revision selected; later physical constraints; no local destination |
| `projf/display_controller`, `dafbe3385749da4ae2100bba2945350ace7ec04e` | `rtl/display_timings.v`, `rtl/display_clocks.v`, `rtl/dvi_generator.v`, `rtl/serializer_10to1.v` | MIT; ©2019 Will Green | Generic timing and 25.2/126 MHz clock references plus DVI/serializer blocks; README notes Xilinx Series-7-specific SerDes support | Audited alternative, not selected; overlaps selected timing source and introduces unused clock/serializer scope; no local destination |

Only the selected `display_480p.sv` is planned for Gate-5 reuse. No source is
imported by D-036. When it is imported, the selected file and its root MIT
LICENSE shall be recorded in `THIRD_PARTY_NOTICES.md` and
`docs/THIRD_PARTY_MANIFEST.md` with the pinned commit and local hash.
Project-owned 2× scanout mapping, role control, mailbox, and memory selection
remain original RTL.

The separate `from-rtl-to-pixels` dependency remains pinned at
`v1.0.1-dependency-ready`, commit
`ad35514c990f6e1c9eb9fa18aee9d906f9df7721`, top
`rtl_to_pixels_top_pipelined`. It is not a Gate-5 dependency and no parent RTL,
Sobel reader/writer/APB/bridge, or parent build integration is added here. Any
source reuse/license issue is tracked as a Gate-6 dependency matter and does
not block Gate-5 simulation.

### Gate boundaries

Gate 5 comprises deterministic timing/scanout simulation, exact 2× mapping and
memory-latency alignment, front-invalid black output, three-buffer roles,
presentation CDC, NORMAL switching, and multi-frame simulation. Gate 6 owns
Sobel integration. Gate 9 owns full synthesis, P&R, resource and routed timing
evidence. Gate 10 owns board programming, physical display, physical
framebuffer comparison/readback, and physical Sobel validation. D-036 is
`SPECIFIED`; it adds no implementation or verification evidence.
