# Requirements

This document freezes the source-level v1 contract. It is subordinate to the
Master Project Plan and Operating Instructions and records D-001–D-028 without
claiming implementation evidence.

## Scope and partition

- Render 320×240 RGB332 frames and present them at 640×480 using exact 2×
  nearest-neighbour mapping.
- Use three 320×240×8 colour framebuffers and one 320×240×8, 8-bit Z buffer.
- Accept host-transformed screen-space triangles with unsigned Q4 coordinates.
- Use Pineda edge functions, positive-area accepted winding, top-left shared-edge
  ownership, strict-less-than depth, and host-computed fixed-point planes.
- Keep transform, clipping, perspective divide, winding normalization, plane
  derivation, quantization, serialization, transport, and readback comparison on
  the host. The FPGA owns command handling, setup, traversal, interpolation,
  depth/color writes, presentation, display, Sobel processing, counters, and
  readback.
- Defer textures, shaders, floating point, hardware transform/clipping, PCIe,
  external SDRAM baseline, blending, MSAA, stencil, configurable depth modes,
  dynamic resolution, extra filters, and networking.

## Geometry and interpolation

- Screen origin is top-left; +x is right; +y is down; visible pixels are
  `x=0..319`, `y=0..239`.
- Q4 coordinates use 13 unsigned bits, with legal X range 0..5120 and Y range
  0..3840. Samples are at `(x<<4)+8, (y<<4)+8`.
- For edge `a→b`, `E=dx*(p.y-a.y)-dy*(p.x-a.x)`. AREA is `E(v0,v1,v2)`;
  AREA>0 is accepted, AREA=0 is degenerate, and AREA<0 is backface/wrong
  winding. Hardware does not reorder vertices.
- An edge is inclusive when `(dy<0)||((dy==0)&&(dx>0))`; coverage requires all
  three `(E>0)||(E==0 && top_left)` tests.
- The exact pixel-centre bounding box is defined in `docs/FIXED_POINT.md`.
  It may be empty for an AREA>0 triangle and must then produce no candidates.
- R/G/B/Z starts and gradients are signed 32-bit with eight fractional bits;
  internal row/current accumulators are signed 42-bit.

## Commands, responses, and errors

- The graphics core uses a 32-bit ready/valid command stream and a 32-bit
  ready/valid response stream. Exact fixed packet layouts are in
  `docs/COMMAND_PROTOCOL.md`.
- Known commands are collected and validated atomically. Incomplete packets
  wait indefinitely; reset discards them; unknown opcodes consume one word.
- Command legality, sticky errors, fatal recovery, response ordering, response
  stability under backpressure, and FRAME_DONE semantics are frozen in the
  command protocol.
- The FIFO target is 1024×32 and the guaranteed frame list is 774 words.

## Memory, reset, and presentation

- Colour ports, Z timing, address range, F0–F3 depth sequencing, and the
  no-inter-triangle-drain rule are frozen in the microarchitecture contract.
- Logical roles are pairwise distinct: FRONT is displayed, RENDER is the
  current destination, and SPARE is free or Sobel destination. FRONT is never
  written.
- Reset is asynchronous assertion/synchronous deassertion per clock domain with
  at least two release-synchronizer stages. RAM arrays are not reset.
- Presentation uses one outstanding payload-stable toggle/mailbox request and
  acknowledgment. FRONT changes only at the defined safe presentation boundary.

## Sobel dependency and reuse boundary

- The admitted immutable dependency is
  `https://github.com/dilanj123/from-rtl-to-pixels.git`, tag
  `v1.0.1-dependency-ready`, commit
  `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`, selected top
  `rtl_to_pixels_top_pipelined`.
- The public dependency contract includes RGB888 input ready/valid, 8-bit
  output ready/valid, SOF/EOL, backpressure stability, 320×240 evidence, W+1,
  final drain, reset, APB, synthesis/resource, and timing evidence.
- The wrapper advances source/destination positions only on accepted transfers,
  requires exactly 76800 input and output transfers with defined SOF/EOL,
  applies APB configuration before SOF, and presents SPARE only after final
  drain/completion checks.
- RasterIX and Raster I are architecture references; Pineda is a mathematical
  reference. Project F may supply reviewed platform/display infrastructure.
  Core raster, command, framebuffer, reference, verification, and experiment
  work remains original and every reused file requires exact provenance.

## Evidence boundary

These are specified contracts only. No reference, RTL simulation, formal,
synthesis, timing, or hardware result is claimed by this document.
