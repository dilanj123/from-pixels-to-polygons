# G7-G8-SYSTEM-VERIFY — GFX-023/024/025

## Result

The public command/response controller and UART transport have RTL simulation
evidence. The corrective verification addendum below closes the outstanding
Gate-7 public-path checks and adds a bounded two-clock digital CDC check for
Gate 8. These results do not establish analog metastability safety, synthesis,
timing, or hardware operation.

The dependency remains the unchanged `ip/rtl-to-pixels` submodule at
`ad35514c990f6e1c9eb9fa18aee9d906f9df7721`.

## Decisions

D-037 freezes the previously unspecified response payloads:

- FRAME_DONE W1 is zero.
- ERROR W1 contains the existing error code in bits 7:0.
- STATUS W1 exposes architectural flags; W2 contains packed FRONT/RENDER/SPARE
  IDs.
- No-success-response commands remain unchanged; PRESENT completes after
  synchronized acknowledgement and role rotation.

D-038 freezes UART as 8N1, LSB-first, four little-endian bytes per 32-bit word,
`CLKS_PER_BIT=217` by default, one pending RX word, and sticky framing/overrun
blocking until reset. It makes no physical clock or UART claim.

## Implementation

`graphics_command_top` connects the existing 1024×32 FIFO and packet decoder to
the existing `graphics_core`. It implements IDLE/FRAME_ACTIVE legality,
SET_SOBEL configuration, PRESENT completion, READ_FRONT pass-through, STATUS,
COUNTERS snapshot, ERROR packets, and fatal local Sobel recovery after the
ERROR packet transfers. D-034 events now use the real presentation-wait event,
Sobel-busy event, and FIFO occupancy.

`uart_word_bridge` supplies the 8N1 serial/word conversion and synchronizes
reset release in the system-clock domain. `graphics_uart_top` composes it with
the logical command controller. `sw/host/gfx_host.py` contains command
encoders, packet receive helpers, 774-word batch protection, status/counter
requests, and full READ_FRONT reconstruction/checksum/save support.

One command-controller defect was found and fixed. GET_STATUS/GET_COUNTERS
received during FRAME_ACTIVE were not consumed, although the sequential state
logic was intended to reject them. The held decoded command blocked a later
PRESENT. The combinational ready path now consumes these requests so they
return ERR_ILLEGAL_STATE. The regression places this rejected query before a
queued legal presentation and verifies progress.

## Simulation evidence

`make test-command-system` passes. The test traverses
NORMAL→SOBEL→SOBEL→NORMAL using the public 32-bit command stream, actual FIFO,
decoder, renderer, pinned Sobel parent, presentation CDC, framebuffer bank,
and READ_FRONT engine. It checks four tagged FRAME_DONE packets and the expected
role sequence. Four complete readbacks reconstruct 307,200 bytes with zero
mismatches. The final NORMAL frame contains a triangle generated and scored by
the independent Python reference: 76,800 framebuffer bytes match, SHA-256
`cf6d0e1d69e10c2d62b28a0de2ae6190376dd4412f74ceb265861665aec2179e`.

Both Sobel command-path frames use a uniform source and produce the expected
all-zero edge image; each readback checks all 76,800 bytes and the checksum.
This supplements, but does not replace, the existing GFX-021 full-frame
pattern/reference regressions.

The test also verifies incomplete BEGIN_FRAME atomicity, illegal STATUS in
FRAME_ACTIVE, unknown-opcode ERROR, STATUS response stability during a stall,
COUNTERS snapshot/header stability and W1/W9 values, and reset abort of a
stalled READ_FRONT stream. The corrective response matrix and complete public
counter scoreboard are recorded below.

`make test-uart` passes four checks: RX/TX byte order, framing-error blocking,
and overrun blocking. `make test-uart-system` passes an actual UART NOP followed
by GET_STATUS and verifies the three serialized little-endian response words.
`make test-host` passes four Python tests, including complete 76,800-byte
READ_FRONT reconstruction and checksum.

The full existing relevant graphics regression passes, including renderer,
reset, counters, FIFO, decoder, raster, Fragment/Z, readback, Gate-5
presentation, adapters, real Sobel integration, five-frame Sobel controller
reference comparison, and the Python reference suite (31/31). Sobel vector
generation used Python 3.11 with NumPy 1.25.2. Icarus emits its existing
“constant selects in always_*” sensitivity notices for decoder, triangle
setup, Sobel arithmetic, framebuffer mux, and packed-struct controller logic;
these are simulator notices and all tests pass. Verilator lint passes for the
command-system top, UART top, UART bridge, and existing graphics composition.

## Selected formal results

Tools: OSS CAD Suite Yosys `0.69+154`, SymbiYosys `0.69`, Z3 `4.15.5`, ABC PDR
through Yosys. The suite was invoked after sourcing
`/Users/Dilan/eda/wire-to-decision/oss-cad-suite/environment`.

| Group | Run and scope | Result |
|---|---|---|
| FIFO order/conservation | `make formal-fifo`; depth-4 harness, BMC depth 12, scalar ghost queue | PASS, bounded |
| Buffer roles / mailbox | `make formal-buffer-manager`; sys/pix clocks tied to one formal clock, BMC depth 16, reset first then held inactive | PASS, bounded; not asynchronous CDC proof |
| Raster counter bounds | `make formal-raster-bounds`; 4×3 fixed bbox, ready/valid constrained for one simple walk, BMC depth 12 | PASS, reduced bounded |
| Fragment/Z write implication | `make formal-fragment-depth`; symbolic transactions, BMC depth 8 | PASS, bounded |
| Sobel reader addresses | `make formal-sobel-addresses`; production 320×240 control, symbolic source data/ready, ABC PDR | PASS, inductive |
| Sobel writer addresses/transfers | same target; production 320×240 control, symbolic stream/data, ABC PDR | PASS, inductive |
| Decoder | `make formal-decoder`; documented packet harness, BMC depth 25 | PASS, bounded (136 s) |
| Clear engine | `make formal-clear`; 8-pixel reduced instance, BMC depth 20 | PASS, reduced bounded |

At the original G7-G8-SYSTEM-VERIFY checkpoint, the role/mailbox harness ran
both RTL clock ports from the same formal clock.
It checks uniqueness, valid IDs, readback lock, role update only with an
outstanding presentation, safe-boundary gating of the pixel FRONT, and tagged
completion. It does not model unrelated clock edges or metastability. Therefore
the Gate-8 CDC safety checkbox was left open at that checkpoint. Formal runs also emit expected
unconstrained-input/no-clock-driver notices for symbolic inputs and the formal
global clock; no analog CDC or full-system proof is claimed.

## G7-G8-CLOSE corrective verification

Starting state was clean `main` at `d38dafdf3e7a0d4a6a648aa355b5d60e58df1e3e`,
equal to `origin/main`; the pinned Sobel parent remained unchanged.

`make test-command-system` passes the expanded 71-check public-system test.
FRAME_DONE and ERROR words are each held under backpressure before each
transfer; all three STATUS words and all fifteen COUNTERS words are stalled
and checked; READ_FRONT stalls cover BEGIN W0/W1/W2, the first data word,
middle/final data positions, END header/status/checksum. The complete
19,206-word READ_FRONT stream reconstructs 76,800 bytes and independently
checks the modulo-32-bit checksum. No response word was skipped or repeated.

The public reset matrix covers an incomplete command packet, active clear,
pending NORMAL presentation before the safe event, active Sobel, and stalled
READ_FRONT. Each reset returns the controller to IDLE and roles to 0/1/2,
invalidates FRONT, aborts active local work, verifies all architectural
counters are zero after global reset, and produces no stale
response/completion. The existing
`make test-presentation` case also resets after pixel FRONT switches but before
system ACK and verifies no stale completion.

Fatal recovery is injected only in the testbench by forcing the existing
`sobel_error` boundary after a public PRESENT SOBEL command reaches its
completion wait. The public ERROR packet carries the original tag and frozen
error code 8, remains stable under stall, causes no destination writes or role
rotation, and rearms the local Sobel controller only after ERROR transfer. A
subsequent STATUS response checks sticky CMD_ERROR, front_valid, Sobel
configuration and post-recovery role fields. A new legal BEGIN_FRAME and
NORMAL presentation then complete. No production fault-injection port was
added.

The independent testbench model observes event handshakes/cycles and FIFO
occupancy; it never reads the DUT counter bank. It compares W1-W14 at three
snapshots. For tag `1006`, actual/expected values are
`1,0,0,0,0,0,0,0,76800,0,0,133192,0,1`; for `1015`,
`2,0,0,0,0,0,0,0,76800,0,0,35530,151072,1`; for `1028`,
`4,4,1,1,6000,3000,1500,1500,76800,6014,8,145109,0,50`.
During the final stalled COUNTERS packet, 64 NOPs raise live FIFO occupancy
above the captured high-watermark; the transmitted W14 remains the captured
value 50. W0 tag and all 14 words match the independent snapshot.

The new `formal/present_cdc_multiclock_formal.sv` harness uses separate
symbolic `clk_sys` and `clk_pix` event traces on the SBY global formal
time-step clock, `multiclock on`, a common asynchronous reset assertion, and
separate two-stage synchronized reset release. The environment excludes
coincident rising edges but imposes no fixed frequency or phase. The DUT's
captured mailbox payload is checked through destination-ID correspondence at
the returned ACK; the environment assumes well-formed safe-frame-start pulses
and no unilateral reset.
`make formal-gate8` passes the two-clock SBY/Z3 BMC safety task at depth 32 and
the separate cover task at depth 48. Covers reach request acceptance, pixel
switch, ACK, completed manager presentation, reset while outstanding, and
both NORMAL and SOBEL completion. This is bounded digital clock-interleaving
safety evidence, not an analog metastability or MTBF proof. The captured
formal command result and cover reach points are preserved in the run index.

The formal harness required a narrow `bootstrap-smoke` allowlist update for
its authorized source and generated work directories. No production RTL,
command/response format, or upstream dependency was changed. The first
regression invocation of the two Python-generated Sobel suites used the
system Python and failed before simulation because NumPy was absent; reruns
with the documented Python 3.11/NumPy 1.25.2 interpreter passed.

Gate 7 — CLOSED based on the public response/backpressure, reset, fatal
recovery, counter, UART, full graphics/Sobel, and regression evidence.
Gate 8 — CLOSED for the selected bounded formal property set, including the
new two-clock CDC safety model. This is not a claim of complete or analog CDC
proof. No synthesis, P&R, timing, physical UART, or hardware evidence is
claimed.

The upstream parent is all-rights-reserved. The project retains only the pinned
submodule; this work does not establish redistribution or downstream product
rights.
