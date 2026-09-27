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
