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
