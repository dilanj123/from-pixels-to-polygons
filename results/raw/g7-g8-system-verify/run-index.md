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

Gate 7 remains open for full response-stall coverage, controller reset matrix, end-to-end fatal Sobel recovery injection, and independent public-path scoreboard for all 14 counters. Gate 8 remains open for asynchronous CDC safety evidence.
