# From Pixels to Polygons — Master Checklist

A checkbox is completed only by actual evidence, not by intent.

## Gate 0 — Contract, Dependency and Environment

- [ ] master plan uploaded/accepted
- [ ] operating instructions uploaded/accepted
- [ ] authoritative files checked for contradictions
- [ ] repository state known
- [ ] Mac architecture/OS recorded
- [ ] Git path/version recorded
- [ ] GitHub CLI path/version/auth state recorded
- [ ] Python path/version recorded
- [ ] Make path/version recorded
- [ ] Verilator path/version recorded
- [ ] Yosys path/version recorded
- [ ] SBY path/version recorded
- [ ] formal solver(s) recorded
- [ ] nextpnr-ecp5 path/version recorded
- [ ] repository initialized
- [ ] public remote created if authorized/authenticated
- [ ] `make doctor` works
- [ ] bootstrap known-good commit preserved
- [ ] no raster RTL added during bootstrap
- [ ] `docs/REQUIREMENTS.md`
- [ ] `docs/MICROARCHITECTURE.md`
- [ ] `docs/COMMAND_PROTOCOL.md`
- [ ] `docs/FIXED_POINT.md`
- [ ] `docs/VERIFICATION_PLAN.md`
- [ ] `docs/DECISIONS.md`
- [ ] `AGENTS.md`
- [ ] coordinate system frozen
- [ ] Q4 geometry frozen
- [ ] edge equation frozen
- [ ] accepted winding frozen
- [ ] top-left rule frozen
- [ ] bbox/sample-centre rules frozen
- [ ] R/G/B/Z plane semantics frozen
- [ ] colour quantization frozen
- [ ] Z quantization/test frozen
- [ ] command packet formats frozen
- [ ] error semantics frozen
- [ ] triple-buffer role transitions frozen
- [ ] CDC presentation semantics frozen
- [ ] reset semantics frozen
- [ ] third-party/reference policy frozen
- [ ] RTL-to-Pixels dependency policy frozen
- [ ] admitted exact parent commit/tag recorded
- [ ] dependency evidence recorded

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

- [ ] 3 × 320×240×8 framebuffer wrappers synthesized
- [ ] Z buffer synthesized
- [ ] 1024×32 FIFO synthesized
- [ ] EBR inference confirmed
- [ ] dual-clock framebuffer inference reviewed
- [ ] no unexpected large LUT RAM
- [ ] exact EBR count recorded
- [ ] graphics memory-spike resource use recorded
- [ ] admitted parent resource use recorded
- [ ] other mandatory EBR allocations recorded
- [ ] combined target-device resource budget recorded
- [ ] resource margin not invented
- [ ] memory architecture retained/revised with decision record

## Gate 3 — Raster Primitive

- [ ] `gfx_pkg.sv`
- [ ] command FIFO simulation
- [ ] command FIFO formal
- [ ] command decoder
- [ ] clear engine
- [ ] triangle setup
- [ ] area/winding tests
- [ ] bbox tests
- [ ] top-left flags/tests
- [ ] initial edge-value tests
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
