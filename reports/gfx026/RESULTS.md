# GFX-026 — ECP5 implementation baseline and FIFO corrective investigation

Date: 2026-11-04
Starting repository commit: `eb4e18a587f03f19c61f4c91451ae6358f2c8389`
Implementation commit: `be25ccb` (`Add ULX3S ECP5 baseline build`)
Original baseline result: **full hierarchy synthesized; the register-expanded FIFO made routing impractical; Gate 9 remained OPEN.**

Current corrective result (starting from `45672e74d515a6e237332dba4f9d0cd23964cda6`): the FIFO now maps to two DP16KD blocks, full synthesis and full routing complete, but the routed `clk_sys` estimate is 39.19 MHz against 60 MHz. Result: **PLACED/ROUTED — TIMING FAILING; Gate 9 remains OPEN.** Original baseline logs and results below are retained unchanged as historical evidence.

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

## Corrective investigation — production command FIFO EBR mapping

Starting commit: `45672e74d515a6e237332dba4f9d0cd23964cda6`. FIFO correction commit: `5cb5e00a4a7269ec9eb15ff6d1d0cc2b426c5db7`. The pinned Sobel dependency remains `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`. The only functional RTL and test changes are `rtl/cmd_fifo.sv` and `tb/tests/cmd_fifo_tb.sv`; FIFO capacity and public ready/valid interface remain 1024×32.

### Diagnosis and correction

The original production FIFO placed the dynamic memory write, `mem[rd_ptr+1]` read, pointer/count logic and asynchronously reset `out_data` in one `always_ff @(posedge clk_sys or posedge rst)` process. Yosys emitted `Replacing memory \\mem with list of registers` in the Verilog frontend, before ECP5 memory mapping. A standalone synthesis of the original source from the starting commit, stopped after ECP5 `map_ram`, shows 1,024 32-bit `$dffe` words (32,768 data bits), no `DP16KD`, and no remaining memory for `memory_libmap`. This establishes an RTL inference-pattern/reset-process cause, rather than a missing synthesis-flow option. The GFX-004 spike's simple synchronous FIFO memory used a separate unreset RAM process and mapped to two EBRs.

The production correction separates the synchronous RAM read/write process from asynchronously reset FIFO control. Its RAM read-data register is separate from a first-word bypass register; this lets Yosys infer the registered RAM read without the bypass-data mux. An empty-to-nonempty push still supplies the first word immediately through the bypass register. When a queued head transfers and more words remain, the next word is synchronously read on that same edge. Output is stable under stalls, simultaneous push/pop, full behavior, order and pointer wrap are preserved, and no extra output bubble is added. RAM contents are not reset. `out_data` is zero while invalid; as specified by ready/valid, only data with `out_valid=1` is meaningful.

Standalone corrected command:

```text
yosys -p 'read_verilog -sv rtl/cmd_fifo.sv; hierarchy -top cmd_fifo; synth_ecp5 -top cmd_fifo -json /tmp/gfx026_cmd_fifo_corrected.json; stat'
```

It exits 0 and maps the actual 1024×32 production FIFO to 2 `DP16KD` and 64 `TRELLIS_FF`, without a memory-to-register warning. Reports: `cmd_fifo_original_map.txt` and `cmd_fifo_ebr_standalone.txt`.

### Corrected full-chip synthesis

`make synth-ecp5` exits 0 with the unchanged ULX3S source list and device. Corrected full log: `yosys_synth_fifo_ebr.txt`. Original baseline files remain unchanged. Tool: Yosys 0.69+154, git `30d62572e` (environment build reports dirty).

| Resource | Original full-chip baseline | FIFO-corrected full-chip synthesis |
|---|---:|---:|
| LUT4 (nextpnr pre-pack total) | 38,481 | 9,822 |
| FF | 38,778 | 6,011 |
| DP16KD | 154 | 156 |
| MULT18X18D | 11 | 11 |
| EHXPLLL | 3 | 3 |

The two additional EBRs are the command FIFO. Existing framebuffer/Z and Sobel memories remain present; the full graphics/UART/parent hierarchy remains elaborated. Yosys hierarchy and `check -assert` report no problems. There is no FIFO-to-register warning in the corrected full log. Remaining array-to-register warnings are for the small Sobel reader queue, renderer selection helper arrays and decoder packet storage. Other reviewed notices are three Project F `.RST(0)` width resizes, experimental `write_xaiger2`, and ABC diagnostics.

### Placement and completed route

The corrected netlist uses the same ULX3S-85F reference, LFE5U-85F-6BG381C / CABGA381 speed grade 6, both LPFs, seed 1, static placer, router1, and existing `--freq 60`. No target, clock constraint or seed was relaxed.

| Clock | Target | Placement-only estimate | Completed-route estimate |
|---|---:|---:|---:|
| `clk_sys` | 60 MHz | 38.92 MHz — FAIL | 39.1896 MHz — FAIL |
| pixel output | 25.2 MHz | 31.80 MHz — PASS | 39.8470 MHz — PASS |
| serializer | 126 MHz | 149.14 MHz — PASS | 217.6752 MHz — PASS |
| intermediate PLL clock | 315.06 MHz | 995.02 MHz — PASS | 1053.7407 MHz — PASS |

The original placement estimate was 20.38 MHz on `clk_sys`; the FIFO correction raises it to 38.92 MHz. Router1 completed all 71,351 arcs in 16.36 seconds after the static placer/SA stage (SA reports 25.69 seconds). Routing progress is no longer blocked, but the system clock still misses the target.

The routed timing JSON reports a worst `clk_sys` path of 25.517 ns against a 16.666 ns period, approximately **−8.851 ns slack**. The path has 133 timing arcs: 1 clock-to-Q, 66 routed nets, 65 logic arcs and 1 setup. Its reported source is the Sobel APB `run_enable_o` register; its endpoint is a renderer Z-buffer write-side element. It traverses carry-chain/multiplier-related mapped cells and is not a FIFO path. Detailed output: `nextpnr_route_fifo_ebr.txt` and compressed `nextpnr_route_fifo_ebr.json.gz`; compressed routed config: `ulx3s_graphics_fifo_ebr.config.gz`.

Classification: **PLACED/ROUTED — TIMING FAILING**. No bitstream was generated because the frozen 60 MHz system target is unmet. No timing-clean, physical-clock, Fmax or hardware claim is made.

### PLL report precision

`ecppll` accepts the unchanged 25→300/60, 300→315 and 315→126/25.2 MHz calculations. nextpnr reports 315.059845 MHz (displayed period 3.174 ns), while the nominal 315 MHz period is 3.174603 ns. The 0.000603 ns period representation difference explains the ~0.06 MHz report difference (~0.02%); no divider or constraint change is justified. This is tool-model precision, not a physical clock measurement or PLL-lock test.

### Corrective regressions

- `make lint-fifo`, `make test-fifo`, `make formal-fifo`, `make test-decoder`, and `make test-command-system`: pass. FIFO simulation covers full/empty, ordering, wrap, stalls, simultaneous push/pop, and asynchronous reset during partial occupancy followed by recovery. Depth-4 FIFO BMC at depth 12 passes with the independent ghost queue and output-stability properties; Z3 runtime was about 78 seconds.
- Full relevant functional batch exits 0: public command-system, UART/UART-system/host, presentation, graphics-core, Sobel integration/controller/modes/adapters, renderer/reset/decoder/counters, readback/framebuffer, wrappers, Fragment/Z, raster, triangle setup, clear, decoder and FIFO. Public NORMAL/SOBEL/SOBEL/NORMAL and complete framebuffer/readback comparisons remain passing.
- `make formal-gate8` exits 0, including FIFO, role, raster, depth, Sobel bounds and two-clock presentation safety/cover.
- Relevant lint exits 0; Python reference suite exits 0; `make doctor` and `make bootstrap-smoke` exit 0. Logs: `functional_regression_fifo_ebr.log`, `formal_gate8_fifo_ebr.log`, `lint_fifo_ebr.log`.

The reports are digital verification/implementation-tool evidence only. No graphics algorithm, clock, constraint, target, or architecture was changed; no Gate-11 experiment was started. Gate 9 remains **OPEN** because routed `clk_sys` timing fails and throughput at a compliant clock is not established.

## Gate-9 disposition

Gate 9 remains **OPEN**. Full-chip synthesis and routing, resource use, routed slack and a critical path are now recorded. The required 60 MHz `clk_sys` target is not met, and compliant-clock throughput metrics are not established. No bitstream, programming, physical video or hardware evidence exists. The next task should address the measured renderer/control critical path within the project’s approved Gate-9 scope before any physical baseline can be claimed.
