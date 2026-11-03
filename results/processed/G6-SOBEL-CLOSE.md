# G6-SOBEL-CLOSE — GFX-021/022 evidence

## Initial GFX-021/022 campaign result

The individual GFX-021/022 RTL components and single-frame flows have passing
simulation evidence; Gate 6 was still open pending repeated-mode integration.
The unchanged parent submodule is
at `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`
(`v1.0.1-dependency-ready`). The actual `rtl_to_pixels_top_pipelined` was
instantiated with `IMG_WIDTH=320`, `IMG_HEIGHT=240` and connected to the
existing reader, writer, and APB master through `sobel_controller`.

## Full-frame reference tests

Command:

```sh
SOBEL_PYTHON=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 make test-sobel-controller
```

Five 76,800-pixel cases passed: black, horizontal/vertical edges, gradient,
deterministic pseudorandom, and renderer-produced source. Threshold-enabled and
bypass settings were exercised. Every source read and destination write was
row-major; all 384,000 compared output bytes matched the independent parent
Python reference. Each case reported 76,800 reads, 76,800 writes, and zero
mismatches. The controller also checked exact input/output count, SOF/EOL
counts, APB status, frame-count completion, writer error, and final output
drain before presentation.

## Graphics-core composition

```sh
SOBEL_PYTHON=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 make test-sobel-integration
```

An actual renderer-produced frame traversed the real Sobel core, was written
to SPARE, presented at the D-036 raster origin, and read back from FRONT using
GFX-014. The full processed framebuffer and readback each had zero byte
mismatches. The stream monitor observed 76,800 source reads, input transfers,
output transfers, and destination writes, with one SOF and 240 EOLs on each
stream. A second Sobel operation was reset after ten source reads; reset
restored roles/front-valid and generated no stale FRAME_DONE.

## Role and regression tests

```sh
make test-sobel-modes
make test-presentation
make test-graphics-core
make test-sobel-adapters
make lint-sobel-adapters
make lint-sobel-integration
```

The role manager sequence NORMAL→SOBEL→SOBEL→NORMAL matched expected IDs and
maintained uniqueness. It exercised readback locking and only changed roles
after a synthetic safe-boundary event and synchronized ACK. This test does not
run the full parent Sobel datapath at every transition. The graphics-core
NORMAL regression retained three complete reference-rendered frames and full
scanout comparisons.

Additional passing regression commands:

```sh
make lint-renderer && make test-renderer && make test-renderer-reset && make test-renderer-decoder && make test-renderer-counters
make lint-readback && make test-readback && make test-readback-framebuffer
make test-memory-wrappers
make test-fragment-z && make test-raster-walk && make test-triangle-setup && make test-clear && make test-decoder && make test-fifo
python3 -m unittest discover -s sw/reference -p 'test_*.py' -v
make doctor
make bootstrap-smoke
```

All listed regression commands exited zero. The Python suite ran 31 tests. The bootstrap smoke initially
identified the new focused controller testbench as an unlisted HDL file; the
Gate-6 testbench allowlist was updated and the rerun passed.

## Limits

Simulation used Icarus Verilog and lint used Verilator 5.053. Icarus printed
known `constant selects in always_*` sensitivity notices. Formal was not run;
Yosys/SBY/solvers and ECP5 implementation tools are unavailable per
`make doctor`. No synthesis, P&R, timing, physical display, metastability, or
hardware claim is made. The parent source is unchanged and its all-rights-
reserved notice remains in force; no general redistribution permission is
claimed.

The role transition test and full Sobel-frame test are separate focused
compositions. Full Sobel datapath processing was performed end-to-end at
graphics-core level for the renderer scene; the other four image patterns
were checked at the controller/memory boundary. The initial repeated-mode
attempt stalled in its testbench readback checker and was not counted as
passing evidence; the corrective reproduction and result follow.

## G6-REPEATED-MODE-FIX corrective result

**Gate 6: CLOSED** after the corrected full graphics-core repeated-mode
regression passed. No production RTL or pinned parent source changed.

### Reproduced cause and correction

The first bounded run reproduced a checker timeout at readback word 19205. The
diagnostic snapshot showed the graphics core idle, `readback_active=0`, and
`rsp_valid=0`: the readback engine had completed. The testbench had left
`rb_rsp_ready` asserted after the prior readback. Consequently the final
checksum of the next transaction transferred before the checker started
observing that word, and the checker waited for an already accepted response.
The earliest incorrect observable was the unobserved ready/valid handshake,
not renderer, Sobel-controller, role-manager, or CDC state.

The permanent test fix holds response ready low while waiting for and checking
each word, then asserts it for that word's single rising-edge transfer. Every
response in both readbacks is now observed in order. Every wait has a finite
watchdog with a bounded state snapshot.

### Full graphics-core mode sequence

Command:

```sh
SOBEL_PYTHON=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 make test-sobel-integration
```

Result: exit 0 under Icarus Verilog. The deterministic sequence is:

| Operation | Resulting FRONT/RENDER/SPARE | Verification |
|---|---|---|
| NORMAL, tag `7100` | `1/0/2` | Rendered colour/Z reference check and full 307,200-pixel scanout comparison; one tagged FRAME_DONE |
| SOBEL, tag `7204` | `2/1/0` | 76,800 ordered source reads, input and output transfers, and SPARE writes; one input/output SOF, 240 EOLs per direction; zero full-frame Sobel reference mismatches; 19,206-word readback reconstructs 76,800 bytes with zero mismatch |
| SOBEL, tag `7201` | `0/2/1` | Same complete counts, metadata, independent reference comparison, and full readback checks |
| NORMAL, tag `7101` | `2/0/1` | Rendered colour/Z reference check and full 307,200-pixel scanout comparison; one tagged FRAME_DONE |

All IDs remain distinct. The safe-boundary monitor recorded no FRONT change
outside the D-036 raster-origin event (`switches_outside_safe=0`). Exactly
four FRAME_DONE pulses were observed. A subsequent active-Sobel reset abort
after ten source reads restored reset roles/front-valid and produced no stale
completion.

### Corrective regression set

The following commands all exited 0: `make test-sobel-controller`,
`make test-sobel-modes`, `make test-sobel-adapters`,
`make lint-sobel-adapters`, `make lint-sobel-integration`,
`make test-presentation`, `make test-graphics-core`, `make test-renderer`,
`make test-renderer-reset`, `make test-renderer-decoder`,
`make test-renderer-counters`, `make test-readback`,
`make test-readback-framebuffer`, `make test-memory-wrappers`,
`make test-fragment-z`, `make test-raster-walk`, `make test-triangle-setup`,
`make test-clear`, `make test-decoder`, `make test-fifo`,
`make lint-renderer`, `make lint-readback`, `make lint-presentation`,
`make lint-perf-counters`, `make lint-fragment-z`, `make lint-raster-walk`,
`make lint-triangle-setup`, `make lint-clear`, `make lint-decoder`,
`make lint-fifo`, `make doctor`, and `make bootstrap-smoke`. The Python
reference suite exited 0 with 31 tests. `git diff --check` exited 0.

Known Icarus `sorry: constant selects in always_*` sensitivity-analysis
notices appeared during compilation; no new functional or lint warnings were
reported. Formal, synthesis/P&R, timing, and physical hardware/display checks
were not run and are not claimed. The parent remains pinned at
`ad35514c990f6e1c9eb9fa18aee9d906f9df7721`.
