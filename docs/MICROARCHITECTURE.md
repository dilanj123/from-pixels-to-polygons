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

The baseline walker advances one candidate per `clk_sys` target cycle using
signed32 edge additions and signed42 row/current R/G/B/Z accumulators. It emits
covered fragment tokens and drains the complete downstream pipeline before a
new triangle begins.

## Fragment/Z path

F0 quantizes RGB/Z and calculates the unsigned17 address; F1 issues the
synchronous Z read; F2 receives old Z and compares strict `<`; F3 conditionally
writes Z and RGB332. No architecture behavior depends on same-address RAM
read/write semantics. The required hazard assertion forbids simultaneous equal
Z read/write addresses.

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
