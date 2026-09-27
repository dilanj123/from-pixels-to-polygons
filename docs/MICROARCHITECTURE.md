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
