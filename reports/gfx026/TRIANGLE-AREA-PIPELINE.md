# G9-TRIANGLE-AREA-PIPELINE — GFX-026 timing correction

Starting HEAD: 058e5d8a1e26445bbe11a4fb738aece519aaf58e
Pinned Sobel dependency: ad35514c990f6e1c9eb9fa18aee9d906f9df7721 (unchanged)
Target: ULX3S reference, LFE5U-85F-6BG381C, same PLL/LPFs/clocks, static placer, router1, seed 1.

## Change

D-041 adds one registered stage relative to D-040:

1. Stage 1 captures the accepted decoded DRAW, six signed coordinate deltas and signed32 AREA operands.
2. Stage 2 uses only Stage-1 registers for AREA multiplication/subtraction, classification, exact bbox, top-left flags, edge steps and initial-edge sample-relative offsets.
3. Stage 3 computes initial edge values from registered Stage-2 data and registers the unchanged triangle_setup_result_t.

The three-stage elastic valid/ready pipeline permits output retirement and new input acceptance together. Sustained throughput remains one result per cycle. A result becomes valid after three clock edges from acceptance, one edge later than D-040. Reset clears each stage valid. No renderer RTL or parent IP changed.

## Functional evidence

- make lint-triangle-setup: exit 0 (Verilator 5.053).
- make test-triangle-setup: exit 0. 160 independent vectors (80 RASTER, 2 EMPTY, 1 DEGENERATE, 77 BACKFACE); 5,440 oracle field comparisons plus 374 directed/pipeline field comparisons, 5,814 total. No output-field mismatches.
- Testbench checks exact three-edge visibility, live input mutation after acceptance, six consecutive inputs at one/cycle, ordered draining, stalled-payload stability, reset in Stage 1, Stage 2, and stalled Stage 3, then fresh recovery.
- make test-renderer test-renderer-reset test-renderer-decoder test-renderer-counters: exit 0. Nine renderer frames and full framebuffer/Z comparisons passed. Directed renderer counter case: five submitted triangles, 9 candidates, 2 covered, 1 Z pass, 1 Z fail, 38 render cycles and 20 setup cycles.
- make test-raster-walk test-fragment-z test-clear: exit 0; raster 48 cases / 39,207 candidates, Fragment/Z 200 checks / zero memory mismatches, clear 210 checks.
- make test-command-system: exit 0; public NORMAL/SOBEL/SOBEL/NORMAL sequence, four FRAME_DONE events and 307,200 readback bytes passed. Independent public W1-W14 scoreboard passed. For four DRAWs, W10 changed 6,018→6,022 and W11 12→16 versus D-040: +1 observed renderer/setup cycle per DRAW. W1-W9 and W12-W14 matched independent event expectations.
- SOBEL_PYTHON=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 make test-sobel-integration test-sobel-controller test-sobel-modes: exit 0. Two real Sobel runs each processed 76,800 inputs/outputs/writes and had zero reference/readback mismatches; all four role transitions and tagged completions passed. Five controller reference frames passed.
- make test-sobel-adapters test-presentation test-graphics-core: exit 0; adapter counts passed, presentation phase tests passed, three NORMAL frames had zero framebuffer and scanout mismatches.
- make test-readback test-readback-framebuffer test-uart-system test-host: exit 0; full 76,800-byte readbacks and UART/host regressions passed.
- make lint-renderer lint-command-system lint-sobel-integration lint-presentation: exit 0.
- python3 -m unittest discover -s sw/reference -p 'test_*.py' -v: exit 0, 31 tests.
- make formal-gate8: exit 0. Existing selected FIFO, buffer role, raster bounds, fragment depth, Sobel address and two-clock presentation mailbox properties passed under their documented assumptions; multiclock safety and covers passed. This suite does not include triangle setup, so no triangle-setup formal claim is made.
- make doctor, make bootstrap-smoke, git diff --check: exit 0.

An initial Sobel command without the documented Python 3.11 override exited 2 before simulation because system Python lacked NumPy. It was rerun using the documented interpreter and passed. Icarus continues to print its existing “constant selects in always_* processes are not fully supported” sensitivity notices. They are simulator notices, not functional mismatches.

## Synthesis

Yosys 0.69+154 (git 30d62572e-dirty) full ulx3s_graphics_top hierarchy completed; hierarchy-check and check -assert passed. The complete source list in scripts/synth/run_ecp5.sh was used, with unique output paths:
- reports/gfx026/yosys_synth_triangle_area_pipeline.txt
- build/ecp5/ulx3s_graphics_triangle_area_pipeline.json

Synthesis resources versus D-040:

| Resource | D-040 two-stage | D-041 three-stage |
|---|---:|---:|
| LUT4 (Yosys mapped) | 7,523 | 7,579 |
| TRELLIS_FF | 6,702 | 7,277 |
| DP16KD | 156 | 156 |
| MULT18X18D | 17 | 19 |
| EHXPLLL | 3 | 3 |

The new design adds 575 FF, 56 mapped LUT4 and 2 multipliers; EBR and PLL counts are unchanged. Nextpnr packed utilization: 10,693 TRELLIS_COMB, 7,277 TRELLIS_FF, 156 DP16KD, 19 MULT18X18D, 3 EHXPLLL, 8 TRELLIS_IO. All three colour buffers/Z and the pinned Sobel hierarchy remain in the complete top.

Yosys retained the previously classified warnings: reader/selection/decoder small arrays mapped to registers; three Project F DVI reset-width resizes; experimental write_xaiger2; ABC notices. No hierarchy/check errors or new latch warning was observed.

## Place and route

Full route command (same target/constraints/settings as the prior accepted static route; outputs uniquely named):

    nextpnr-ecp5 --85k --package CABGA381 --speed 6
      --json build/ecp5/ulx3s_graphics_triangle_area_pipeline.json
      --lpf third_party/projectf/graphics/fpga-graphics/ecp5/ulx3s.lpf
      --lpf constraints/ulx3s_ftdi.lpf
      --textcfg reports/gfx026/ulx3s_triangle_area_pipeline.config
      --report reports/gfx026/nextpnr_report_triangle_area_pipeline.json
      --detailed-timing-report --placer static --router router1 --seed 1 --freq 60

The command ran under a 600-second timeout. Router1 completed 87,247 arcs in 22.09 seconds. nextpnr exited 1 because it rejected the failing 60 MHz clock requirement; the log says “Program finished normally”, with 0 warnings and 1 timing error. This is a completed route with timing failure.

| Clock | Constraint | Routed estimate | Result |
|---|---:|---:|---|
| clk_sys | 60.0024 MHz | 52.8290 MHz | FAIL |
| pixel output | 25.2048 MHz | 42.2155 MHz | PASS |
| serializer | 126.0239 MHz | 197.3165 MHz | PASS |
| intermediate PLL | 315.0598 MHz | 1053.7407 MHz | PASS |

Worst system path delay is 18.929 ns, slack approximately −2.263 ns. Compared with D-040 static route/router1/seed1 (20.336 ns, 49.1739 MHz, −3.670 ns), delay improved 1.407 ns and estimate improved 3.6551 MHz. It remains noncompliant.

The path is a same-clk_sys register-to-register triangle setup AREA path. Mapped source attributes identify Stage-1 captured geometry operands (triangle setup sequential block, rtl/triangle_setup.sv:171-196) through the Stage-2 AREA expression at line 94 to the Stage-2 prepared register in the same sequential block. Physical aliases include flattened zbuffer_i.mem names; Yosys attributes.src maps these cells to triangle setup, so those aliases do not indicate a Z-buffer logic path. The detailed path contains 41 timing nodes, 7.98 ns logic and 10.95 ns routing. Four mapped MULT18X18D cells are present along the reported cone. No timing exception was used. The new worst path is still the AREA multiply/subtract stage; this report does not establish the next-most-critical path or prove the pinned Sobel path is now comfortably below budget.

Artifacts:
- nextpnr_route_triangle_area_pipeline.txt
- nextpnr_report_triangle_area_pipeline.json.gz
- ulx3s_triangle_area_pipeline.config.gz
- yosys_synth_triangle_area_pipeline.txt

SHA-256:
- mapped netlist: f983d171460b6becae767327ebdc57cf71724759e44332e6d4a8d5853bd48f6a
- Yosys log: 3c6b6920f8ce6baf1bcedff81d313f240d31719d18dbd98e0c30dabe0c879ada
- nextpnr report JSON: 83843e34e7309aadf48127b8d13f8a8a3eacd9fb76e50a80e5643e3af2386fb5
- routed config: 86e2e41f938202925486bc01f8cdcfe6602bc1a732749af4e572eddb5b465e48
- route log: ca596a7f61afd744a3c119ba17cb3cb5d529e3d7686d6d9ed3917fccbcc13a9d

## Disposition

D-041 is implemented and the measured AREA path is shorter, with passing functional integration and unchanged D-029 result bits. The FF/multiplier cost is measurable and timing remains failing. Retain this authorized correction as the current baseline because it produces a defensible 1.407 ns routed improvement; Gate 9 remains OPEN. No bitstream was packed. Candidate/fragment throughput at compliant clocks, physical clocks, hardware, and triangle-setup formal proof remain unproven. The pinned Sobel dependency is unchanged.
