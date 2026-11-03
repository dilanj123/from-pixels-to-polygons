# G7-G8 system verification run index

Run at base `7cb2f9741d6ffc7cef79bce5bee872ceebbb1293` plus local documentation sync `e54f73859bb97c09a449173cdcb0c6bc591fca98`; pinned Sobel submodule remained `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`.

Tool setup used for HDL/formal commands:
`source /Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment`.
Sobel vector generation used `/Library/Frameworks/Python.framework/Versions/3.11/bin/python3` (Python 3.11.6, NumPy 1.25.2).

All listed commands exited 0:

- `make lint-command-system`
- `make test-command-system` — PASS, 32 checks; NORMAL/SOBEL/SOBEL/NORMAL; four complete READ_FRONT streams, 307,200 bytes; final 76,800-byte renderer/reference comparison exact.
- `make lint-uart`
- `make test-uart` — PASS, 4 checks.
- `make test-uart-system` — PASS, UART NOP and GET_STATUS loopback.
- `make test-host` — PASS, 4 Python tests.
- `make lint-perf-counters`, `make test-perf-counters`, `make test-renderer-counters`
- `make lint-renderer`, `make test-renderer`, `make test-renderer-reset`, `make test-renderer-decoder`, `make test-memory-wrappers`
- `make test-fragment-z`, `make test-raster-walk`, `make test-triangle-setup`, `make test-clear`, `make test-decoder`, `make test-fifo`
- `make lint-readback`, `make test-readback`, `make test-readback-framebuffer`
- `make lint-presentation`, `make test-presentation`, `make test-graphics-core`
- `make lint-sobel-adapters`, `make test-sobel-adapters`, `make lint-sobel-integration`, `make test-sobel-integration`, `make test-sobel-controller`, `make test-sobel-modes`
- `python3 -m unittest discover -s sw/reference -p 'test_*.py' -v` — PASS, 31/31.
- `make formal-fifo`, `make formal-buffer-manager`, `make formal-raster-bounds`, `make formal-fragment-depth`, `make formal-sobel-addresses`, `make formal-decoder`, `make formal-clear` — PASS under the scopes described in `results/processed/G7-G8-SYSTEM-VERIFY.md`.
- `make doctor` — PASS; Yosys 0.69+154, SBY 0.69, Z3 4.15.5, Verilator 5.053, Icarus 14.0 devel detected.
- `make bootstrap-smoke` — PASS.
- `git diff --check` — PASS.

Warnings/limitations: Icarus emitted its existing constant-select sensitivity notices. Formal emitted expected symbolic-input/global-clock notices. Buffer-manager formal ties sys/pix to one formal clock and is not asynchronous CDC safety evidence. No synthesis, P&R, timing, physical UART, or hardware checks were run.

## G7-G8-CLOSE corrective rerun

The corrective run started from clean `d38dafdf3e7a0d4a6a648aa355b5d60e58df1e3e`.
The pinned parent remained at `ad35514c990f6e1c9eb9fa18aee9d906f9df7721`.

| Command | Result |
|---|---|
| `make test-command-system` (expanded response/reset/error/counter test) | exit 0; 71 checks; four NORMAL/SOBEL presentations; 307,200 full-readback bytes |
| `make test-uart` | exit 0 |
| `make test-uart-system` | exit 0 |
| `make test-host` | exit 0; four tests |
| `make test-sobel-integration` with system `python3` | exit 2 before simulation: NumPy unavailable in that interpreter |
| `make test-sobel-controller` with system `python3` | exit 2 before simulation: NumPy unavailable in that interpreter |
| `SOBEL_PYTHON=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 make test-sobel-integration test-sobel-controller` | exit 0; integration NORMAL/SOBEL/SOBEL/NORMAL, full-frame outputs/readbacks zero mismatch; five controller reference frames zero mismatch |
| `make test-sobel-modes` | exit 0 |
| `make test-presentation` | exit 0; reset-after-pixel-switch stale-ACK case included |
| `make test-graphics-core` | exit 0 |
| `make test-renderer test-renderer-reset test-renderer-decoder test-renderer-counters` | all exit 0 |
| `make test-readback test-readback-framebuffer` | both exit 0 |
| `make test-perf-counters test-fifo test-decoder test-clear test-raster-walk test-fragment-z` | all exit 0 |
| Python reference suite (`python3 -m unittest discover -s sw/reference -p 'test_*.py' -v`) | exit 0; 31/31 |
| `make lint-command-system` | exit 0 |
| `make lint-uart lint-presentation lint-sobel-adapters lint-sobel-integration` | exit 0 |
| `make lint-renderer lint-perf-counters` | exit 0 |
| `make doctor` | exit 0 |
| `make bootstrap-smoke` | initially exit 2 because the new formal harness was not on the authorized HDL allowlist; Makefile allowlist updated narrowly; rerun exit 0 |
| `make formal-gate8` | exit 0; FIFO, buffer manager, raster bounds, fragment depth, Sobel reader/writer bounds, multiclock safety and multiclock covers all PASS under recorded scopes |

Expanded command-path evidence: every word of the two-word FRAME_DONE and
ERROR responses, each of three STATUS words, and each of fifteen COUNTERS
words is stalled and checked stable. READ_FRONT stalls at word indices
0,1,2,3,9603,19202,19203,19204,19205, reconstructs all 76,800 bytes and
checks the data-only checksum. The counter scoreboard reports exact expected
and actual W1–W14 for tags 1006, 1015 and 1028. At tag 1028, 64 queued NOPs
raise live FIFO occupancy while the snapshotted W14 remains 50.

The reset matrix covers partial command collection, active clear, pending
NORMAL presentation, active Sobel, and stalled READ_FRONT. The existing
presentation regression separately covers reset after pixel FRONT switch
and before synchronized system ACK. Public fatal recovery injects the
existing `sobel_error` at the controller boundary, checks ERROR tag/code 8,
stable ERROR words, no writes/role rotation, local rearm after transfer, then
checks sticky CMD_ERROR/front-valid/config flags and role fields in STATUS
before a subsequent successful NORMAL presentation. This is testbench-only
forcing; no production fault injection was added.

The new formal configuration uses `[options] multiclock on`, global-step
modelling and separate symbolic `clk_sys`/`clk_pix` event traces; exact
coincident rising edges are excluded. Common asynchronous reset assertion is
released through independent two-stage domain synchronizers. Safety BMC is
depth 32 using SBY 0.69 / `smtbmc z3` / Z3 4.15.5; cover depth is 48. The
cover model reaches mailbox/manager request acceptance, safe pixel FRONT
switch, ACK, manager completion, reset while outstanding, and NORMAL/SOBEL
completion paths. This is bounded digital clock-interleaving evidence, not
analog metastability/MTBF proof. Formal command exit is recorded after the
full `make formal-gate8` run completed with exit 0. The multiclock safety log
reports BMC depth 32 PASS (about 5m44s); the separate cover run reports PASS
at depth 48 (about 9s), with traces reaching the manager and standalone
mailbox transactions, safe switch, ACK, both modes, and reset outstanding.

Gate 7 and Gate 8 are CLOSED for the simulation requirements and selected formal scopes listed above. Gate 9 remains open. No synthesis, P&R, timing, physical UART, analog CDC/MTBF, or hardware evidence is claimed.
