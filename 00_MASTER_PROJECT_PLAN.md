# From Pixels to Polygons — Master Project Plan and Replication Playbook

**Version:** 1.0  
**Date:** 2026-09-26  
**Project repository:** `from-pixels-to-polygons`  
**Project type:** Public RTL/FPGA graphics engineering portfolio project  
**Parent project/IP dependency:** `from-rtl-to-pixels`  
**Primary development host:** Apple Silicon Mac  
**Planned physical FPGA class:** Lattice ECP5 LFE5U-85F  
**Preferred candidate board:** ULX3S-85F, subject to current availability/tool support when Gate 9/10 is reached  
**Status:** Authoritative plan for a future ChatGPT Project; implementation must not begin until the parent RTL-to-Pixels dependency is in a known-good evidence-backed state.

---

# 0. Purpose of this document

This document is the master project contract for **From Pixels to Polygons**.

The project is deliberately scoped as a small, fixed-function FPGA 3D graphics accelerator rather than a modern GPU. The goal is to demonstrate graphics microarchitecture, synthesizable RTL, fixed-point arithmetic, memory architecture, clock-domain integration, verification, formal reasoning, synthesis, timing analysis, physical FPGA validation, and measured optimisation in a design that one engineer can credibly understand and defend end-to-end.

The project follows the same evidence-driven method as `from-rtl-to-pixels`:

> **DEFINE → BUILD SIMPLE BASELINE → VERIFY → IMPLEMENT → MEASURE → IDENTIFY BOTTLENECK → FORM HYPOTHESIS → MAKE ONE CONTROLLED CHANGE → RE-VERIFY → RE-MEASURE → RETAIN/MODIFY/REJECT → COMPARE → CONCLUDE**

A rotating cube is a demonstration. The engineering process and evidence are the project.

---

# 1. Authority and document hierarchy

If project documents disagree, use this order:

1. `00_MASTER_PROJECT_PLAN.md`
2. `01_CHATGPT_PROJECT_OPERATING_INSTRUCTIONS.md`
3. `docs/REQUIREMENTS.md`
4. `docs/MICROARCHITECTURE.md`
5. `docs/COMMAND_PROTOCOL.md`
6. `docs/FIXED_POINT.md`
7. `docs/VERIFICATION_PLAN.md`
8. `docs/DECISIONS.md`
9. `docs/PROJECT_STATE.md`
10. `docs/EVIDENCE_INDEX.md`
11. RTL/tests/scripts
12. older notes/handoffs

A contradiction must never be resolved silently.

When a contradiction is found:

1. identify it;
2. determine intended behaviour;
3. update the highest authoritative specification that needs correction;
4. record the decision in `docs/DECISIONS.md`;
5. update tests before or with implementation changes;
6. preserve evidence from the superseded behaviour where useful.

---

# 2. Executive project definition

## 2.1 Title

**From Pixels to Polygons — Fixed-Function FPGA 3D Graphics Accelerator**

## 2.2 Main objective

Build an original SystemVerilog fixed-function 3D raster graphics accelerator that accepts quantized screen-space triangle commands from a host, rasterizes them using incremental edge functions, interpolates colour and depth, performs a Z test, writes an on-chip framebuffer, and drives a real digital display.

The system shall also integrate the completed `from-rtl-to-pixels` Sobel accelerator as a pinned, reusable IP block through its public ready/valid RGB888/APB interfaces, without modifying the Sobel core merely to fit the graphics system.

The complete design shall be checked against independent software reference models, exercised under randomized control/CDC conditions, synthesized and routed, physically read back from hardware, and subjected to exactly one evidence-driven microarchitecture optimisation after the baseline bottleneck has actually been measured.

## 2.3 Main engineering questions

1. How can a small triangle rasterizer be partitioned so that expensive low-throughput geometry work remains in host software while repetitive high-throughput pixel work maps cleanly into FPGA RTL?
2. How do fixed-point format, pipeline placement and memory organization affect correctness, latency, throughput, area and timing?
3. Can three on-chip framebuffers plus an 8-bit Z buffer provide a clean, contention-free architecture for simultaneous display, rendering and Sobel post-processing?
4. Can an independently verified streaming image accelerator be reused as IP inside a larger graphics system without violating its protocol or internal assumptions?
5. What mechanism actually limits the baseline implementation after route, and what single controlled change best addresses it?

## 2.4 Why this scope

The design is deliberately smaller than a Voodoo-class GPU and much smaller than a modern programmable GPU.

It still exercises:

- hardware/software partitioning;
- command processing;
- fixed-point arithmetic;
- signed arithmetic and overflow reasoning;
- triangle geometry;
- rasterization/fill conventions;
- pipelined datapaths;
- memory inference and BRAM organization;
- depth buffering;
- ready/valid flow control;
- CDC and reset;
- framebuffer presentation;
- real display timing;
- reusable IP integration;
- reference-model verification;
- randomized regression;
- targeted formal properties;
- synthesis/place-and-route;
- timing/resource trade-offs;
- hardware readback;
- performance counters;
- evidence-driven optimisation.

This is the intended CV value. Feature count is not the objective.

---

# 3. Public technical reference set and originality boundary

The project architecture is informed by public existence proofs. These references validate major ideas but do not provide the core implementation.

## 3.1 RasterIX

Reference: `https://github.com/ToNi3141/Rasterix`

Useful evidence/ideas:

- software-side vertex work with FPGA-side rasterization;
- fixed-function raster pipeline;
- fixed-point interpolation;
- framebuffer/depth concepts;
- software rasterizer/reference ideas;
- evidence that a larger design can fit modest FPGA resources.

Policy:

- architecture/reference only;
- do not copy its rasterizer RTL;
- treat GPL-3.0 licensing as a strong reason to keep our original core independent.

## 3.2 Raster I

Reference: `https://github.com/raster-gpu/raster-i`

Useful evidence/ideas:

- Pineda-style rasterization is practical in FPGA hardware;
- fixed-point interpolation;
- multiple graphics/display clock domains;
- VSync-driven framebuffer presentation;
- deeper pipeline/memory architecture examples.

Policy:

- architecture/reference only;
- do not copy implementation.

## 3.3 Pineda rasterization paper

Reference: Juan Pineda, *A Parallel Algorithm for Polygon Rasterization*, 1988.

Useful basis:

- edge functions;
- incremental X/Y stepping;
- suitability for Z-buffered framebuffer rasterization;
- linear interpolation compatibility.

The project shall implement its own edge-function rasterizer from the mathematical specification.

## 3.4 Project F

Reference: `https://github.com/projf/projf-explore`

Useful infrastructure:

- ECP5/ULX3S constraints;
- display timing;
- DVI/TMDS support;
- clock-generation helpers;
- open-source Yosys/nextpnr ECP5 flow examples.

Policy:

- selected platform/display infrastructure may be reused only after exact file/commit/licence review;
- preserve original copyright/licence notices;
- add entries to `THIRD_PARTY_NOTICES.md` and `docs/THIRD_PARTY_MANIFEST.md`;
- do not reuse Project F graphics/raster logic as the core project implementation.

## 3.5 Lattice ECP5 vendor documentation

Use current official Lattice documents for:

- EBR width/depth modes;
- true dual-port memory semantics;
- DSP/multiplier resources;
- PLL/clocking constraints;
- device/package resources;
- any board/device-specific implementation rules.

## 3.6 Original project work

The following should be original:

- command protocol;
- command FIFO integration/control;
- command decoder;
- clear engine;
- triangle setup RTL;
- edge/top-left logic;
- raster walker;
- attribute stepping;
- fragment/Z pipeline;
- framebuffer wrappers/role manager;
- presentation CDC logic;
- 2× scanout mapper;
- performance counters;
- readback engine;
- Sobel framebuffer stream adapters;
- Sobel APB wrapper;
- host command compiler;
- independent raster reference model;
- full verification environment;
- selected formal properties;
- synthesis/timing/analysis scripts;
- debug case studies;
- project diagrams/documentation.

---

# 4. Scope

## 4.1 MVP / v1 includes

- ECP5-85F-class physical graphics target;
- 320×240 internal render surface;
- 640×480 physical display output with exact 2× nearest-neighbour expansion;
- RGB332 colour framebuffer;
- three physical colour framebuffers;
- one 8-bit depth buffer;
- host-transformed screen-space triangles;
- 1/16-pixel subpixel geometry;
- Pineda-style edge rasterization;
- top-left shared-edge ownership rule;
- clockwise/positive-area accepted winding according to the project coordinate convention;
- host-computed colour/depth planes;
- incremental fixed-point R/G/B/Z stepping;
- strict-less-than Z test;
- one candidate pixel per clock steady-state design target for the baseline raster walker;
- 32-bit ready/valid command stream;
- fixed command packet sizes;
- 1024×32 command FIFO target;
- UART adapter for physical bring-up;
- response channel and frame completion acknowledgement;
- performance counters;
- framebuffer readback;
- independent Python reference renderer;
- randomized and directed simulation;
- CDC/reset tests;
- targeted formal checks;
- Yosys/nextpnr synthesis and P&R;
- physical framebuffer/reference comparison;
- real DVI/HDMI-compatible display demonstration;
- pinned `from-rtl-to-pixels` Sobel integration;
- exactly one evidence-driven post-baseline architecture experiment.

## 4.2 Explicitly out of scope for v1

Do not add before baseline publication gates:

- texture mapping;
- programmable shaders;
- hardware vertex transform;
- hardware clipping/perspective divide;
- floating-point raster arithmetic;
- OpenGL/Vulkan/Direct3D compatibility;
- PCIe;
- kernel/OS graphics driver;
- external SDRAM in the baseline design;
- alpha blending;
- MSAA;
- stencil;
- configurable depth functions;
- general-purpose GPU compute;
- cache hierarchy;
- multiple render targets;
- dynamic render resolution;
- arbitrary scaling;
- extra image-processing filters beyond imported Sobel;
- Ethernet/networking merely to broaden scope.

These may become future projects only after the baseline is complete.

---

# 5. Dependency on From RTL to Pixels

## 5.1 Admission rule

Do not begin Sobel integration until the parent `from-rtl-to-pixels` project has a pinned known-good commit/tag with evidence for the interface behaviour the graphics project relies upon.

Preferred state:

- Gate 5 / public-CV-ready parent project;
- complete functional regression;
- documented ready/valid semantics;
- 320×240 legal compile-time parameterization confirmed by actual regression if needed;
- synthesis/timing evidence for at least one Sobel architecture;
- exact commit/tag recorded.

## 5.2 Import mechanism

Use a pinned Git submodule or equivalently immutable dependency record:

```text
ip/
└── rtl-to-pixels/
```

Record:

- repository URL;
- exact commit/tag;
- import date;
- test command used to verify dependency;
- evidence path.

## 5.3 No hidden modification

Do not modify Sobel internals to simplify GPU integration unless a genuine bug or missing public contract is discovered.

If change is required:

1. reproduce issue in parent project;
2. fix and verify there;
3. advance pinned dependency commit;
4. record dependency update.

---

# 6. Frozen graphics coordinate contract

## 6.1 Screen space

```text
origin = top-left
+x     = right
+y     = down
```

Visible integer pixels:

```text
x = 0 .. 319
y = 0 .. 239
```

## 6.2 Subpixel representation

Vertex X/Y use unsigned Q?.4 storage with four fractional bits.

Canonical storage width:

```text
13 bits per X/Y coordinate
```

Legal coordinate extent:

```text
0 <= X_q4 <= 320*16 = 5120
0 <= Y_q4 <= 240*16 = 3840
```

The exact command encoding shall reserve 13 bits for X and 13 bits for Y.

## 6.3 Pixel sample position

Pixel `(x,y)` is sampled at its centre:

```text
sample_x_q4 = (x << 4) + 8
sample_y_q4 = (y << 4) + 8
```

No corner sampling.

---

# 7. Triangle edge equation and winding

For edge `a → b` and point `p`:

```text
dx = b.x - a.x
dy = b.y - a.y

E(a,b,p) = dx*(p.y-a.y) - dy*(p.x-a.x)
```

Triangle area proxy:

```text
AREA = E(v0,v1,v2)
```

Frozen v1 policy:

```text
AREA > 0  -> accepted orientation
AREA = 0  -> degenerate, reject
AREA < 0  -> back-facing/wrong orientation, reject
```

Host should normalize winding before submission.

Hardware does not swap vertices in v1.

Counters distinguish degenerate from backface rejection.

---

# 8. Top-left fill convention

Shared-edge ownership is a specification requirement.

For the frozen orientation, define an inclusive/top-left edge as:

```text
(dy < 0) || (dy == 0 && dx > 0)
```

For one edge:

```text
inside_edge = (E > 0) || (E == 0 && edge_is_top_left)
```

A sample is covered only if all three edge tests pass.

The Python reference and RTL must implement the same rule.

Mandatory directed test:

- two triangles forming one rectangle;
- no crack;
- no double-owned sample;
- exact expected coverage.

---

# 9. Edge arithmetic widths

Maximum useful legal deltas are bounded by screen extent in Q4 units.

Planning representation:

```text
dx/dy storage: signed 16-bit
edge accumulators: signed 32-bit
edge X/Y steps: signed 32-bit
```

The design intentionally uses comfortable 32-bit edge accumulators rather than aggressively minimizing width.

`docs/FIXED_POINT.md` must provide a formal range derivation before implementation is frozen.

No legal coordinate may overflow an edge accumulator.

---

# 10. Incremental edge stepping

From current sample to one pixel right:

```text
E += -(dy << 4)
```

From start of current row to next row:

```text
row_E += (dx << 4)
```

Triangle setup performs the initial multiplies; steady raster walk performs only comparisons and additions for edge functions.

No division or per-pixel multiply is allowed in the baseline raster loop.

---

# 11. Bounding box contract

Triangle setup derives a clamped integer candidate rectangle from the submitted subpixel vertices.

The exact ceil/floor equations must be frozen in `docs/FIXED_POINT.md` and implemented identically in the reference and RTL.

Candidate bounds are always clamped to:

```text
x = 0..319
y = 0..239
```

The edge functions, not the bounding box, define actual coverage.

The baseline walks every candidate in the box.

Do not add span skipping/tiling until baseline measurements justify it.

---

# 12. Host/FPGA partition

## 12.1 Host responsibilities

Host software performs:

- mesh/model loading;
- model transform;
- view transform;
- projection;
- near-plane/viewport clipping;
- perspective divide;
- screen-space conversion;
- re-triangulation after clipping;
- winding normalization;
- attribute-plane derivation;
- fixed-point quantization;
- command serialization;
- UART/transport;
- response handling;
- framebuffer readback and comparison.

## 12.2 FPGA responsibilities

FPGA performs:

- command collection/validation;
- frame clear;
- area/winding validation;
- bounding box setup;
- edge coefficient setup;
- initial edge evaluation;
- top-left classification;
- candidate traversal;
- incremental RGB/Z stepping;
- coverage classification;
- colour/depth quantization;
- Z read/compare/write;
- colour framebuffer write;
- buffer ownership/presentation;
- display scanout;
- Sobel post-processing;
- performance counters;
- readback.

This division intentionally keeps low-throughput numerically expensive operations out of the v1 FPGA datapath while preserving the graphics-specific high-throughput workload in hardware.

---

# 13. Attribute interpolation contract

Host computes quantized planes for:

- R;
- G;
- B;
- Z.

Each attribute uses a signed 32-bit fixed-point representation with eight fractional bits:

```text
stored = real_value * 256
```

Each DRAW packet provides:

```text
attribute_start
d_attribute_dx
d_attribute_dy
```

`attribute_start` is defined at the centre of the candidate pixel `(xmin,ymin)`.

The raster walker maintains row/current accumulators.

Horizontal candidate step:

```text
A += dA_dx
```

Next row:

```text
row_A += dA_dy
```

The independent reference renderer shall calculate expected attributes mathematically from start + x/y offsets rather than replicating the hardware accumulator schedule.

---

# 14. Colour quantization

For an interpolated colour accumulator:

```text
value_i = arithmetic_shift_right(value_raw, 8)
```

Clamp to:

```text
0..255
```

Framebuffer RGB332 packing:

```text
bits 7:5 = R8[7:5]
bits 4:2 = G8[7:5]
bits 1:0 = B8[7:6]
```

No dithering.

No alpha.

No blending.

Rounding/truncation behaviour must be explicit and identical in reference/RTL.

---

# 15. Depth contract

Depth storage:

```text
8-bit unsigned
0   = nearest
254 = furthest drawable
255 = clear/infinity
```

Quantization:

```text
z_i = arithmetic_shift_right(z_raw, 8)
clamp 0..254
```

Depth test:

```text
new_z < old_z
```

If pass:

- write new Z;
- write RGB332.

If fail:

- no Z write;
- no colour write.

Equal depth does not replace the existing sample.

No configurable depth mode in v1.

---

# 16. Framebuffer and Z architecture

## 16.1 Physical memories

Use three physical 320×240×8 colour framebuffers:

```text
FB0
FB1
FB2
```

and one 320×240×8 Z buffer.

Logical roles:

```text
FRONT  = currently displayed completed frame
RENDER = current rendering/raw frame destination
SPARE  = free or Sobel destination
```

Role IDs must always be pairwise distinct.

## 16.2 EBR planning estimate

For 76,800 bytes at an approximately 2048×9 EBR organization:

```text
ceil(76800/2048) = 38 EBR per 8-bit surface
```

Planning total:

```text
3 colour buffers = 114 EBR
1 Z buffer        =  38 EBR
--------------------------
large memories    = 152 EBR
```

The ECP5-85F has 208 18-Kbit EBRs according to Lattice device documentation.

This is a planning estimate only.

A dedicated early synthesis spike must verify actual inference and packing before the rasterizer is implemented deeply.

## 16.3 Reset policy

Do not reset entire framebuffer/Z memories.

On reset:

- logical role IDs return to documented initial values;
- `front_valid=0`;
- display outputs black;
- future BEGIN_FRAME clears the selected RENDER colour buffer and Z buffer.

---

# 17. Command interface

Canonical graphics-core command input:

```systemverilog
input  logic        cmd_valid;
output logic        cmd_ready;
input  logic [31:0] cmd_data;
```

Canonical response output:

```systemverilog
output logic        rsp_valid;
input  logic        rsp_ready;
output logic [31:0] rsp_data;
```

Transfer occurs only on valid && ready.

UART is a transport adapter around this interface, not part of the graphics core protocol.

---

# 18. Command format

Exact bit encodings shall be frozen in `docs/COMMAND_PROTOCOL.md` before decoder RTL.

Candidate v1 opcodes:

```text
0x0 NOP
0x1 BEGIN_FRAME
0x2 DRAW_TRIANGLE
0x3 SET_SOBEL
0x4 PRESENT
0x5 READ_FRONT
0x6 GET_STATUS
0x7 GET_COUNTERS
```

Unknown opcode:

- set sticky `CMD_ERROR`;
- emit error response;
- do not corrupt current frame/buffer roles.

## 18.1 Header

Candidate header:

```text
31:28 opcode
27:16 reserved = 0
15:0  user/sequence tag
```

## 18.2 BEGIN_FRAME

Fixed packet.

Payload includes:

- RGB332 clear colour.

Behaviour:

- clear RENDER framebuffer;
- clear Z to 0xFF;
- reset per-frame counters;
- enter frame-active state.

## 18.3 DRAW_TRIANGLE

Candidate fixed size: 16 32-bit words / 64 bytes.

Contains:

- header;
- three packed Q4 vertices;
- R/G/B/Z start values;
- four X gradients;
- four Y gradients.

The precise encoding is frozen before implementation.

## 18.4 SET_SOBEL

Carries:

- threshold;
- threshold bypass.

Updates GPU wrapper desired configuration; actual Sobel configuration is written via APB before a Sobel frame begins.

## 18.5 PRESENT

Mode:

```text
NORMAL
SOBEL
```

## 18.6 READ_FRONT

Streams currently presented framebuffer contents over the response path.

Legal only in a defined idle state.

---

# 19. Command FIFO and frame-level host flow control

Baseline target:

```text
1024 x 32-bit command FIFO
```

Planning frame submission limit:

```text
<= 48 DRAW_TRIANGLE commands per frame
```

This ensures the complete normal v1 frame command list can fit inside the intended command FIFO under the fixed 64-byte triangle packet assumption.

Host interaction:

```text
submit complete frame
wait FRAME_DONE
submit next frame
```

Do not add a complex general-purpose credit protocol in v1.

The 48-triangle cap is a demo/transport scope rule, not a rasterizer architectural limit.

---

# 20. High-level controller

Recommended states:

```text
RESET
IDLE
CLEAR
FRAME_ACTIVE
TRI_SETUP
TRI_WALK
TRI_DRAIN
POSTPROCESS
PRESENT_WAIT
READBACK
ERROR_RECOVERY
```

Core legality:

- `BEGIN_FRAME` only from IDLE;
- `DRAW_TRIANGLE` only during FRAME_ACTIVE and when no previous triangle is active;
- `PRESENT` only when current triangle/fragment pipeline is fully drained;
- `READ_FRONT` only from defined idle/readback-safe state;
- new frame cannot begin before previous FRAME_DONE.

Illegal command/state pairing sets sticky error without silently modifying buffer ownership.

---

# 21. Triangle setup module

Recommended file:

```text
rtl/triangle_setup.sv
```

Responsibilities:

- coordinate validity;
- edge dx/dy;
- area;
- degenerate/backface decision;
- bounding box;
- top-left flags;
- edge X/Y increments;
- initial E0/E1/E2 at first candidate pixel centre;
- pass through attribute start/gradient fields.

Setup may take multiple cycles.

Use a shared multiplier/multi-cycle FSM where practical rather than maximizing parallel multiplier count.

Triangle setup latency is not the primary baseline performance target.

Every output field is checked against the Python model before raster integration.

---

# 22. Raster walker

Recommended file:

```text
rtl/raster_walk.sv
```

Owns:

- current X/Y;
- row/current E0/E1/E2;
- row/current R/G/B/Z;
- candidate count;
- covered count.

Baseline steady-state design target:

```text
one candidate pixel considered per clk_sys cycle
```

For each candidate:

1. classify all three edges;
2. increment candidate counter;
3. if covered, emit one fragment token with x/y/raw R/G/B/Z;
4. advance accumulators horizontally or to next row.

At end of bounding box:

- stop producing new fragments;
- wait for downstream fragment/Z pipeline to drain before the next triangle begins.

This conservative drain rule avoids inter-triangle depth hazards in the simple baseline.

---

# 23. Fragment and Z pipeline

Recommended stages:

```text
F0: accept covered fragment, quantize RGB/Z, calculate framebuffer address
F1: issue Z read, register address/colour/new_z
F2: receive old_z, compare
F3: conditionally write Z + colour
```

Framebuffer address:

```text
addr = y*320 + x
     = (y<<8) + (y<<6) + x
```

Do not instantiate a general multiplier for address calculation.

Z memory shall use an organization that cleanly supports the required read/write schedule.

Add an assertion against accidental ambiguous same-address read/write cases. If such a hazard appears, change the architecture rather than relying on undocumented/vendor-specific behavior.

---

# 24. Clear engine

Recommended file:

```text
rtl/clear_engine.sv
```

For each address `0..76799`:

- write clear colour to RENDER buffer;
- write 0xFF to Z;
- one address per system clock when active.

Colour and depth clear should happen in parallel.

Expected clear-cycle count is specified and measured.

Do not reset full RAMs via reset logic.

---

# 25. Performance counters

Minimum counters:

- frames_completed;
- triangles_submitted;
- triangles_degenerate;
- triangles_backface_rejected;
- candidate_pixels;
- covered_fragments;
- z_pass;
- z_fail;
- clear_cycles;
- render_cycles;
- triangle_setup_cycles;
- present_wait_cycles;
- sobel_cycles;
- command FIFO high watermark.

Per-frame counters reset on BEGIN_FRAME.

Counters are part of the architectural evidence system, not decorative registers.

Tests must prove counters do not alter rendered output.

---

# 26. Buffer role manager

System-domain registers:

```text
front_id
render_id
spare_id
```

Invariant:

```text
front_id != render_id
front_id != spare_id
render_id != spare_id
```

Initial roles:

```text
front  = 0
render = 1
spare  = 2
front_valid = 0
```

This invariant should be formally checked.

---

# 27. Clock domains and reset

Expected domains:

```text
clk_sys  = command/raster/Z/Sobel domain
clk_pix  = display pixel domain
clk_tmds = display serialization support as required
```

Initial system-clock target constraint:

```text
60 MHz
```

This is a target constraint, not a claimed Fmax.

Each domain gets a documented reset strategy.

Control crossings use explicit CDC structures.

Do not pass unsynchronized multi-bit control state between domains.

---

# 28. Presentation CDC handshake

Use a mailbox/toggle handshake from `clk_sys` to `clk_pix`.

System domain owns:

- requested new front buffer ID;
- request toggle;
- payload stability until acknowledgment.

Display domain:

1. synchronize request toggle;
2. detect new request;
3. wait for vertical blank boundary;
4. adopt requested front buffer;
5. set `front_valid`;
6. toggle acknowledgment.

System domain:

1. synchronize acknowledgment;
2. only then finalize role rotation;
3. emit `FRAME_DONE`.

Required safety:

- front buffer ID changes only at the defined display boundary;
- one request causes at most one acknowledgment;
- no role is reused before acknowledgment;
- payload remains stable until acknowledgment.

---

# 29. Normal presentation

Before NORMAL present:

- all triangle generation finished;
- fragment/Z pipeline empty;
- RENDER holds complete frame.

Sequence:

1. request display switch to `render_id`;
2. wait for VBlank acknowledgment;
3. rotate roles:
   - new FRONT = old RENDER;
   - new RENDER = old FRONT;
   - SPARE unchanged;
4. emit FRAME_DONE;
5. return IDLE.

---

# 30. Sobel presentation with triple buffering

The triple-buffer architecture is chosen specifically to avoid VBlank timing pressure and framebuffer conflicts.

Before SOBEL present:

```text
FRONT  = stable displayed old frame
RENDER = completed raw graphics frame
SPARE  = free destination
```

Sequence:

1. program imported Sobel APB configuration;
2. stream RENDER through Sobel;
3. write Sobel output into SPARE;
4. confirm exact expected Sobel output count/protocol;
5. request display switch to SPARE;
6. wait for VBlank acknowledgment;
7. rotate roles:
   - new FRONT = old SPARE;
   - new RENDER = old FRONT;
   - new SPARE = old RENDER;
8. emit FRAME_DONE.

During post-processing:

- display reads FRONT;
- Sobel reader reads RENDER;
- Sobel writer writes SPARE.

No colour memory has conflicting logical ownership.

This is preferred over a two-buffer/VBlank-deadline design.

---

# 31. Display path

Internal render surface:

```text
320x240 RGB332
```

Physical active output:

```text
640x480
```

Exact mapping:

```text
source_x = display_x >> 1
source_y = display_y >> 1
```

Every source pixel maps to a 2×2 block of display pixels.

No filtering.

No fractional scaler.

The display reader must explicitly account for synchronous EBR latency by delaying DE/sync/coordinate metadata to match returned pixel data.

Display/platform infrastructure may reuse selected Project F files after licence/commit review.

---

# 32. RGB332 display expansion

The display path expands RGB332 to a wider DAC/TMDS colour representation deterministically using bit replication or a frozen equivalent mapping.

The exact mapping must be documented and tested.

No gamma correction in v1.

---

# 33. Sobel RGB332→RGB888 adapter

For framebuffer pixel:

```text
R3 = pixel[7:5]
G3 = pixel[4:2]
B2 = pixel[1:0]
```

Candidate exact expansion:

```text
R8 = {R3, R3, R3[2:1]}
G8 = {G3, G3, G3[2:1]}
B8 = {B2, B2, B2, B2}
```

Properties:

- 0 maps to 0;
- maximum maps to 255;
- monotonic;
- combinational;
- reference model uses identical mapping.

The imported RTL-to-Pixels grayscale equation remains unchanged.

---

# 34. Sobel output RGB332 packing

Imported Sobel returns 8-bit edge magnitude/thresholded output.

Pack grayscale edge result:

```text
R3 = edge[7:5]
G3 = edge[7:5]
B2 = edge[7:6]
```

No extra graphics filter in this path.

---

# 35. Sobel framebuffer reader

Recommended file:

```text
rtl/sobel_fb_reader.sv
```

Reads RENDER framebuffer in raster order and emits the exact RTL-to-Pixels stream contract.

For each pixel:

- RGB332→RGB888 expansion;
- valid/ready;
- SOF on first transferred pixel only;
- EOL on final transferred pixel of each row.

Advance source coordinate/index only on:

```text
s_tvalid && s_tready
```

Because BRAM reads are synchronous, include enough elastic buffering that a downstream stall cannot drop or overwrite a returned memory word.

Steady-state target when ready:

```text
1 pixel transfer / clk_sys
```

---

# 36. Sobel framebuffer writer

Recommended file:

```text
rtl/sobel_fb_writer.sv
```

Consumes imported Sobel output stream and writes SPARE sequentially.

Advance output address only on:

```text
m_tvalid && m_tready
```

Writer owns an independent output transaction count.

It does not model internal Sobel latency.

It validates:

- first output SOF location;
- EOL every 320 outputs;
- exact 76,800 accepted outputs;
- no output past frame extent.

Protocol mismatch sets sticky error and prevents silent presentation of a malformed result.

This naturally accommodates the parent accelerator's W+1 mapping and drain behavior.

---

# 37. Sobel APB wrapper

GPU-side configuration stores desired:

- threshold;
- threshold bypass.

Before post-processing starts, a small APB master writes the imported Sobel block through its documented APB interface.

Do not poke internal Sobel signals/registers.

Configuration shall be complete before the first accepted SOF, avoiding ambiguous same-edge programming/activation behavior.

---

# 38. Readback engine

Physical correctness requires framebuffer readback.

`READ_FRONT` shall:

- be legal only in a safe idle state;
- read active FRONT framebuffer through an available system-clock memory port;
- pack four 8-bit pixels per 32-bit response word;
- transmit exactly 19,200 data words for 76,800 bytes;
- include a header/trailer/status/checksum as defined in `COMMAND_PROTOCOL.md`.

Host reconstructs raw/PNG output and compares it with the independent reference framebuffer.

Readback is correctness evidence; monitor appearance is demonstration evidence.

---

# 39. Host software architecture

Suggested structure:

```text
sw/host/
  protocol.py
  fixed.py
  transform.py
  clip.py
  triangle_compiler.py
  transport_serial.py
  demo_cube.py
  demo_mesh.py
  readback.py
```

Host responsibilities include float/high-level geometry and exact quantized command generation.

The host must preserve a reproducible mode in which a command stream can be saved and replayed.

---

# 40. Independent software reference renderer

Suggested structure:

```text
sw/reference/
  command_parser.py
  raster_reference.py
  sobel_composition.py
  image_io.py
```

Reference input is the **quantized hardware command stream**, not unquantized floating-point scene data.

For every triangle, the reference should:

1. decode command fields;
2. reproduce specified bbox and top-left semantics;
3. mathematically evaluate edge functions at each sample centre;
4. derive attributes from start + x/y gradient offsets rather than mimicking RTL accumulator cycles;
5. quantize/clamp RGB/Z exactly;
6. execute strict Z test;
7. update reference framebuffer/Z.

This keeps the reference mathematically equivalent but structurally independent.

---

# 41. Required reference-model tests before RTL

Must include:

- empty frame;
- clear colour;
- single triangle;
- flat-top triangle;
- flat-bottom triangle;
- valid winding;
- reversed winding rejection;
- zero-area triangle;
- horizontal/vertical edges;
- subpixel vertices;
- screen-corner cases;
- triangles touching/clipped to right/bottom boundary;
- two triangles forming rectangle;
- RGB interpolation;
- Z interpolation;
- near over far;
- far over near;
- equal-depth tie;
- draw-order reversal;
- deterministic random triangle frames.

Reference tests must stabilize before raster RTL.

---

# 42. RTL unit-test structure

Recommended tests:

```text
tb/tests/
  test_cmd_fifo.py
  test_cmd_decoder.py
  test_clear_engine.py
  test_triangle_setup.py
  test_top_left.py
  test_raster_walk.py
  test_attribute_step.py
  test_fragment_quantize.py
  test_depth_stage.py
  test_framebuffer_dp.py
  test_buffer_roles.py
  test_swap_cdc.py
  test_scanout_scale.py
  test_sobel_reader.py
  test_sobel_writer.py
  test_sobel_bridge.py
  test_readback.py
  test_uart_bridge.py
```

Each module receives focused self-checking verification before subsystem integration.

---

# 43. Directed raster tests

Mandatory directed cases:

- one large triangle;
- flat-top;
- flat-bottom;
- shared-edge rectangle;
- tiny/subpixel triangle;
- thin triangle;
- degenerate;
- reversed winding;
- left/top boundary;
- right/bottom boundary;
- RGB corner gradient;
- Z gradient;
- overlapping near/far;
- reversed draw order;
- equal-depth tie.

For each complete frame report:

- expected framebuffer checksum;
- actual checksum;
- colour mismatch count;
- first N mismatch coordinates;
- expected/actual RGB332;
- expected/actual Z where applicable.

A plausible image is not a pass criterion.

---

# 44. Random regression

Use deterministic seeds.

Generate legal frame command streams with:

- 1..48 triangles;
- random legal coordinates;
- random valid orientation or intentional rejection cases;
- random colour planes;
- random depth planes;
- random clear colour.

Compare RTL framebuffer and Z byte-for-byte to reference.

Any newly discovered bug gains a permanent minimized regression seed/case.

---

# 45. Command-stream stress

Randomly apply:

- source valid gaps;
- near-full FIFO conditions;
- response backpressure;
- long host idle periods.

Rendering result must not change.

Partial command packets must not execute.

---

# 46. Reset matrix

Test reset during:

- IDLE;
- frame clear;
- command packet collection;
- triangle setup;
- first candidate;
- middle candidate traversal;
- final candidate;
- fragment/Z pipeline drain;
- presentation request/await;
- CDC handshake;
- Sobel input;
- Sobel drain;
- readback.

After reset:

- `front_valid=0`;
- display black;
- no stale command resumes;
- no stale triangle resumes;
- no stale buffer swap completes;
- no stale Sobel output writes;
- role IDs are valid and unique;
- a new BEGIN_FRAME works.

---

# 47. Display verification

Before renderer integration, fill framebuffers with deterministic coordinate/pattern data.

Verify source `(x,y)` maps to exactly:

```text
(2x,   2y)
(2x+1, 2y)
(2x,   2y+1)
(2x+1, 2y+1)
```

Verify:

- 640 active pixels;
- 480 active lines;
- correct blanking behavior;
- black when `front_valid=0`;
- memory-latency/control alignment;
- no stale pixel at line/frame transitions.

---

# 48. CDC verification

Simulate unrelated `clk_sys`/`clk_pix` frequencies and randomized phase.

Randomize request timing around VBlank and reset.

Check:

- no mid-active-frame front change;
- exactly one ACK per request;
- buffer payload ID stable/correct;
- role IDs remain unique;
- no buffer reused before ACK;
- reset cannot produce a phantom presentation.

Selected properties should be formally checked.

---

# 49. Sobel integration verification

Reference composition:

```text
raw RGB332 framebuffer
  -> exact RGB332→RGB888 expansion
  -> parent project Python Sobel reference semantics
  -> 8-bit edge
  -> exact edge→RGB332 pack
  -> expected postprocessed framebuffer
```

Hardware:

```text
RENDER FB
  -> sobel_fb_reader
  -> actual imported rtl-to-pixels RTL
  -> sobel_fb_writer
  -> SPARE FB
```

Compare all 76,800 bytes.

Required test images:

- black;
- white;
- vertical edge;
- horizontal edge;
- colour gradient;
- random framebuffer;
- rendered cube/frame;
- threshold enabled;
- threshold bypass.

Also test legal stream stalls/backpressure and prove output image is unchanged.

---

# 50. Full-system regression

Run through the real command interface:

```text
BEGIN_FRAME
DRAW...
PRESENT_NORMAL

BEGIN_FRAME
DRAW...
PRESENT_NORMAL

SET_SOBEL
BEGIN_FRAME
DRAW...
PRESENT_SOBEL

BEGIN_FRAME
DRAW...
PRESENT_NORMAL
```

Use independent system/display clocks.

At each FRAME_DONE, identify the presented buffer and compare against reference.

This test covers:

- command processing;
- clear;
- raster;
- depth;
- buffer roles;
- CDC;
- normal presentation;
- Sobel presentation;
- mode transitions.

---

# 51. Targeted formal verification

Do not attempt to formally prove the whole graphics processor.

Priority blocks/properties:

## 51.1 Command FIFO

- no overwrite when full;
- ordering;
- output stability while stalled;
- token count/conservation under assumptions.

## 51.2 Buffer roles

- role IDs pairwise distinct;
- FRONT never RENDER/SPARE;
- legal role rotations only.

## 51.3 Presentation CDC

- at most one ACK per request;
- display front changes only at permitted boundary;
- payload stable until ACK;
- no phantom request after reset under stated reset assumptions.

## 51.4 Address safety

- framebuffer write/readback addresses < 76,800;
- Z addresses < 76,800;
- Sobel source/destination indices bounded.

## 51.5 Raster walker

- x/y stay within bbox;
- walker terminates for valid bbox;
- no candidate generated outside documented range.

## 51.6 Depth pipeline

- colour write implies valid covered fragment + depth pass;
- Z write implies same;
- failed Z test causes no colour/Z write.

## 51.7 Sobel bridge

- source index advances only on valid&&ready;
- destination index advances only on valid&&ready;
- no frame overrun.

Every formal result records assumptions, engine, depth/mode, result, cover/vacuity checks and limitations.

---

# 52. Early synthesis and memory feasibility gate

Before serious raster RTL, synthesize a memory spike containing:

```text
3 × 76800×8 framebuffer wrappers
1 × 76800×8 Z buffer
1 × 1024×32 command FIFO
```

Questions:

- are framebuffers inferred into EBR?
- is Z inferred into EBR?
- is FIFO implemented sensibly?
- is true dual-clock framebuffer inference supported by the chosen flow?
- what exact EBR count is produced?
- is any large memory unexpectedly mapped to LUTs?

This is a hard gate.

If memory inference does not match the architecture, revise the memory wrapper/architecture before raster implementation continues.

---

# 53. Baseline synthesis/P&R target

Initial system clock target:

```text
60 MHz
```

Do not call it achievable until route evidence exists.

Hold constant for controlled experiments:

- device/package/speed grade;
- tool versions;
- top-level wrapper;
- render dimensions;
- display configuration;
- build options;
- constraints;
- seed policy;
- measurement scripts.

Record:

- LUT/cells;
- FFs;
- EBRs;
- DSPs;
- target clock;
- worst slack;
- critical path;
- routed classification;
- triangle setup latency;
- candidate pixels/cycle;
- render cycles;
- presentation waits;
- Sobel cycles;
- derived throughput where justified.

---

# 54. Fmax procedure

Do not call one arbitrary route Fmax.

After a verified baseline:

1. find a clearly timing-clean constraint;
2. raise frequency;
3. bracket pass/fail;
4. refine at documented resolution;
5. preserve each run record;
6. document seed policy;
7. separate timing-clean routed frequency from physical measured board frequency.

---

# 55. Architecture B admission rule

Do not design the optimization architecture in advance.

Architecture B may begin only when:

- baseline full functional regression exists;
- baseline synthesis/P&R evidence exists;
- actual critical path/performance counters identify a limiting mechanism;
- a written bottleneck exists;
- one proposed change directly addresses that bottleneck;
- expected area/latency/control costs are recorded.

Possible future changes may include extra pipeline boundaries or traversal changes, but this document deliberately does not select one.

---

# 56. Optimization experiment procedure

For the one controlled optimization:

```text
A. Record baseline commit/result.
B. State observation.
C. State evidence-backed bottleneck.
D. State hypothesis.
E. Make smallest intended architectural change.
F. Run focused tests.
G. Run complete graphics/Sobel regression.
H. Run selected formal checks.
I. Synthesize/place/route with identical conditions.
J. Record timing/resources.
K. Record latency/throughput/counter changes.
L. Compare against baseline.
M. RETAIN / MODIFY / REJECT / INCONCLUSIVE.
N. Record decision.
```

Do not hide failed experiments.

---

# 57. Physical hardware bring-up order

Do not debug the entire graphics system through the monitor at once.

Bring-up order:

1. known-good Project F/board display colour bars;
2. our deterministic scanout pattern;
3. our framebuffer scanout;
4. normal buffer swap;
5. UART command path;
6. clear engine;
7. one known flat triangle;
8. hardware framebuffer readback + software comparison;
9. shared-edge rectangle;
10. colour interpolation;
11. Z pair;
12. low-poly cube;
13. Sobel bridge on deterministic framebuffer;
14. Sobel rendered frame;
15. normal/Sobel mode transitions;
16. performance counter validation.

At every stage preserve prior known-good evidence.

---

# 58. Hardware readback evidence

A physical framebuffer is considered verified only when actual bytes are read back and compared against the reference.

For a hardware test record:

- bitstream commit;
- synthesis/P&R report identifiers;
- board/device;
- test command/scene;
- readback file;
- reference file;
- mismatch count;
- first N mismatches if any;
- display photograph/video only as supplemental evidence.

A monitor that looks correct does not justify zero-mismatch claims.

---

# 59. Evidence classification

Use:

1. **SPECIFIED**
2. **ASSUMED**
3. **HYPOTHESISED**
4. **REFERENCE-MODEL VERIFIED**
5. **RTL SIMULATION VERIFIED**
6. **FORMALLY CHECKED UNDER DOCUMENTED ASSUMPTIONS**
7. **SYNTHESISED**
8. **PLACED/ROUTED TIMING-FAILING**
9. **PLACED/ROUTED TIMING-CLEAN AT STATED CONSTRAINT**
10. **PHYSICALLY FRAMEBUFFER-VERIFIED**
11. **PHYSICALLY DISPLAY-DEMONSTRATED**
12. **DERIVED**
13. **PHYSICALLY MEASURED**

Never upgrade a derived or predicted result into a measured one.

---

# 60. Repository structure

```text
from-pixels-to-polygons/
├── .github/
│   └── workflows/
├── rtl/
│   ├── gfx_pkg.sv
│   ├── cmd_fifo.sv
│   ├── cmd_decoder.sv
│   ├── clear_engine.sv
│   ├── triangle_setup.sv
│   ├── raster_walk.sv
│   ├── fragment_pipe.sv
│   ├── zbuffer.sv
│   ├── framebuffer_dp.sv
│   ├── buffer_manager.sv
│   ├── present_cdc.sv
│   ├── scanout_2x.sv
│   ├── perf_counters.sv
│   ├── readback_engine.sv
│   ├── sobel_fb_reader.sv
│   ├── sobel_fb_writer.sv
│   ├── sobel_apb_master.sv
│   ├── sobel_bridge.sv
│   ├── uart_cmd_bridge.sv
│   ├── graphics_core.sv
│   └── graphics_top_ulx3s.sv
├── ip/
│   └── rtl-to-pixels/
├── third_party/
│   └── projectf/
├── sw/
│   ├── host/
│   └── reference/
├── tb/
│   ├── drivers/
│   ├── monitors/
│   ├── tests/
│   └── images/
├── formal/
├── constraints/
├── scripts/
│   ├── sim/
│   ├── formal/
│   ├── synth/
│   ├── timing/
│   └── analysis/
├── results/
│   ├── raw/
│   └── processed/
├── reports/
├── docs/
│   ├── assets/
│   ├── debug/
│   ├── REQUIREMENTS.md
│   ├── MICROARCHITECTURE.md
│   ├── COMMAND_PROTOCOL.md
│   ├── FIXED_POINT.md
│   ├── VERIFICATION_PLAN.md
│   ├── FORMAL.md
│   ├── TIMING.md
│   ├── TRADEOFFS.md
│   ├── DECISIONS.md
│   ├── KNOWN_LIMITATIONS.md
│   ├── PROJECT_STATE.md
│   ├── EVIDENCE_INDEX.md
│   └── THIRD_PARTY_MANIFEST.md
├── examples/
├── THIRD_PARTY_NOTICES.md
├── AGENTS.md
├── Makefile
├── pyproject.toml
├── .gitignore
├── LICENSE
└── README.md
```

---

# 61. Standard command contract

Target user interface:

```text
make help
make doctor
make lint
make test-ref
make test-unit
make test-raster
make test-display
make test-sobel
make test-system
make test
make formal
make synth-memory
make synth-core
make synth
make timing
make bitstream
make program
make demo-cube
make readback
make compare-hw
make clean
```

`make doctor` prints exact paths/versions and distinguishes required/optional tools.

Do not claim a tool is installed without local evidence.

---

# 62. Git/GitHub process

`main` must remain known-good.

Example branches:

```text
feat/reference-raster
feat/memory-spike
feat/cmd-fifo
feat/triangle-setup
feat/raster-walk
feat/depth-stage
feat/presentation-cdc
feat/display
feat/sobel-bridge
feat/readback
exp/raster-pipeline-b
```

Commit meaningful reviewable states.

Do not manufacture history later.

Suggested evidence-backed tags:

```text
v0.1-contract
v0.2-reference
v0.3-raster
v0.4-system
v0.5-sobel-integration
v0.6-implementation
v0.7-hardware
v1.0-cv-ready
```

Apply only when gates actually support them.

---

# 63. CI

Grow CI gradually.

Early:

- lint/compile;
- reference pytest;
- fast unit tests.

Then:

- raster regression;
- full graphics regression;
- Sobel integration regression.

Later if practical:

- selected formal;
- 85F synthesis smoke.

Long P&R/Fmax sweeps remain manual/scheduled when appropriate.

---

# 64. Run-record template

Every meaningful implementation experiment records:

```text
Experiment ID:
Date:
Git commit:

Question:
Hypothesis:

Architecture:
Render dimensions:
Display mode:
Sobel mode/config:

Python:
Simulator:
Yosys:
nextpnr:
Target device/package/speed:
Top:
Synthesis options:
P&R options:
Seed:

Functional regression:
Formal status:

Triangles submitted:
Candidates:
Covered fragments:
Z passes/fails:
Clear cycles:
Render cycles:
Sobel cycles:
Frame/present cycles:

Resources:
LUT/cells:
FF:
EBR:
DSP:

Timing:
Constraint:
Worst slack:
Critical path:
Classification:

Derived throughput:
Physical test:
Hardware readback mismatch count:

Decision:
RETAIN / MODIFY / REJECT / INCONCLUSIVE
Reason:
Evidence files:
```

---

# 65. Decision-log template

```text
Decision ID:
Date:
Problem:
Available evidence:
Options:
Chosen approach:
Reason:
Expected trade-off:
Result:
Retained/rejected:
```

Important decisions include:

- ECP5-85F graphics target;
- 320×240 internal surface;
- RGB332;
- triple colour framebuffer;
- 8-bit Z;
- host-side geometry;
- Pineda edges;
- top-left rule;
- fixed-point formats;
- command packet format;
- frame-level flow control;
- CDC presentation mailbox;
- Project F reuse set;
- Sobel dependency commit;
- baseline/optimization boundary.

---

# 66. Risk register

| Risk | Consequence | Mitigation |
|---|---|---|
| EBR inference differs from estimate | architecture may not fit | memory synthesis spike before raster RTL |
| top-left/sign convention mismatch | cracks/double fill | directed shared-edge tests + reference |
| fixed-point overflow | wrong pixels/depth | formal range derivation + extrema tests |
| Z latency misalignment | wrong occlusion | focused stage test + first-divergence debug |
| async presentation race | tearing/role corruption | mailbox CDC + randomized phase + formal |
| display data/control latency mismatch | shifted/glitched image | standalone scanout pattern verification |
| command packet desync | arbitrary behavior | fixed packet lengths + error state + tests |
| UART limits demo rate | weak animation | small scene cap; separate GPU vs transport measurement |
| Sobel protocol mismatch | corrupted postprocess | adapters tested independently + exact count checks |
| parent IP changes | non-reproducible build | pinned commit/tag + dependency evidence |
| external reference licensing | portfolio/authorship issue | architecture-only use; manifest all reused files |
| scope creep into GPU features | non-completion | strict deferred-scope list |
| timing failure | hardware clock target missed | baseline route before optimization; one measured change |
| hardware availability | physical gate delayed | do not buy early; keep simulation/P&R evidence useful |

---

# 67. Project gates

## Gate 0 — Contract and environment known

Required:

- authoritative docs coherent;
- repository/tool state known;
- command/fixed-point/memory/CDC contracts frozen enough for reference work;
- parent Sobel dependency state known;
- no unsupported environment claims.

## Gate 1 — Reference model

Required:

- command encoder/parser;
- independent raster reference;
- top-left/shared-edge directed tests;
- depth tests;
- random deterministic frames.

## Gate 2 — Memory feasibility

Required actual synthesis:

- 3 framebuffers infer EBR;
- Z buffer infers EBR;
- command FIFO sensible;
- actual memory resource evidence recorded.

## Gate 3 — Raster primitive

Required:

- triangle setup verified;
- raster coverage matches reference;
- attribute stepping matches reference;
- no framebuffer/depth integration yet unless primitive evidence exists.

## Gate 4 — Complete colour/Z renderer

Required:

- command→framebuffer path;
- exact colour/Z comparison;
- random frames;
- counters;
- readback logic in simulation.

## Gate 5 — Display/presentation

Required:

- 2× scanout verified;
- CDC presentation verified;
- role ownership correct;
- multi-frame simulation.

## Gate 6 — Sobel integration

Required:

- pinned imported parent IP;
- parent regression evidence reviewed;
- stream adapters verified;
- APB wrapper verified;
- actual Sobel RTL frame matches composed software reference;
- triple-buffer role rotation verified.

## Gate 7 — Deep regression

Required:

- command gaps/backpressure;
- reset matrix;
- random triangles;
- multi-frame/mode transitions;
- CDC phase variation;
- requirements traceability;
- regression for every discovered defect.

## Gate 8 — Formal depth

Required:

- selected FIFO/role/CDC/address/depth/Sobel bridge properties;
- assumptions/limits documented.

## Gate 9 — Implementation baseline

Required:

- full 85F synthesis;
- route;
- resources;
- timing;
- critical path;
- baseline performance counters/derived metrics.

## Gate 10 — Physical hardware

Required:

- known-good display bring-up;
- framebuffer output;
- physical raster readback/reference comparison;
- physical Sobel readback/reference comparison;
- documented board/tool/bitstream commit.

## Gate 11 — Controlled optimisation

Required:

- measured baseline bottleneck;
- written hypothesis;
- one controlled change;
- identical verification rerun;
- identical implementation conditions;
- quantitative comparison and decision.

## Gate 12 — Public/CV-ready

Required:

- strong README;
- architecture diagram;
- reference/RTL/hardware imagery;
- diff/readback evidence;
- regression/formal summaries;
- resource/timing table;
- baseline/B comparison;
- exact commands;
- evidence index;
- limitations;
- third-party notices;
- clean-checkout reproduction;
- `v1.0-cv-ready` only after evidence is complete.

---

# 68. Detailed phase/task plan

The local/Codex sequence is intentionally narrow.

## GFX-000 — Repository bootstrap

Create skeleton, `make doctor`, Python environment, documentation placeholders, CI skeleton. No graphics RTL.

## GFX-001 — Freeze source-level contracts

Write/review REQUIREMENTS, MICROARCHITECTURE, COMMAND_PROTOCOL, FIXED_POINT, VERIFICATION_PLAN, DECISIONS, AGENTS. No raster RTL.

## GFX-002 — Python fixed-point/reference primitives

Implement coordinate/edge/top-left/bbox/fixed quantization and single-triangle reference tests.

## GFX-003 — Reference framebuffer/Z renderer

Implement BEGIN_FRAME, multiple triangles, depth, random regression.

## GFX-004 — Memory inference spike

Synthesize framebuffers/Z/FIFO. Hard gate.

## GFX-005 — gfx_pkg + command FIFO

Implement types/constants/FIFO + simulation/formal.

## GFX-006 — Command decoder

Packet collection/validation only.

## GFX-007 — Clear engine

Exact address/count/value verification.

## GFX-008 — Triangle setup

All edge/bbox/top-left/setup fields compared to Python.

## GFX-009 — Raster walker coverage only

Output covered x/y stream; compare coordinate list/mask to reference.

## GFX-010 — Attribute stepping

Add raw R/G/B/Z and compare exact fixed-point values.

## GFX-011 — Fragment/Z stage

Quantization/address/depth/write logic.

## GFX-012 — Baseline renderer integration

Full command→colour/Z framebuffer comparison; no display.

## GFX-013 — Performance counters

Add/verify counters.

## GFX-014 — Readback engine

Response packing/backpressure/count/checksum.

## GFX-015 — Display simulation

Bring in reviewed Project F platform/display support; verify scanout pattern/2× scaling.

## GFX-016 — Presentation CDC/buffer manager

Role FSM/mailbox, random clock tests, formal uniqueness.

## GFX-017 — Normal graphics system

Renderer + display + normal present, multi-frame regression.

## GFX-018 — Pin RTL-to-Pixels dependency

Import exact known-good commit and run its own regression.

## GFX-019 — Sobel stream adapters

Reader/writer/RGB adapters against mocks, with stalls.

## GFX-020 — Sobel APB wrapper

Program threshold/bypass via real interface.

## GFX-021 — Actual Sobel integration

Instantiate real imported top at 320×240 and compare frames.

## GFX-022 — Triple-buffer Sobel present

Full role rotation and mode-transition tests.

## GFX-023 — UART transport

Physical transport only after canonical command core works.

## GFX-024 — Full-system regression

Command transport model→render→display/Sobel→readback.

## GFX-025 — Formal suite

Run selected properties and document assumptions.

## GFX-026 — Full synthesis/P&R baseline

85F resource/timing evidence.

## GFX-027 — Hardware display bring-up

Colour bars→scanout pattern→framebuffer.

## GFX-028 — Hardware raster validation

Known triangles/cube + framebuffer readback/reference compare.

## GFX-029 — Hardware Sobel validation

Rendered frame→Sobel→readback/reference compare.

## GFX-030 — Baseline measurement

Measure cycles/counters/route/critical path and write bottleneck report.

## GFX-031 — Architecture experiment

One evidence-backed change only.

## GFX-032 — Publication/clean-clone validation

Freeze public evidence and reproduce from clean checkout.

---

# 69. Exact local/Codex task format

Every local task must use:

```text
TASK ID:
PROJECT PHASE:
CURRENT KNOWN-GOOD COMMIT:

OBJECTIVE:
One narrow observable result.

AUTHORITATIVE INPUTS:
Exact docs/specs.

FILES ALLOWED TO CHANGE:
Explicit list.

FILES NOT TO CHANGE:
All others unless explicitly listed.

REQUIRED IMPLEMENTATION:
Exact behavior/interfaces/widths/reset/protocol.

TESTS TO ADD/UPDATE:
Exact tests.

COMMANDS TO RUN:
Exact commands if known; otherwise inspect existing Makefile/help first.

ACCEPTANCE CRITERIA:
Observable evidence-backed conditions.

EVIDENCE TO RETURN:
- commands executed;
- exit codes;
- relevant stdout/stderr;
- test counts/results;
- report paths;
- generated artifacts;
- git diff --stat;
- git status.

CONSTRAINTS:
- no unrelated refactors;
- no silent spec changes;
- no architecture changes outside task;
- no dependency upgrades;
- no fabricated output;
- no extra commits unless requested.
```

Never send Codex "build the GPU".

---

# 70. ChatGPT/Codex responsibility split

ChatGPT owns most intellectual/project-management work:

- specification;
- microarchitecture;
- fixed-point analysis;
- command protocol;
- RTL/test drafting;
- reference-model drafting;
- formal planning;
- scripts/CI drafting;
- experiment design;
- evidence review;
- debug reasoning;
- documentation;
- next-task selection.

Codex/local execution is mainly for:

- actual repository inspection;
- applying reviewed patches;
- compiling/running tests;
- formal execution;
- Yosys/nextpnr;
- report extraction;
- Git/GitHub actions;
- real hardware/board tool commands where supported;
- returning genuine logs/evidence.

Intended loop:

```text
ChatGPT prepares narrow task
-> Codex executes locally
-> user returns Codex evidence
-> ChatGPT reviews actual evidence
-> ChatGPT decides accept/fix/next task
```

Codex is not the independent project manager.

---

# 71. Debug algorithm

For a framebuffer mismatch:

1. identify first wrong pixel;
2. identify command/triangle/tag responsible;
3. compare expected coverage;
4. compare edge values/classification;
5. compare raw R/G/B/Z;
6. compare quantization;
7. compare old Z/new Z/test decision;
8. compare write enable/address;
9. find first divergent stage;
10. minimize reproducer;
11. add regression;
12. fix smallest responsible unit;
13. rerun focused test;
14. rerun full relevant regression;
15. document educational bugs under `docs/debug/`.

Do not rewrite a subsystem merely because a frame differs.

---

# 72. Third-party manifest requirements

For every copied/derived file record:

- upstream project;
- URL;
- file path;
- commit/tag;
- original copyright;
- licence;
- unmodified/derived;
- local path;
- modifications.

Do not assume README prose/images are covered by code licences.

Prefer original diagrams/screenshots/waveforms.

---

# 73. Career-signal intent

The project should generate concrete evidence relevant to:

- RTL/SystemVerilog design;
- graphics microarchitecture;
- fixed-point computer arithmetic;
- verification/self-checking testbenches;
- formal reasoning;
- synthesis/timing/PPA;
- CDC/reset;
- memory architecture;
- HW/SW co-design;
- IP integration;
- physical validation;
- performance analysis;
- disciplined debug.

Do not add unrelated features merely to match job descriptions.

In particular, trading-specific low-level networking should be covered by a separate focused project rather than added to this graphics design.

---

# 74. Final public narrative

The final project should tell a causal story:

1. define a deliberately small graphics architecture;
2. justify it using public/reference existence proofs;
3. freeze exact raster/fixed-point/protocol semantics;
4. build an independent reference renderer;
5. verify memory feasibility before complex RTL;
6. build and verify triangle setup;
7. build and verify coverage independently;
8. add attribute/depth pipeline;
9. compare complete framebuffer/Z against software;
10. add multi-clock presentation/display;
11. integrate previously verified Sobel IP without modifying its core;
12. add physical framebuffer readback;
13. run formal checks on high-value control/protocol blocks;
14. synthesize and route the verified baseline;
15. bring up physical hardware incrementally;
16. compare hardware readback against software reference;
17. measure actual bottleneck;
18. introduce one controlled architecture change;
19. reverify/reroute/remeasure;
20. publish limitations and reproducible evidence.

That process—not simply the spinning cube—is the project.

---

# 75. Final deliverables

## Engineering

- authoritative requirements;
- microarchitecture;
- command protocol;
- fixed-point specification;
- original synthesizable RTL;
- host compiler/transport;
- independent reference renderer;
- cocotb/pytest regression;
- formal harnesses;
- build system;
- synthesis/timing scripts;
- physical readback tooling;
- baseline/B comparison;
- decision log;
- known limitations.

## Evidence

- reference-test logs;
- regression logs;
- formal reports;
- memory-inference reports;
- synthesis/resource reports;
- route/timing reports;
- critical-path reports;
- framebuffer expected/RTL/hardware/diff files;
- Sobel expected/RTL/hardware/diff files;
- performance-counter outputs;
- run records.

## Public presentation

- README;
- original architecture diagram;
- command/raster diagrams;
- normal render image;
- Sobel render image;
- physical hardware readback comparison;
- optional display photo/video;
- verification traceability summary;
- PPA/timing table;
- architecture experiment result;
- exact commands;
- third-party attribution;
- limitations;
- clean-checkout reproduction.

---

# 76. Success criterion

A fresh technical reviewer should be able to answer from the repository alone:

- What exactly does the graphics accelerator implement?
- Why is host/FPGA work split this way?
- How are triangle ownership and shared edges defined?
- What fixed-point formats are used and why are they safe?
- How are colour/depth interpolated?
- How are framebuffers organized and protected across domains?
- How is display presentation synchronized?
- How is RTL-to-Pixels integrated without violating its protocol?
- What is original versus third-party?
- How was every major requirement verified?
- What was formally checked and under what assumptions?
- What did synthesis and route actually report?
- What did physical framebuffer readback show?
- What bottleneck did the baseline have?
- Why was the optimization introduced?
- Was the baseline/B comparison fair?
- What limitations remain?
- Can the key results be reproduced?

If those questions are answerable with evidence, the project has succeeded.
