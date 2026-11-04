# G9-SOBEL-TIMING-INVESTIGATION — heap placer trial

Date: 2026-11-04
Baseline commit: `a45eef1460b74ace54aced04302a6f1244263a50`
RTL/source changes: none.

## Question and controlled change

The static-placer baseline used the full mapped ECP5 netlist generated for the
accepted two-stage triangle-setup implementation. Its routed `clk_sys` estimate
was 49.1739 MHz against 60 MHz (20.336 ns path, approximately −3.670 ns slack).
The worst path ran from the Sobel reader pixel FIFO through the pinned parent
line-buffer/Sobel arithmetic cone to the arithmetic elastic output register.

The diagnostic changed only `--placer static` to `--placer heap`. The device,
package, speed grade, mapped JSON, two LPFs, nextpnr build, `router1`, seed 1,
`--freq 60`, and detailed timing reporting were held constant. No RTL, source
list, synthesis result, constraints, clocks, or dependency was changed.

Mapped input JSON SHA-256:
`b1243e4b13135a5840bd4f15d7b40ebb3aad63a99dbeef3eee031896b39cf34e`

## Command and outcome

```sh
source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment
/opt/homebrew/bin/timeout --signal=INT --kill-after=10s 300s nextpnr-ecp5 \
  --85k --package CABGA381 --speed 6 \
  --json build/ecp5/ulx3s_graphics.json \
  --lpf third_party/projectf/graphics/fpga-graphics/ecp5/ulx3s.lpf \
  --lpf constraints/ulx3s_ftdi.lpf \
  --textcfg build/ecp5/ulx3s_graphics_sobel_heap.config \
  --report build/ecp5/nextpnr_report_sobel_heap.json \
  --detailed-timing-report --placer heap --router router1 --seed 1 --freq 60 \
  --log reports/gfx026/nextpnr_route_sobel_heap.txt
```

The shell captured and returned the wrapped process status (`1`); stdout/stderr
were also captured during the run, identical to the `--log` output.

nextpnr: `0.11.1-34-gc4fbb55a`. Router1 completed (reported router1 runtime
106.77 s); a routed configuration and full JSON report were produced within
the 300 s process limit. Process exit was 1 because nextpnr correctly rejected
the failing 60 MHz `clk_sys` timing constraint. The log reports 0 warnings and
1 timing error. No bitstream was generated.

## Result

| Clock | Constraint | Heap routed estimate | Result |
|---|---:|---:|---|
| `clk_sys` | 60.0024 MHz | 48.9788 MHz | FAIL |
| pixel output | 25.2048 MHz | 40.7830 MHz | PASS |
| serializer | 126.0239 MHz | 396.0396 MHz | PASS |
| intermediate PLL | 315.0598 MHz | 1053.7407 MHz | PASS |

The heap result corresponds to about 20.417 ns for the limiting system path
and approximately −3.751 ns slack against nextpnr's reported constraint
period. Relative to the static route, the system estimate fell by 0.1951 MHz;
path delay increased by about 0.081 ns and slack worsened by about 0.081 ns.
This is no material improvement and does not support timing closure.

The heap route's worst path is no longer the Sobel path. Its flattened physical
cell names begin with a `zbuffer_i.mem...` alias, but Yosys source attributes
map the launch FF to the renderer sequential block (`renderer_core.sv:165-222`),
the large multiplier to `triangle_setup.sv:85`, and the capture FF to the
triangle-setup sequential block (`triangle_setup.sv:164-182`). The logical
dataflow is the renderer's accepted DRAW payload (`draw_q`) through the
Stage-1 signed AREA products into the prepared setup register (`prep_q`,
including `prep_calculated.base.area`, assigned at line 179). The mapped report
does not expose bit-specific launch/capture aliases, so the register-bank
identification is based on this source mapping and triangle-setup dataflow.
The same-clock path contains 61 arcs: 29 logic and 30 routing arcs plus
clock-to-Q, including MULT18X18D/carry-chain/LUT stages. It is a real
constrained register-to-register path in nextpnr's timing model; no timing
exception was used.

The static route's path remains relevant evidence: it exposed the Sobel path
at 49.1739 MHz. Heap placement changed which path is worst, not the 60 MHz
result. A second placement configuration is not justified by this one trial.

## Resources and artifact hashes

The routed packed netlist reports:

- TRELLIS_COMB: 10,511 / 83,640
- TRELLIS_FF: 6,702 / 83,640
- DP16KD: 156 / 208
- MULT18X18D: 17 / 156
- EHXPLLL: 3 / 4
- TRELLIS_IO: 8 / 365

SHA-256:

- Routed config: `109cc700f820e0a3be129a05866e6c9af08e7bd70cdcd6205152b88664a62bcb`
- nextpnr JSON report: `215864484c5457c5aee38b8d8da016b6b6b502c60daca4735581c7c71d3c0f8f`
- nextpnr text log: `ebb3c29adc6b30cdacb515402ab06dfca91be9d5cc3318ee287ad5dffcb2058f`

Compressed config SHA-256: `e82257bff492a14613ed019e9300384659fe9057daf7c6cfcf85fc9afddae15d`.
Compressed report SHA-256: `f56216ce89528e13b57bcb9e5a7a835aeede95b251510b17f85c3524037101ed`.
The corresponding compressed config/report are retained beside this report.

## Decision

Gate 9 remains OPEN. Classification: **PLACED/ROUTED — TIMING FAILING**. Heap
placement with router1 did not meet 60 MHz and did not materially improve the
static-placer result. The pinned Sobel source remains unchanged at
`ad35514c990f6e1c9eb9fa18aee9d906f9df7721`.

This result does not prove that the parent Sobel cone alone makes 60 MHz
impossible: the static placer was limited by the parent Sobel path, while this
heap placement was limited by the renderer DRAW→triangle-setup AREA path. Timing closure now requires decision-level review of both cones and the
fixed single-cycle contracts. If a future change requires modifying the pinned parent, it needs
explicit approval, a separately qualified upstream revision, a new dependency
pin, and reruns of the parent's ready/valid, SOF/EOL, W+1, drain, APB,
functional, synthesis, and implementation evidence. No such change was made
here.

Existing RTL simulation and formal evidence is retained unchanged; no RTL was
modified, so functional suites were not rerun for this placer-only trial.
