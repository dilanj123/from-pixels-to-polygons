# GFX-026 — ECP5 implementation baseline attempt

Date: 2026-11-04
Starting repository commit: `eb4e18a587f03f19c61f4c91451ae6358f2c8389`
Implementation commit: `be25ccb` (`Add ULX3S ECP5 baseline build`)
Result: **full hierarchy synthesized; placement-stage timing estimate fails; full route not completed; Gate 9 remains OPEN.**

## Target and assumptions

- Reference target: ULX3S-85F, `LFE5U-85F-6BG381C`, nextpnr `--85k --package CABGA381 --speed 6`.
- Board revision is not known. The selected FTDI pin mapping follows the ULX3S v2.0 LPF and is assumed to apply to ULX3S v2.x.x/v3.0.x. No board ownership or physical test is claimed.
- Nominal board reference: 25 MHz. The three PLL stages preserve the required 60 MHz system clock, 25.2 MHz pixel clock and 126 MHz serializer clock. PLL parameter calculations and nextpnr's derived clock report are in the build log; ecppll's calculation and a small nextpnr PLL smoke build accepted the settings. This is tool-model evidence, not physical PLL measurement.
- Stage settings in `rtl/board/ulx3s_graphics_top.sv`: 25→300/60 MHz (`CLKI_DIV=1, CLKFB_DIV=12, CLKOP_DIV=2, CLKOS_DIV=10`); 300→315 MHz (`20,21,2,2`); 315→126/25.2 MHz (`5,2,5,25`). Nominal VCO/PFD pairs are 600/25 MHz, 630/15 MHz and 630/63 MHz.
- `ecppll` calculations: `ecppll -i 25 -o 300 --clkout1 60`; `ecppll -i 300 -o 315 --clkout1 315`; `ecppll -i 315 -o 126 --clkout1 25.2`. Outputs match the wrapper's divider settings. The PFD figures are reference frequency divided by the input divider. Lattice ECP5 DS FPGA-DS-02012 v3.4 Table 3.23 lists 8–400 MHz input, 3.125–400 MHz output, 400–800 MHz VCO and 10–400 MHz PFD ranges; TN-02200 v1.4 describes the PLL input paths and multiple PLL resources. Tool legality does not establish oscillator tolerance, lock behavior on a physical board, jitter, or timing closure.
- Clock-model note: nextpnr's derived-clock summary displays the intermediate as 315.1 MHz (the max-frequency row uses 315.06 MHz) while `ecppll` reports nominal 315 MHz; nextpnr displays the pixel clock as 25.2 MHz. This small tool-model/rounding discrepancy is not resolved here and must be checked before claiming exact generated physical clocks.
- UART divider: `CLKS_PER_BIT=521`; nominal baud at 60 MHz is 115,163.15 baud (−0.0320% from 115,200).
- D-036 display timing and the graphics RTL were not changed.

## Clock and board source provenance

Project F source is pinned at `dd212c2e5e0e0d8bdcf93ba077630dbfd49ae708`; the ECP5 clock wrapper, ECP5 DVI generator, TMDS encoder and ULX3S LPF were copied byte-for-byte and remain unmodified. SHA-256 values and notices are in `docs/THIRD_PARTY_MANIFEST.md` and `THIRD_PARTY_NOTICES.md`. The separate FTDI pin file transcribes L4/M1 from `emard/ulx3s` commit `6a92cec6b177191c5b0f80e260013a1f8ec147dd`; it does not copy that LPF or board artwork. The pinned Sobel submodule remains `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`.

## Toolchain and synthesis

Toolchain from `/Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment`:

- Yosys 0.69+154, git `30d62572e` (environment build reports dirty).
- nextpnr-ecp5 0.11.1-34-gc4fbb55a.
- ecppack/Trellis 1.4-83-g65fe191.

Command: `make synth-ecp5` — **exit 0**. Exact Yosys source list and complete log: `reports/gfx026/yosys_synth.txt`. The top is `ulx3s_graphics_top`; hierarchy checking and `check -assert` report zero problems. The full graphics/UART/Sobel hierarchy is present. All inferred generic memories were mapped; the RAM count includes the three colour buffers, Z storage, and parent line buffers.

Mapped counts from the nextpnr packed-netlist report (capacity from the selected device):

| Resource | Used / capacity | Notes |
|---|---:|---|
| LUT4 | 38,481 / 83,640 (46%) | Includes carry cells in nextpnr's LUT4 total; Yosys separately reports 36,015 LUT4 plus 1,233 CCU2C. |
| FF | 38,778 / 83,640 (46%) | TRELLIS_FF. |
| EBR | 154 / 208 (74%) | DP16KD. |
| 18×18 multipliers | 11 / 156 (7%) | MULT18X18D. |
| PLL | 3 / 4 (75%) | EHXPLLL. |
| Serializer | 3 ODDRX1F; 3 SIOLOGIC | DVI data lanes. |
| I/O | 8 / 365 (2%) | Before completed route. |

The production framebuffer/Z and Sobel line memories map to DP16KD. Yosys reports the 1024×32 command FIFO array as replaced by registers in this full-chip flow; it is not counted among the 154 EBRs. This is recorded as an implementation observation, not corrected in this baseline task. The shallow reader queue, decoder packet storage and framebuffer-selection helper arrays also become registers.

Reviewed synthesis warnings: the above memory-to-register conversions; three upstream Project F unsized `.RST(0)` connections resized 32→1 bits; Yosys `write_xaiger2` experimental-feature notice; and ABC internal fanout/carry/combinational-network notices. No missing module, inferred-latch or `check -assert` failure was reported. The upstream Project F source was not edited to silence width warnings.

## Placement and routing attempts

`make route-ecp5` uses the full mapped netlist, both LPFs, nextpnr seed 1, `--freq 60`, static placer and router1. It begins with the complete design and reports the packed resource counts above. The static placement-stage estimate reports:

| Clock | Target | Placement-stage estimated maximum | Result |
|---|---:|---:|---|
| `clk_sys` | 60 MHz | 20.38 MHz | FAIL |
| `clk_pix` output | 25.2 MHz | 26.91 MHz | PASS at placement stage |
| serializer | 126 MHz | 160.64 MHz | PASS at placement stage |
| intermediate PLL clock | 315 MHz | 995.02 MHz | PASS at placement stage |

These are placement estimates, not routed timing. The nextpnr log gives maximum-delay summaries between clock/asynchronous groups, but no completed detailed critical-path report was emitted. **Worst routed slack and critical-path start/end are unavailable.** No timing-clean or Fmax claim is made.

Three controlled routing attempts are retained:

1. Heap placer + router1: placement completed with system estimate 32.52 MHz, but router1 made impractically slow progress; manually interrupted after about 4m48s (exit 130). `nextpnr_router1_incomplete.txt`.
2. Heap placer + router2: nextpnr aborted with an uncaught C++ `std::out_of_range` vector exception after packing/placement (exit 2). `nextpnr_router2_abort.txt`.
3. Static placer + router1: placement completed, system estimate 20.38 MHz; after roughly two minutes of routing, about 194,839 of 206,981 arcs remained and progress was not practical, so it was interrupted (exit 130). `nextpnr_route.txt`.

No completed routed configuration, nextpnr JSON report or bitstream was produced. `ecppack` was not run. Route outcome is **NOT COMPLETED**; timing is already failing at placement for the latest placement. This is not a proof that routing is impossible, but the current baseline does not satisfy the Gate-9 route/timing criteria.

## Functional regression and other evidence

The successful command was `make test-command-system test-uart test-uart-system test-host test-presentation test-graphics-core test-sobel-integration test-sobel-controller test-sobel-modes test-sobel-adapters test-renderer test-renderer-reset test-renderer-decoder test-renderer-counters test-readback test-readback-framebuffer test-memory-wrappers test-fragment-z test-raster-walk test-triangle-setup test-clear test-decoder test-fifo SOBEL_PYTHON=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3` (exit 0). It passed using Python 3.11.4 with NumPy 1.25.2 for Sobel vector generation. The initial aggregate attempt using the OSS CAD Suite Python 3.11.6 lacked NumPy and stopped at `test-sobel-integration` (aggregate exit 2); no RTL test failed. Successful log: `reports/gfx026/functional_regression.log`.

- Full command/UART/presentation/graphics-core and Sobel integration/adapters/controller/modes tests, renderer/reset/decoder/counters tests, readback and framebuffer tests, fragment/Z, raster, triangle setup, clear, decoder and FIFO targets: all pass (aggregate make exit 0).
- Four-mode public command sequence NORMAL→SOBEL→SOBEL→NORMAL: pass; full Sobel outputs and readbacks have zero byte mismatch; full scanout comparisons have zero mismatch.
- Python reference suite: 31/31 pass, using `/Library/Frameworks/Python.framework/Versions/3.11/bin/python3`.
- Lint group (`lint-command-system`, `lint-uart`, `lint-presentation`, `lint-sobel-adapters`, `lint-sobel-integration`, `lint-renderer`, `lint-perf-counters`, `lint-readback`): exit 0.
- `make doctor`, `make bootstrap-smoke`: exit 0.
- `make formal-gate8`: exit 0. This re-runs the selected FIFO, role, raster, depth, Sobel bounds and two-clock presentation proofs/covers. The presentation mailbox/roles two-clock BMC passed at depth 32; transaction covers passed at depth 48. Captured SBY logs/status files are in `reports/gfx026/formal/`. Digital formal modelling only, not metastability/MTBF proof.
- `git diff --check`: pass at final review.

Selected simulation counter observations retained by the passing public command regression include a draw scenario with 6,014 render cycles and a Sobel scenario with 151,072 Sobel cycles. These are RTL simulation counter readings, not measured board throughput. No hardware throughput is derived because 60 MHz timing is not met.

## Gate-9 disposition

Gate 9 remains **OPEN**. Full-chip synthesis is established and resources are recorded. Required full routing, routed slack/path, and timing closure are not established; throughput baseline metrics are not complete. No bitstream, programming, physical video, or hardware evidence exists. The next task should investigate the placement-stage `clk_sys` timing path and nextpnr routing behavior without changing the frozen architecture or claiming optimization results.
