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
- [x] public remote requirement evaluated at Gate 0; remote was unavailable then. Repository was subsequently published as https://github.com/dilanj123/from-pixels-to-polygons
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
checkbox records the historical Gate-0 condition. The repository was subsequently
published as https://github.com/dilanj123/from-pixels-to-polygons, with `main`
synchronized to `origin/main`. Later gates remain open.

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

Gate 3 — CLOSED based on GFX-005 through GFX-010 primitive evidence.

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
- [x] raster coverage-only walker — GFX-009 RTL/reference sequence comparison
- [x] shared-edge rectangle RTL matches reference
- [x] subpixel/thin/extreme geometry tests
- [x] attribute stepping matches reference — GFX-010 signed42 raw-attribute comparison

## Gate 4 — Complete Colour/Z Renderer

- [x] fragment quantization — GFX-011 standalone RTL/reference simulation
- [x] framebuffer address logic — GFX-011 standalone RTL/reference simulation
- [x] Z read/test/write stage — GFX-011 synchronous-memory simulation
- [x] conditional colour/Z writes — GFX-011 strict-depth simulation
- [x] overlapping near/far tests — GFX-012 full-frame comparison
- [x] draw-order reversal tests — GFX-012 depth-order coverage
- [x] complete command→framebuffer simulation — GFX-012 decoded-command renderer
- [x] complete Z comparison — GFX-012 full 76800-byte comparison
- [x] random frame regression — GFX-012 deterministic frame suite
- [x] performance counters — GFX-013 reusable bank, passive instrumentation, and renderer scoreboard
- [x] readback engine simulation — GFX-014 standalone, production-framebuffer, and renderer-frame readback tests
- [x] no unresolved basic renderer defect — GFX-012 full-frame regressions and GFX-014 source/renderer compositions pass

## Gate 5 — Display / Presentation

- [x] reviewed third-party display support selected — D-036 pinned Project F timing source
- [x] third-party manifest updated — GFX-015 exact source/license provenance recorded
- [x] deterministic framebuffer scanout test — GFX-015 complete raster comparison
- [x] exact 2× scaling test — GFX-015 all 307,200 active pixels
- [x] synchronous RAM latency aligned — GFX-015 production framebuffer simulation
- [x] front_valid black output — GFX-015 full-frame invalid-front check
- [x] buffer-role manager — GFX-016 system/pixel role state and three physical framebuffer integration
- [x] role uniqueness simulation/formal — GFX-016 phase-varied assertions and NORMAL swap checks (simulation; formal not run)
- [x] CDC mailbox — GFX-016 one-outstanding stable-payload toggle request/ack simulation
- [x] random clock phase simulation — GFX-016 deterministic unrelated clock periods and three starting phases
- [x] VBlank-only front switch — GFX-016 safe raster-origin event checks, no switch outside event
- [x] multi-frame NORMAL presentation — GFX-017 three complete reference-rendered frames

## Gate 6 — RTL-to-Pixels Integration

- [x] parent project known-good commit/tag selected — exact v1.0.1 tag/commit
- [x] parent regression re-run locally — lint, unit, integration, and 320×240 suites
- [x] dependency pinned — immutable Git submodule pointer at admitted SHA
- [x] dependency evidence recorded — interface/parameter results and rights status
- [x] RGB332→RGB888 adapter — full-frame reader transfer checked
- [x] Sobel framebuffer reader — sync read, 76,800 addresses/transfers, metadata
- [x] Sobel framebuffer writer — 76,800 writes, conversion and malformed metadata
- [x] adapter backpressure/reset checks — deterministic reader stalls and abort
- [x] APB master — CONTROL/THRESHOLD setup/access and PREADY/PSLVERR
- [x] threshold programming test
- [x] bypass programming test — asserted and cleared
- [x] actual Sobel instantiated at 320×240 — GFX-021 controller/core and graphics composition
- [x] exact input pixel count — 76,800 in adapter mock and parent 320×240 tests
- [x] exact output pixel count — 76,800 writer transfers and parent outputs
- [x] SOF/EOL positions checked — every accepted pixel in adapter and parent tests
- [x] W+1 alignment checked — pinned parent full-frame reference comparisons at 320×240
- [x] final-drain completion checked — parent streaming drain-backpressure regression
- [x] complete postprocessed framebuffer matches composed reference — five complete frames, 76,800 bytes each, zero mismatches
- [x] NORMAL→SOBEL full graphics-core mode sequence — bounded repeated-mode integration; normal scanout, Sobel reference and readback comparisons pass
- [x] SOBEL→SOBEL full graphics-core mode sequence — second actual parent frame, correct roles, full reference and readback comparisons
- [x] SOBEL→NORMAL full graphics-core mode sequence — final renderer frame and full scanout comparison pass
- [x] triple-buffer role rotation verified — pairwise uniqueness throughout NORMAL/SOBEL transitions

Gate 6 — CLOSED. The bounded graphics-core NORMAL→SOBEL→SOBEL→NORMAL
integration passes with the real pinned parent, complete Sobel frame and
readback comparisons, normal scanout comparisons, expected role transitions,
and exactly one tagged completion per presentation. Formal, synthesis/P&R,
timing, and hardware evidence are not claimed.

## Gate 7 — Deep Regression

- [x] command valid gaps — decoder tests and public command-path packet atomicity
- [x] command FIFO stress — 1024-word fill/drain and ordering regression
- [x] response backpressure — public command-system test stalls every word of FRAME_DONE, ERROR, STATUS and COUNTERS, plus selected READ_FRONT header/data/trailer words; exact order and stability checked
- [x] reset matrix — incomplete command, active clear, pending presentation, active Sobel, stalled READ_FRONT; verifies idle/roles/front_valid/counter reset; Gate-5 test covers reset after pixel switch before system ACK
- [x] randomized legal triangles — renderer fixed-seed reference comparisons
- [x] randomized rejection cases — decoder malformed/resynchronization regression
- [x] multiple frames — public NORMAL/SOBEL/SOBEL/NORMAL command-path sequence
- [x] async display/system phase variation — three Gate-5 deterministic phase cases
- [x] readback regression — four public-path full-frame readbacks plus GFX-014 regression
- [x] performance-counter scoreboard — independent public-path event/cycle model checks W1–W14 at three snapshots, including snapshot stability while live FIFO watermark rises
- [x] fatal Sobel recovery — testbench-injected existing Sobel error boundary; public tagged ERROR, no writes/role rotation, local rearm and subsequent NORMAL completion
- [x] requirement→test traceability — G7-G8 evidence report
- [x] regression for every known functional defect — illegal active-state query regression

## Gate 8 — Formal Depth

- [x] FIFO formal — depth-4 scalar ghost queue, bounded depth 12
- [x] buffer-role formal — role uniqueness/tagged completion, bounded depth 16
- [x] CDC safety formal — separate symbolic clock events; two-clock digital safety BMC depth 32 and transaction covers depth 48; no analog metastability claim
- [x] address-bound formal — Sobel reader/writer address and transfer sequence PDR
- [x] selected raster counter formal — reduced 4×3 bbox, bounded depth 12
- [x] depth write implication formal — bounded depth 8
- [x] Sobel bridge counter formal — reader/writer accepted address ordering PDR
- [x] formal assumptions/limitations documented — G7-G8 evidence report

Gate 7 — CLOSED. Gate 8 — CLOSED for the selected bounded and inductive
property set recorded in `results/processed/G7-G8-SYSTEM-VERIFY.md`. The
two-clock CDC result is a digital interleaving model, not analog metastability
or MTBF evidence. Gate 9 remains open.

## Gate 9 — Synthesis / Route Baseline

- [x] full 85F synthesis — complete `ulx3s_graphics_top`; Yosys hierarchy/check passed, `reports/gfx026/yosys_synth.txt`
- [x] full route — FIFO-corrected netlist; router1 completed; `clk_sys` timing fails
- [x] LUT/cell count recorded — original 38,481; FIFO-corrected baseline 9,822 pre-pack LUT4; D-040 10,511 TRELLIS_COMB (Yosys 7,523 LUT4); D-041 10,693 (7,579 LUT4); D-042 10,616 (7,466 LUT4)
- [x] FF count recorded — original 38,778; FIFO-corrected baseline 6,011 TRELLIS_FF; D-040 6,702; D-041 7,277; D-042 7,888
- [x] EBR count recorded — original 154; corrected 156 DP16KD; D-040/D-041/D-042 remain 156
- [x] DSP count recorded — FIFO-corrected baseline 11; D-040 17; D-041/D-042 19 MULT18X18D
- [x] clock constraints recorded — nominal 25 MHz input and PLL-derived 60/25.2/126 MHz; D-039 and GFX-026 report
- [x] worst slack recorded — FIFO-corrected baseline approximately −8.851 ns; D-040 approximately −3.670 ns; D-041 approximately −2.263 ns; D-042 −2.881 ns at target 60 MHz
- [x] critical path recorded — D-041: triangle AREA; D-042 reported worst: reader pixel FIFO through pinned Sobel grayscale/window/arithmetic to arithmetic-elastic register. D-042 report is worst-path-only and does not establish complete path ranking.
- [x] warnings reviewed — original FIFO mem2reg diagnosed/fixed; remaining memory conversions, upstream DVI RST width resize and tool notices classified in GFX-026 report
- [ ] candidate throughput measured/derived correctly
- [x] render-cycle metrics recorded — public counter scoreboard scenario tag `0x1028`: D-041 W10=6,022; D-042 W10=6,026
- [x] Sobel-cycle metrics recorded — public counter scoreboard scenario tag `0x1015`: W13=151,072 cycles
- [x] timing classification correct — D-041 and D-042 static routes completed; D-042 `clk_sys` estimate 51.1587 MHz fails 60 MHz; no timing-closure claim
- [x] no unsupported Fmax claim

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
