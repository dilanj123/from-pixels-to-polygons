# From Pixels to Polygons — Master Checklist

A checkbox is completed only by actual evidence, not by intent.

## Gate 0 — Contract, Dependency and Environment

- [x] master plan uploaded/accepted
- [x] operating instructions uploaded/accepted
- [x] authoritative files checked for contradictions
- [x] repository state known
- [x] Mac architecture/OS recorded
- [x] Git path/version recorded
- [x] GitHub CLI path/version/auth state recorded
- [x] Python path/version recorded
- [x] Make path/version recorded
- [x] Verilator path/version recorded
- [x] Yosys path/version recorded (missing, explicitly documented)
- [x] SBY path/version recorded (missing, explicitly documented)
- [x] formal solver(s) recorded (missing, explicitly documented)
- [x] nextpnr-ecp5 path/version recorded (missing, explicitly documented)
- [x] repository initialized
- [x] public remote requirement evaluated — not applicable at Gate 0 because GitHub authentication is invalid and remote creation has not been authorized
- [x] `make doctor` works
- [x] bootstrap known-good commit preserved
- [x] no raster RTL added during bootstrap
- [x] `docs/REQUIREMENTS.md`
- [x] `docs/MICROARCHITECTURE.md`
- [x] `docs/COMMAND_PROTOCOL.md`
- [x] `docs/FIXED_POINT.md`
- [x] `docs/VERIFICATION_PLAN.md`
- [x] `docs/DECISIONS.md`
- [x] `AGENTS.md`
- [x] coordinate system frozen
- [x] Q4 geometry frozen
- [x] edge equation frozen
- [x] accepted winding frozen
- [x] top-left rule frozen
- [x] bbox/sample-centre rules frozen
- [x] R/G/B/Z plane semantics frozen
- [x] colour quantization frozen
- [x] Z quantization/test frozen
- [x] command packet formats frozen
- [x] error semantics frozen
- [x] triple-buffer role transitions frozen
- [x] CDC presentation semantics frozen
- [x] reset semantics frozen
- [x] third-party/reference policy frozen
- [x] RTL-to-Pixels dependency policy frozen
- [x] admitted exact parent commit/tag recorded
- [x] dependency evidence recorded

Gate-0 tool-state checkboxes mean the executable state was explicitly detected
and documented. They do not mean missing tools were installed. The public-remote
checkbox remains open because GitHub authentication is invalid and no remote was
authorized or created. Later gates remain open.

## Gate 1 — Independent Reference Renderer

- [ ] fixed-point helper tests
- [ ] edge-function tests
- [ ] top-left/shared-edge tests
- [ ] bbox tests
- [ ] single-triangle reference
- [ ] multi-triangle framebuffer reference
- [ ] Z-buffer reference
- [ ] colour interpolation reference
- [ ] depth interpolation reference
- [ ] equal-depth tie test
- [ ] reversed draw order tests
- [ ] random deterministic frames
- [ ] quantized command parser/renderer stable

## Gate 2 — Memory Feasibility

Gate 2 — CLOSED; GFX-005 review accepted the recorded memory-spike evidence.

- [x] 3 × 320×240×8 framebuffer wrappers synthesized — 38 `DP16KD` each
- [x] Z buffer synthesized — 38 `DP16KD`
- [x] 1024×32 FIFO synthesized — 2 `DP16KD`
- [x] EBR inference confirmed — combined spike uses 154 `DP16KD`
- [x] dual-clock framebuffer inference reviewed
- [x] no unexpected large LUT RAM
- [x] exact EBR count recorded
- [x] graphics memory-spike resource use recorded
- [x] admitted parent resource use recorded separately
- [x] other mandatory EBR allocations recorded — none identified in this spike
- [x] combined target-device resource budget recorded against 208 LFE5U-85F
      sysMEM blocks
- [x] resource margin not invented — only the actual count comparison is recorded
- [x] memory architecture retained with GFX-004 synthesis evidence

Gate-2 note: this is representative memory-inference evidence only. It does
not close later full-synthesis, route, timing, formal, display, Sobel, or
hardware requirements.

## Gate 3 — Raster Primitive

Gate 3 — OPEN.

- [x] `gfx_pkg.sv`
- [x] command FIFO simulation
- [x] command FIFO formal under documented depth-scaled assumptions
- [x] command decoder — GFX-006 packet collection/validation simulation and
      bounded formal evidence; command execution remains out of scope
- [x] clear engine — full-depth 76,800-address simulation and reduced formal
      control/address/value properties
- [x] triangle setup — GFX-008 RTL/reference vector comparison
- [x] area/winding tests
- [x] bbox tests
- [x] top-left flags/tests
- [x] initial edge-value tests
- [ ] raster coverage-only walker
- [ ] shared-edge rectangle RTL matches reference
- [ ] subpixel/thin/extreme geometry tests
- [ ] attribute stepping matches reference

## Gate 4 — Complete Colour/Z Renderer

- [ ] fragment quantization
- [ ] framebuffer address logic
- [ ] Z read/test/write stage
- [ ] conditional colour/Z writes
- [ ] overlapping near/far tests
- [ ] draw-order reversal tests
- [ ] complete command→framebuffer simulation
- [ ] complete Z comparison
- [ ] random frame regression
- [ ] performance counters
- [ ] readback engine simulation
- [ ] no unresolved basic renderer defect

## Gate 5 — Display / Presentation

- [ ] reviewed third-party display support selected
- [ ] third-party manifest updated
- [ ] deterministic framebuffer scanout test
- [ ] exact 2× scaling test
- [ ] synchronous RAM latency aligned
- [ ] front_valid black output
- [ ] buffer-role manager
- [ ] role uniqueness simulation/formal
- [ ] CDC mailbox
- [ ] random clock phase simulation
- [ ] VBlank-only front switch
- [ ] multi-frame NORMAL presentation

## Gate 6 — RTL-to-Pixels Integration

- [ ] parent project known-good commit/tag selected
- [ ] parent regression re-run locally
- [ ] dependency pinned
- [ ] dependency evidence recorded
- [ ] RGB332→RGB888 adapter
- [ ] Sobel framebuffer reader
- [ ] Sobel framebuffer writer
- [ ] adapter random stalls
- [ ] APB master/wrapper
- [ ] threshold programming test
- [ ] bypass programming test
- [ ] actual Sobel instantiated at 320×240
- [ ] exact input pixel count
- [ ] exact output pixel count
- [ ] SOF/EOL positions checked
- [ ] W+1 alignment checked
- [ ] final-drain completion checked
- [ ] complete postprocessed framebuffer matches composed reference
- [ ] NORMAL→SOBEL transition
- [ ] SOBEL→SOBEL transition
- [ ] SOBEL→NORMAL transition
- [ ] triple-buffer role rotation verified

## Gate 7 — Deep Regression

- [ ] command valid gaps
- [ ] command FIFO stress
- [ ] response backpressure
- [ ] reset matrix
- [ ] randomized legal triangles
- [ ] randomized rejection cases
- [ ] multiple frames
- [ ] async display/system phase variation
- [ ] readback regression
- [ ] performance-counter scoreboard
- [ ] requirement→test traceability
- [ ] regression for every known functional defect

## Gate 8 — Formal Depth

- [ ] FIFO formal
- [ ] buffer-role formal
- [ ] CDC safety formal
- [ ] address-bound formal
- [ ] selected raster counter formal
- [ ] depth write implication formal
- [ ] Sobel bridge counter formal
- [ ] formal assumptions/limitations documented

## Gate 9 — Synthesis / Route Baseline

- [ ] full 85F synthesis
- [ ] full route
- [ ] LUT/cell count recorded
- [ ] FF count recorded
- [ ] EBR count recorded
- [ ] DSP count recorded
- [ ] clock constraints recorded
- [ ] worst slack recorded
- [ ] critical path recorded
- [ ] warnings reviewed
- [ ] candidate throughput measured/derived correctly
- [ ] render-cycle metrics recorded
- [ ] Sobel-cycle metrics recorded
- [ ] timing classification correct
- [ ] no unsupported Fmax claim

## Gate 10 — Physical Hardware

- [ ] current board/tool support reverified before purchase/use
- [ ] known-good display colour bars
- [ ] our scanout fixed pattern
- [ ] our framebuffer display
- [ ] UART transport
- [ ] hardware clear
- [ ] single flat triangle
- [ ] triangle framebuffer readback/reference compare
- [ ] two-triangle shared-edge hardware test
- [ ] Z pair hardware test
- [ ] low-poly cube hardware test
- [ ] Sobel deterministic hardware test
- [ ] Sobel readback/reference compare
- [ ] mode transitions on hardware
- [ ] physical evidence classified correctly

## Gate 11 — Controlled Optimisation

- [ ] baseline bottleneck measured
- [ ] bottleneck written in decision log
- [ ] hypothesis documented
- [ ] expected benefit/cost documented
- [ ] only intended files/architecture changed
- [ ] focused tests rerun
- [ ] full regression rerun
- [ ] formal subset rerun where relevant
- [ ] synthesis/P&R rerun under identical conditions
- [ ] resources compared
- [ ] latency compared
- [ ] timing compared
- [ ] candidate/fragment throughput compared
- [ ] conclusion RETAIN/MODIFY/REJECT/INCONCLUSIVE

## Gate 12 — Public / CV-ready

- [ ] strong README
- [ ] original architecture diagram
- [ ] original raster/pipeline diagram
- [ ] normal reference image
- [ ] normal RTL image
- [ ] hardware readback image
- [ ] diff image
- [ ] Sobel reference image
- [ ] Sobel RTL/hardware image
- [ ] regression summary
- [ ] formal summary
- [ ] resource/timing table
- [ ] baseline/B comparison
- [ ] exact commands
- [ ] performance counters/results
- [ ] limitations
- [ ] evidence index
- [ ] MIT licence for original work
- [ ] third-party notices/manifest
- [ ] CI
- [ ] clean-checkout reproduction
- [ ] `v1.0-cv-ready` only after evidence complete
