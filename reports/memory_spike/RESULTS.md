# GFX-004 memory-spike synthesis results

Commit scope: `Run GFX-004 memory feasibility synthesis spike`

## Toolchain

Activation:

```text
source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment
```

Resolved tools:

```text
yosys       /Users/Dilan/eda/wire-to-decision/oss-cad-suite/bin/yosys
            Yosys 0.69+154 (git sha1 30d62572e-dirty)
nextpnr     /Users/Dilan/eda/wire-to-decision/oss-cad-suite/bin/nextpnr-ecp5
            nextpnr-0.11.1-34-gc4fbb55a
ecppack     /Users/Dilan/eda/wire-to-decision/oss-cad-suite/bin/ecppack
            Project Trellis ecppack 1.4-83-g65fe191
```

## Commands

```text
make synth-memory                                      exit 0
yosys -q -l reports/memory_spike/<top>.log \
  -p "read_verilog -sv rtl/memory_spike/memory_spike.sv; \
      hierarchy -top <top>; synth_ecp5 -top <top> \
      -json reports/memory_spike/<top>.json"              exit 0
```

The Yosys command was run for each of:

```text
memory_spike_one_framebuffer_top
memory_spike_zbuffer_top
memory_spike_fifo_top
memory_spike_top
```

Each report checked successfully with `Found and reported 0 problems.` The
only repeated warning was Yosys's experimental `write_xaiger2` feature notice.

## Resource results

| View | DP16KD | LUT4 | PFUMX | TRELLIS_FF | DSP |
|---|---:|---:|---:|---:|---:|
| one framebuffer | 38 | 475 | 170 | 10 | 0 |
| Z buffer | 38 | 255 | 88 | 5 | 0 |
| FIFO | 2 | not reported as a mapped LUT4/PFUMX memory | not reported | not reported | 0 |
| combined hierarchy | 154 | support logic is hierarchical; no large LUT/FF memory | — | — | 0 |

The combined hierarchy was reported as 154 `DP16KD`, with three framebuffer
instances, one Z instance, and one FIFO instance. No generic memories remained
in the final mapped hierarchy.

The LFE5U-85F comparison capacity is 208 18-Kbit sysMEM blocks, 84K LUTs,
and 156 18x18 multipliers, from the Lattice ECP5 family selection table. This
is a capacity comparison, not integrated utilization or timing evidence.

The admitted parent resource record remains separate: 2 `DP16KD`, 3
`MULT18X18D`, 775 `LUT4`, and 223 `TRELLIS_FF` for the pinned
`rtl_to_pixels_top_pipelined` dependency evidence.

## Interpretation

The three framebuffers and Z buffer inferred as ECP5 `DP16KD`; the FIFO
inferred as two `DP16KD`. The framebuffer’s independent `clk_pix` and
`clk_sys` synchronous memory style mapped without inference errors or RAM-mode
warnings. This does not establish placement, routing, timing, formal, or
hardware behavior, and the spike is not full-system synthesis.
