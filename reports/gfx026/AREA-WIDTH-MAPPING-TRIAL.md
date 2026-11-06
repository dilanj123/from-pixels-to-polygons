# G9-AREA-WIDTH-MAPPING-TRIAL — disposition

## Decision

**Rejected for retention.** The trial is mathematically sound for decoder-legal
coordinates and passed the focused and relevant functional regression. Yosys
reduced the two AREA products from four `MULT18X18D` cells to two, reducing the
full-chip DSP count from 19 to 17. However, the comparable routed `clk_sys`
estimate worsened from D-041's 52.8290 MHz to 50.7125 MHz. The active baseline
remains the unmodified D-041 three-stage triangle setup. Gate 9 remains OPEN.

This is a current baseline-selection decision. It does not show that narrower
AREA arithmetic is mathematically incorrect; it shows that this implementation
trial did not improve whole-design timing under the fixed route configuration.

## Legal arithmetic bounds

The decoder rejects DRAW coordinates outside `X=0..5120`, `Y=0..3840`
(`rtl/cmd_decoder.sv`, `ERR_COORD_RANGE`), and the fixed-point contract gives
the same bounds. Therefore:

| Quantity | Bound | Width used / required |
|---|---:|---:|
| Signed X delta | −5120..+5120 | signed 14 bits |
| Signed Y delta | −3840..+3840 | signed 13 bits |
| Product magnitude | at most 19,660,800 | signed 27-bit full product for 14×13 operands |
| Difference of products | −39,321,600..+39,321,600 | signed 27 bits suffice; trial subtracts sign-extended products in signed 28 bits |
| D-029 AREA output | exact legal mathematical value, sign-extended | signed 32 bits |

The trial explicitly sized the AREA operands/products and sign-extended each
27-bit product before the 28-bit subtraction, then sign-extended the result to
32 bits. Coordinate bounds make the narrowed values exact. No edge arithmetic,
pipeline boundary, latency, handshake, classification, bbox, attribute, or
result field was changed. The public decoder remains responsible for rejecting
illegal coordinates before this internal precondition applies.

## Verification

- `make lint-triangle-setup test-triangle-setup`: PASS. 256 legal vectors,
  9,078 result-field comparisons against the independent Python reference;
  includes all classifications, signed AREA boundaries, legal coordinate
  extrema, deterministic random legal coordinates, latency, stalls, mutation,
  reset and refill behavior. Verilator lint passed. Icarus emitted its existing
  constant-select sensitivity notices.
- Relevant simulation batch: PASS after setting the documented Python 3.11
  interpreter. The initial default-Python batch stopped at Sobel vector
  generation because that interpreter lacked NumPy; no RTL test failed.
- The public command-system scenario passed with all W1–W14 values matching;
  the four-DRAW values remain W10=6,022 and W11=16.
- NORMAL→SOBEL→SOBEL→NORMAL passed. Both Sobel frames had 76,800 accepted
  inputs, outputs, source reads and writes, zero independent-reference
  mismatches, and full readback with zero byte/word mismatches.
- Sobel controller: five full reference frames passed; 76,800 reads/writes per
  frame and zero mismatches. Adapter, renderer/framebuffer/Z, 17-frame readback,
  UART/host, presentation and mode tests passed.
- Python suites: reference 31/31; host 4/4.
- `make formal-gate8`: PASS for the project's existing selected properties;
  this does not prove triangle setup arithmetic.
- Relevant lint, `make doctor`, and `make bootstrap-smoke`: PASS.

## Synthesis mapping

Yosys `0.69+154` completed the full `ulx3s_graphics_top` hierarchy and
`check -assert` reported zero problems. Source attribution in the mapped netlist
shows D-041's AREA expression (source line 94) mapped to four `MULT18X18D`
cells, while each trial AREA product (source lines 81 and 82) mapped to one.
Thus the trial's two-product DSP reduction is directly evidenced. The whole
chip still uses 156 framebuffer/Z/FIFO `DP16KD` memories and 3 PLLs.

| Resource | D-041 | Width trial | Change |
|---|---:|---:|---:|
| LUT4 | 7,579 | 7,338 | −241 |
| TRELLIS_FF | 7,277 | 7,276 | −1 |
| DP16KD | 156 | 156 | 0 |
| MULT18X18D | 19 | 17 | −2 |
| EHXPLLL | 3 | 3 | 0 |

Yosys retained the existing four memory-to-register conversions, three
Project F DVI `RST` width-resize warnings, and the experimental `write_xaiger2`
notice. No new latch or hierarchy/check problem was reported.

## Comparable route

The trial reused the full mapped JSON and the D-041 build conditions: ULX3S-85F
reference, LFE5U-85F-6BG381C, same LPFs/PLL/source hierarchy/dependency pins,
60 MHz system, 25.2 MHz output and 126 MHz serializer requirements, nextpnr
`0.11.1-34-gc4fbb55a`, static placer, router1, seed 1. No constraint or clock
was changed. Router1 completed in 34.16 seconds; total command wall time was
73.34 seconds.

| Routed clock | Achieved | Constraint | Result |
|---|---:|---:|---|
| `clk_sys` | 50.7125 MHz | 60.0024 MHz | FAIL |
| DVI serializer | 178.8909 MHz | 126.0239 MHz | PASS |
| pixel output | 41.9111 MHz | 25.2048 MHz | PASS |
| auxiliary intermediate | 973.7099 MHz | 315.0598 MHz | PASS |

The routed worst path is no longer the AREA expression. It launches at
`sobel_control_i.reader_i.pixel_fifo[1]` (bit 0, source register Q) and captures
at the pinned parent's `sobel_i.u_arithmetic_elastic.m_data` register. The
reported path traverses the parent's 3×3 window/line-buffer and arithmetic
logic. Its delay is 19.719 ns: 7.456 ns logic, 11.738 ns routing and 0.525 ns
clock-to-Q. The worst slack is approximately −3.053 ns against the 60 MHz
system constraint. The trial therefore does not establish the AREA path's
individual timing, only that the whole design is slower and the Sobel cone is
now worst.

The route completed and emitted a configuration, but nextpnr returned exit 1
for the timing failure (one timing error; zero warnings). No bitstream was
generated. This is **PLACED/ROUTED — TIMING FAILING**, not timing closure.

## Commands and retained artifacts

The full-chip Yosys source list was identical to `scripts/synth/run_ecp5.sh`;
the trial command used a unique log and mapped JSON:

```text
source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && yosys -ql reports/gfx026/yosys_synth_area_width_trial.txt -p 'read_verilog -lib /Users/Dilan/eda/wire-to-decision/oss-cad-suite/share/yosys/ecp5/cells_bb.v; read_verilog -sv rtl/gfx_pkg.sv third_party/projectf/lib/display/display_480p.sv third_party/projectf/lib/clock/ecp5/clock2_gen.v third_party/projectf/lib/display/tmds_encoder_dvi.sv third_party/projectf/lib/display/ecp5/dvi_generator.sv rtl/clear_engine.sv rtl/triangle_setup.sv rtl/raster_walk.sv rtl/fragment_z.sv rtl/perf_counters.sv rtl/zbuffer.sv rtl/framebuffer_dp.sv rtl/scanout_2x.sv rtl/renderer_core.sv rtl/readback_engine.sv rtl/present_cdc.sv rtl/buffer_manager.sv rtl/sobel_fb_reader.sv rtl/sobel_fb_writer.sv rtl/sobel_apb_master.sv rtl/sobel_controller.sv ip/rtl-to-pixels/rtl/pixel_pkg.sv ip/rtl-to-pixels/rtl/rgb_to_gray.sv ip/rtl-to-pixels/rtl/elastic_stage.sv ip/rtl-to-pixels/rtl/apb_regs.sv ip/rtl-to-pixels/rtl/pixel_control.sv ip/rtl-to-pixels/rtl/line_buffer.sv ip/rtl-to-pixels/rtl/window_3x3.sv ip/rtl-to-pixels/rtl/sobel_compact.sv ip/rtl-to-pixels/rtl/magnitude_clamp.sv ip/rtl-to-pixels/rtl/threshold_stage.sv ip/rtl-to-pixels/rtl/output_control.sv ip/rtl-to-pixels/rtl/rtl_to_pixels_top_pipelined.sv rtl/graphics_core.sv rtl/cmd_fifo.sv rtl/cmd_decoder.sv rtl/graphics_command_top.sv rtl/uart_word_bridge.sv rtl/graphics_uart_top.sv rtl/board/ulx3s_graphics_top.sv; hierarchy -check -top ulx3s_graphics_top; synth_ecp5 -top ulx3s_graphics_top -json build/ecp5/ulx3s_graphics_area_width_trial.json; check -assert'
```

The one bounded route used:

```text
source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && /usr/bin/time -p /opt/homebrew/bin/gtimeout --signal=TERM 600 nextpnr-ecp5 --85k --package CABGA381 --speed 6 --json build/ecp5/ulx3s_graphics_area_width_trial.json --lpf third_party/projectf/graphics/fpga-graphics/ecp5/ulx3s.lpf --lpf constraints/ulx3s_ftdi.lpf --textcfg build/ecp5/ulx3s_graphics_area_width_trial.config --report reports/gfx026/nextpnr_report_area_width_trial.json --detailed-timing-report --placer static --router router1 --seed 1 --freq 60 --log reports/gfx026/nextpnr_route_area_width_trial.txt
```

Synthesis exited 0. Route exited 1 for the timing failure and was not terminated
by the 600-second timeout. The corrected make regression batch using Python
3.11 exited 0; lint, formal, Python, doctor and smoke checks exited 0. The first
batch invocation exited 2 when default Python lacked NumPy; it stopped at
vector generation and was rerun successfully with Python 3.11. The focused
trial source patch and test log, synthesis/route logs, compressed timing report,
mapped netlist and routed config are retained beside this memo. The pinned
Sobel SHA is unchanged:
`ad35514c990f6e1c9eb9fa18aee9d906f9df7721`.

Artifact SHA-256 values: mapped trial JSON (uncompressed, generated in the
isolated worktree) `54f5d9a8bcf1d3e5ef56228d1bb41ec50cf94c8b33cfa09848b38983121cd2ec`;
synthesis log `3d65696ad976c91f81deb80fa190c9dba33193a2f4866033a17a3fa60eca8139`;
route log `cc5dc2b8a55a6b46adaf5a75ecb912e67556cfe554840191b1d7c91add7c95b1`;
compressed timing report `04536b2deb664b3fd2a684b72572e9eb65268f54a07a7d7c0101d5be2eeb6269`;
compressed routed config `0f2596f28780bc05805e5cd8c2b127a0555e453a05aa6d5a937bd092d67f6e69`;
compressed RTL/test trial patch `28188367d0500d35a545b0e153cc97ac6014eeaa69afebc6b5598f19a0d9f475`;
focused triangle test log `fd2520c32545328c5707da20701567036bce7c5a20d224052d033c72ca3e4c25`.

Active RTL and triangle testbench on `main` are unchanged from D-041. No
triangle-setup formal proof, compliant 60 MHz system implementation, bitstream,
physical clock, or hardware result is claimed.
