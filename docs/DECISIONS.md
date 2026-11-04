# Source-level decisions

The following D-001–D-036 decisions are the supplied authoritative source-level
decisions. They are subordinate to the Master Project Plan and Operating
Instructions.

| ID | Frozen decision |
|---|---|
| D-001 | Master Plan Gate 0–12 numbering is canonical; the checklist maps Gate 0 Contract/Dependency/Environment, Gate 1 Reference, Gate 2 Memory, Gate 3 Raster, Gate 4 Renderer, Gate 5 Display, Gate 6 Sobel, Gate 7 Deep Regression, Gate 8 Formal, and Gates 9–12 unchanged. |
| D-002 | Use exact quantized Q4 min/max pixel-centre bbox equations; clamp only after raw interval calculation; empty intervals remain empty. |
| D-003 | Host coordinates use non-negative Q4 round-nearest; signed Q8 fields use ties-away-from-zero; out-of-range values are errors, never silently saturated. |
| D-004 | Use unsigned13 coordinates, signed16 deltas, signed32 edge products/AREA/accumulators/steps; conservative edge bound is 39,321,600. |
| D-005 | Command attributes remain signed32 Q8; internal row/current accumulators are signed42 Q8. |
| D-006 | AREA>0 with an empty bbox is a valid DRAW producing zero candidates/fragments and neither rejection counter. |
| D-007 | Use the exact 1/2/16/2/2/1/1/1-word command packets and specified bit layouts. |
| D-008 | Known packets are atomic; incomplete packets wait without side effects; reset discards them; unknown opcodes consume one word. |
| D-009 | Enforce the specified IDLE/FRAME_ACTIVE legality; SET_SOBEL is IDLE-only; SOBEL PRESENT requires valid configuration; geometry rejections are not protocol errors. |
| D-010 | Use sticky CMD_ERROR and the specified recoverable/fatal error codes and recovery behavior. |
| D-011 | Use tagged, non-interleaved ready/valid responses with stable data under stall and specified response lengths/order. |
| D-012 | Use a 1024-word FIFO; the guaranteed frame list is 774 words for 48 DRAWs plus required commands. |
| D-013 | Colour memories are 76800×8 with one-cycle synchronous `clk_pix` read-only and `clk_sys` read/write ports; FRONT is never written; actual EBR inference remains to be measured. |
| D-014 | Z is 76800×8 with one-cycle synchronous read/write timing; use F0–F3 and forbid equal-address simultaneous Z read/write. |
| D-015 | Use unsigned17 address `(y<<8)+(y<<6)+x`, legal range 0..76799. |
| D-016 | Use one logical reset, asynchronous assertion/synchronous deassertion with two release stages per domain; do not reset RAM arrays. |
| D-017 | Use a one-outstanding stable-payload request/ack mailbox; switch FRONT only at the defined safe boundary; rotate roles after synchronized ACK. |
| D-018 | Use the specified RGB332↔RGB888 bit replication for display/Sobel and edge-to-RGB332 mapping. |
| D-019 | Export unsigned32 modulo counters with the specified lifetime/per-frame reset behavior and COUNTERS ordering. |
| D-020 | READ_FRONT snapshots valid FRONT, blocks role rotation, emits exact 19206-word framing, packing, and modulo-2^32 checksum. |
| D-021 | The exact `from-rtl-to-pixels` tag/commit/top is admitted; retain the project-wide immutable dependency rule and verify the specified public evidence boundary before import. |
| D-022 | Sobel source advances only on accepted transfers and uses two-entry elastic capacity with in-flight synchronous-read accounting; exactly 76800 input transfers and metadata positions are required. |
| D-023 | Sobel destination exclusively owns SPARE, uses the specified ready policy, advances only on accepted outputs, and requires exact count/metadata checks. |
| D-024 | Do not shift/drop/insert pixels; accepted stream order defines the mapping and preserves parent `k=n-(IMG_WIDTH+1)` alignment. |
| D-025 | Completion requires exact input/output counts, final EOL, no protocol error, and parent final drain/quiescence; final input acceptance alone is insufficient. |
| D-026 | Program admitted-parent APB threshold/bypass before SOF; shadow writes accepted on the same edge as SOF apply to the following frame. |
| D-027 | GFX-004/Gate 2 must combine the graphics memory spike with actual resource evidence for the exact admitted parent, separately recording resources without inventing margin. |
| D-028 | RasterIX/Raster I/Pineda are references; Project F is reviewed infrastructure only; every reused file needs provenance, while core graphics work remains original. |
| D-029 | Freeze the synthesizable triangle-setup result: `TRI_SETUP_RASTER=2'b00`, `TRI_SETUP_EMPTY=2'b01`, `TRI_SETUP_DEGENERATE=2'b10`, and `TRI_SETUP_BACKFACE=2'b11`; only RASTER enters the walker; non-RASTER bbox and initial edges canonicalize to zero; AREA, edge dx/dy, top-left flags, steps, tag, and all attributes remain valid for every legal input; the decoder owns coordinate-range errors and setup receives legal decoded coordinates as a precondition. |
| D-030 | Freeze the coverage-only raster-walker handshake, candidate retirement, state-freeze under covered-output backpressure, row-major traversal, one-shot final-candidate completion, reset abort, and the GFX-009/GFX-010 scope boundary as specified in `docs/MICROARCHITECTURE.md`. |
| D-031 | Freeze signed42 Q8 row/current R/G/B/Z attribute stepping, sign-extended signed32 setup coefficients, raw signed42 covered-fragment fields, stall/reset behavior, and the GFX-010/GFX-011 boundary as specified in `docs/MICROARCHITECTURE.md`. |
| D-032 | Freeze the fixed-latency F0–F3 fragment/Z pipeline: signed42 Q8 quantization, RGB332 and unsigned17 address conversion, one-cycle synchronous Z-read alignment, strict-less-than depth testing, coincident pass writes, no-write fails, pipeline drain, reset flushing, and the no-equal-address Z read/write integration hazard as specified in `docs/MICROARCHITECTURE.md`. |
| D-033 | Freeze the baseline renderer integration boundary, local execution states, production framebuffer/Z wrapper contracts, mutually exclusive clear/fragment memory ownership, quiescent-frame verification boundary, and GFX-012/GFX-013/GFX-014 scope split as specified in `docs/MICROARCHITECTURE.md`. |
| D-034 | Freeze unsigned32 modulo performance counters, lifetime/per-frame reset domains, exact increment events, cycle-count definitions, passive instrumentation boundaries, future presentation/Sobel event inputs, FIFO high-watermark sampling, and W1–W14 ordering as specified in `docs/MICROARCHITECTURE.md`. |
| D-035 — Snapshot framebuffer readback, synchronous packing and response-stream contract | Freeze standalone framebuffer readback start/snapshot, FRONT role lock, one-cycle synchronous reads, little-endian four-pixel packing, exact 19206-word response, modulo checksum, backpressure, completion, reset-abort, and Gate-4/Gate-5 boundary as specified in `docs/MICROARCHITECTURE.md`. |
| D-036 — Gate-5 simulation timing, renderer memory boundary and reviewed display support | Freeze the 640×480p60 logical scanout timing, exact 2× mapping and one-cycle memory alignment, reset/clock/mailbox semantics, NORMAL role/presentation behavior, renderer logical framebuffer-write port for three-buffer composition, and the sole selected Project F timing source file at its exact MIT-licensed commit, as specified in `docs/MICROARCHITECTURE.md`. Board pins, PLL/serializer, programming and physical display remain later implementation matters. |
| D-037 — Command response payload words | Freeze previously unspecified FRAME_DONE W1 as zero, ERROR W1[7:0] as the existing error code with upper bits zero, and STATUS W1/W2 as the documented architectural flags and FRONT/RENDER/SPARE IDs in `docs/COMMAND_PROTOCOL.md`; packet types, lengths, tags, and counter order are unchanged. |
| D-038 — UART word transport | Freeze GFX-023 UART as 8N1, LSB-first serial bytes, four-byte little-endian 32-bit words, parameterized `CLKS_PER_BIT` default 217 at nominal 25 MHz/115200 baud, one pending RX word, and sticky framing/overrun block-until-reset behavior, as specified in `docs/COMMAND_PROTOCOL.md`. No physical baud/clock claim is implied. |
| D-039 — GFX-026 ULX3S-85F reference implementation target | Use `LFE5U-85F-6BG381C` and the reviewed ULX3S GPDI/clock pins as the Gate-9 reproducible reference target. Assume only the LPF's stated ULX3S v2.x.x/v3.0.x-compatible pinout; no physical board revision or ownership is confirmed. Preserve exact logical clocks with a three-PLL chain from nominal 25 MHz: 300/60 MHz, then 315 MHz, then 126/25.2 MHz. See `reports/gfx026/RESULTS.md`; this selects an implementation reference and does not claim completed P&R, timing closure, programming, or hardware operation. |

## Status

D-001 through D-039 are project decisions classified as `SPECIFIED`; D-039
records the GFX-026 implementation reference and its unverified board-revision
assumption only.

D-031 has now been implemented by GFX-010, and its signed42
attribute-stepping behavior is `RTL SIMULATION VERIFIED` at implementation
commit `d7b6f60b7bcf4a10da0c23d39ba202b9d43a3e99`.

This does not imply formal proof, synthesis, P&R, timing, or hardware evidence.

D-035 specifies the GFX-014 standalone readback engine contract. Its
implementation and verification are recorded as RTL SIMULATION VERIFIED in
the GFX-014 evidence below.

D-036 freezes the Gate-5 simulation/architectural presentation contract only.
No Gate-5 RTL, simulation, formal, synthesis, timing, board, or hardware
evidence is implied.
