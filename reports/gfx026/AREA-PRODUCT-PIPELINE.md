# G9-AREA-PRODUCT-PIPELINE — D-042 implementation result

Date: 2026-11-06
Starting commit: `73c87b4e1fc266ff367b47f2c6dd2fade6faeb0c`
Branch: `main`
Dependency: `ip/rtl-to-pixels` remains at `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`

## Decision and implementation

D-042 authorizes one registered boundary between the two signed32 AREA products
and their subtraction. `rtl/triangle_setup.sv` now has four elastic stages:

1. Capture accepted DRAW data, signed coordinate deltas, AREA operands, tag and
   attributes.
2. Calculate and register both signed32 AREA products, preserving the previous
   expression widths and signedness.
3. Subtract the registered products and prepare classification, bbox, edge
   metadata and initial-edge operands.
4. Calculate the three initial edge values and register the unchanged result
   struct.

The interface remains ready/valid. Four-stage latency is checked, all four
stages support backpressure/reset flushing, and the directed full-rate case
produces one ordered result per cycle while accepting simultaneous refill and
retirement. No renderer or parent Sobel source was changed.

The independent geometry suite passed 160 vectors and 5,848 field comparisons,
including all classifications, legal coordinate extrema, post-accept input
changes, stalled payload stability, continuous throughput and reset in each
stage/output. The 160-vector expected data was unchanged.

## Functional and counter evidence

The public command-system regression passed its full NORMAL/SOBEL/SOBEL/NORMAL
sequence, four tagged completions and 307,200-byte readback. In the independent
four-DRAW counter scenario (tag `0x1028`), all W1-W14 actual values equaled the
scoreboard:

| Word | Counter | Expected = actual |
|---|---|---:|
| W1 | frames_completed | 4 |
| W2 | triangles_submitted | 4 |
| W3 | triangles_degenerate | 1 |
| W4 | triangles_backface_rejected | 1 |
| W5 | candidate_pixels | 6000 |
| W6 | covered_fragments | 3000 |
| W7 | z_pass | 1500 |
| W8 | z_fail | 1500 |
| W9 | clear_cycles | 76800 |
| W10 | render_cycles | 6026 |
| W11 | triangle_setup_cycles | 20 |
| W12 | present_wait_cycles | 145101 |
| W13 | sobel_cycles | 0 |
| W14 | command_fifo_high_watermark | 50 |

The D-041 public scenario was W10=6022/W11=16 for the same four DRAWs. The
observed D-042 deltas are +4 cycles in each field, consistent with one extra
TRI_SETUP cycle per DRAW. These are event-scoreboard comparisons, not values
copied from the DUT to form expectations. Renderer reset/decoder/counter,
raster, Fragment/Z, clear, Sobel integration/controller/modes, presentation,
readback, UART/host, FIFO/decoder and Python reference regressions all passed.
The Python 3.11 reference suite passed 31 tests. `make formal-gate8` passed its
selected existing properties; it does not prove triangle setup. Relevant
Verilator lint passed. Icarus emitted its existing constant-select/sensitivity
notices.

Exact grouped commands and exit codes:

| Command | Exit |
|---|---:|
| `make lint-triangle-setup test-triangle-setup` | 0 |
| `make test-renderer test-renderer-reset test-renderer-decoder test-renderer-counters` | 0 |
| `make test-raster-walk test-fragment-z test-clear` | 0 |
| `make test-command-system` | 0 |
| `SOBEL_PYTHON=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 make test-sobel-integration test-sobel-controller test-sobel-modes` | 0 |
| `make test-sobel-adapters test-presentation test-graphics-core` | 0 |
| `make test-readback test-readback-framebuffer test-uart-system test-host` | 0 |
| `make test-fifo test-decoder test-perf-counters test-memory-wrappers test-uart` | 0 |
| `make lint-triangle-setup lint-renderer lint-command-system lint-sobel-integration lint-presentation lint-sobel-adapters lint-perf-counters lint-fragment-z lint-raster-walk` | 0 |
| `/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 -m unittest discover -s sw/reference -p 'test_*.py' -v` | 0 |
| `make formal-gate8` | 0 |
| `make doctor` | 0 |
| `make bootstrap-smoke` | 0 |
| `git diff --check` | 0 |

## Full synthesis

Yosys command used the complete source list and top from
`scripts/synth/run_ecp5.sh`, changing only the output paths to preserve prior
artifacts:

```text
source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && yosys -ql reports/gfx026/yosys_synth_area_product_pipeline.txt -p 'read_verilog -lib /Users/Dilan/eda/wire-to-decision/oss-cad-suite/share/yosys/ecp5/cells_bb.v; read_verilog -sv rtl/gfx_pkg.sv third_party/projectf/lib/display/display_480p.sv third_party/projectf/lib/clock/ecp5/clock2_gen.v third_party/projectf/lib/display/tmds_encoder_dvi.sv third_party/projectf/lib/display/ecp5/dvi_generator.sv rtl/clear_engine.sv rtl/triangle_setup.sv rtl/raster_walk.sv rtl/fragment_z.sv rtl/perf_counters.sv rtl/zbuffer.sv rtl/framebuffer_dp.sv rtl/scanout_2x.sv rtl/renderer_core.sv rtl/readback_engine.sv rtl/present_cdc.sv rtl/buffer_manager.sv rtl/sobel_fb_reader.sv rtl/sobel_fb_writer.sv rtl/sobel_apb_master.sv rtl/sobel_controller.sv ip/rtl-to-pixels/rtl/pixel_pkg.sv ip/rtl-to-pixels/rtl/rgb_to_gray.sv ip/rtl-to-pixels/rtl/elastic_stage.sv ip/rtl-to-pixels/rtl/apb_regs.sv ip/rtl-to-pixels/rtl/pixel_control.sv ip/rtl-to-pixels/rtl/line_buffer.sv ip/rtl-to-pixels/rtl/window_3x3.sv ip/rtl-to-pixels/rtl/sobel_compact.sv ip/rtl-to-pixels/rtl/magnitude_clamp.sv ip/rtl-to-pixels/rtl/threshold_stage.sv ip/rtl-to-pixels/rtl/output_control.sv ip/rtl-to-pixels/rtl/rtl_to_pixels_top_pipelined.sv rtl/graphics_core.sv rtl/cmd_fifo.sv rtl/cmd_decoder.sv rtl/graphics_command_top.sv rtl/uart_word_bridge.sv rtl/graphics_uart_top.sv rtl/board/ulx3s_graphics_top.sv; hierarchy -check -top ulx3s_graphics_top; synth_ecp5 -top ulx3s_graphics_top -json build/ecp5/ulx3s_graphics_area_product_pipeline.json; check -assert'
```

Exit 0. Yosys 0.69+154, git `30d62572e-dirty`. Hierarchy check and both
`check -assert` invocations found zero problems. The full top and pinned parent
hierarchy are present. Resource comparison:

| Resource | D-041 | D-042 trial | Delta |
|---|---:|---:|---:|
| Yosys LUT4 | 7579 | 7466 | -113 |
| Yosys TRELLIS_FF | 7277 | 7888 | +611 |
| DP16KD | 156 | 156 | 0 |
| MULT18X18D | 19 | 19 | 0 |
| EHXPLLL | 3 | 3 | 0 |
| nextpnr TRELLIS_COMB | 10693 | 10616 | -77 |

The synthesis log has eight unique warnings: the existing reader FIFO and
graphics-core small-array register mappings, decoder packet register mapping,
three Project F serializer reset-width resizes, and Yosys's experimental
`write_xaiger2` notice. No new latch or hierarchy issue was reported.

## One comparable full route

The only route attempt used nextpnr-ecp5 0.11.1-34-gc4f4bb55a, device
`LFE5U-85F-6BG381C`, static placer, router1, seed 1, original LPFs/PLL/source
mapping and `--freq 60`. Exact invocation:

```text
source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment && nextpnr-ecp5 --85k --package CABGA381 --speed 6 --json build/ecp5/ulx3s_graphics_area_product_pipeline.json --lpf third_party/projectf/graphics/fpga-graphics/ecp5/ulx3s.lpf --lpf constraints/ulx3s_ftdi.lpf --textcfg reports/gfx026/ulx3s_triangle_area_product_pipeline.config --report reports/gfx026/nextpnr_report_triangle_area_product_pipeline.json --detailed-timing-report --placer static --router router1 --seed 1 --freq 60 --log reports/gfx026/nextpnr_route_triangle_area_product_pipeline.txt
```

Shell exit 1 is due to the timing failure. The log explicitly says `Routing
complete` and `Program finished normally`; router1 reports 51.79 seconds.
Classification: **PLACED/ROUTED — TIMING FAILING**.

| Clock | Routed max estimate | Constraint | Result |
|---|---:|---:|---|
| `clk_sys` | 51.1587 MHz | 60 MHz | FAIL |
| `clk_pix` output | 41.6945 MHz | 25.2048 MHz | PASS |
| serializer `clk_pix_5x` | 205.8036 MHz | 126.0239 MHz | PASS |
| `clk_315m_aux` | 975.6098 MHz | 315.0598 MHz | PASS |

The `clk_sys` route delay is 19.547 ns and slack is -2.881 ns against the
16.666 ns target period. D-041's comparable result was 52.8290 MHz, 18.929 ns,
and approximately -2.263 ns. Thus this route does not improve the overall
system-clock timing result: its maximum-frequency estimate is 1.6703 MHz lower
and its worst delay is 0.618 ns longer. It also uses 611 more FF. Route
completion is not timing closure.

The new worst `clk_sys` path is not the AREA pipeline. Its source register is
`graphics_i.graphics_i.graphics_i.sobel_control_i.reader_i.pixel_fifo[1]`
Q (reader source `rtl/sobel_fb_reader.sv:23`); its capture register is
`...sobel_i.u_arithmetic_elastic.m_data..._TRELLIS_FF_Q_1.M`. The path traverses
the pinned `rtl_to_pixels_top_pipelined` grayscale/window/Sobel arithmetic
cone and ends in the arithmetic elastic stage. The detailed route reports
8.09 ns logic and 11.45 ns routing delay. The trace contains a mapped
MULT18X18D and ECP5 carry-chain stages; source RTL shows the RGB-to-gray
constant multiplications and the Sobel window/arithmetic feed. Both endpoints
are `clk_sys` registers and the path is normally constrained. No timing
exception was added. Since this parent revision is immutable, no source change
was made there. This result does not establish that the AREA path itself is
below 18.929 ns; the report provides the worst path, not a complete path
ranking.

Final route uses 10,616 TRELLIS_COMB, 7,888 TRELLIS_FF, 156 DP16KD,
19 MULT18X18D and 3 EHXPLLL. nextpnr reports zero warnings and one timing
error. No bitstream was generated because `clk_sys` fails. No physical hardware
or measured clock claim is made.

Artifacts:

- Synthesis log: `reports/gfx026/yosys_synth_area_product_pipeline.txt`
- Routed log: `reports/gfx026/nextpnr_route_triangle_area_product_pipeline.txt`
- Timing JSON: `reports/gfx026/nextpnr_report_triangle_area_product_pipeline.json.gz`
- Routed config: `reports/gfx026/ulx3s_triangle_area_product_pipeline.config.gz`
- Mapped netlist: `reports/gfx026/ulx3s_graphics_area_product_pipeline.json.gz`

SHA-256:

```text
nextpnr_report_triangle_area_product_pipeline.json.gz
  bcaa7305c5a1650fdfe46c098a7e5519eb9a25d337b0213731df246ec35e1d55
ulx3s_triangle_area_product_pipeline.config.gz
  850c9eee82b4c7e14a942eceef8e51aad5a3e042fc2d1e61e78b9136fa578bfb
ulx3s_graphics_area_product_pipeline.json.gz
  762f46dfb63d3f1b4eaf2555a0564eaec023c7d841f8160685726be14cbd38cb
```

## Disposition

Gate 9 remains **OPEN**. D-042 behavior is functionally verified and the full
design is synthesized/routed, but no clock-compliant result or bitstream exists.
The run's worst path has moved to the immutable parent Sobel datapath, though
the available report cannot rank the non-critical AREA path. The next action is
not another triangle stage or an unapproved dependency edit: review whether to
retain this four-stage trial and authorize a separately qualified upstream
Sobel timing investigation. The pinned dependency and all frozen contracts
remain unchanged.
