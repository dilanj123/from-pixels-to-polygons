# Source-level decisions

The following D-001–D-028 decisions are the supplied authoritative input for
GFX-001. They are subordinate to the Master Project Plan and Operating
Instructions. No additional architectural decisions are introduced here.

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

## Status

These decisions are `SPECIFIED`. They have not yet been implemented or
verified by simulation, formal, synthesis, timing, or hardware execution.
