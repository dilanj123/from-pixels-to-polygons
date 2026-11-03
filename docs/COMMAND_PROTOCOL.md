# Command and response protocol

The graphics core has a 32-bit ready/valid command input and 32-bit ready/valid
response output. A transfer occurs only on `valid && ready`. A stalled response
holds `rsp_valid=1` and stable `rsp_data`; responses do not interleave.

## Command header and packet sizes

Every command header is:

```text
31:28 opcode
27:16 reserved = 0
15:0  user/sequence tag
```

| Opcode | Command | Words |
|---:|---|---:|
| 0x0 | NOP | 1 |
| 0x1 | BEGIN_FRAME | 2 |
| 0x2 | DRAW_TRIANGLE | 16 |
| 0x3 | SET_SOBEL | 2 |
| 0x4 | PRESENT | 2 |
| 0x5 | READ_FRONT | 1 |
| 0x6 | GET_STATUS | 1 |
| 0x7 | GET_COUNTERS | 1 |

BEGIN_FRAME word 1 has clear RGB332 in bits 7:0 and reserved bits 31:8 zero.

## DRAW_TRIANGLE

```text
W0  header
W1  v0: X[12:0], Y[25:13], reserved[31:26]
W2  v1, same layout
W3  v2, same layout
W4  R_start       W5  G_start       W6  B_start       W7  Z_start
W8  dR_dx         W9  dG_dx         W10 dB_dx         W11 dZ_dx
W12 dR_dy         W13 dG_dy         W14 dB_dy         W15 dZ_dy
```

Starts and gradients are signed32 Q8. Reserved fields must be zero. Coordinate
and coefficient range rules are in `docs/FIXED_POINT.md`.

SET_SOBEL uses threshold bits 7:0, threshold_bypass bit 8, and reserved bits
31:9 zero. PRESENT uses bit 0 (`0=NORMAL`, `1=SOBEL`) and reserved bits 31:1
zero.

## Atomicity, legality, and errors

Known packets execute only after complete collection and validation. Incomplete
packets wait indefinitely and have no side effects. Reset discards partial state.
Unknown opcodes consume one word, raise an error, and parsing resumes at the
following word.

IDLE permits NOP, BEGIN_FRAME, SET_SOBEL, valid FRONT READ_FRONT, GET_STATUS,
and GET_COUNTERS. FRAME_ACTIVE permits NOP, DRAW_TRIANGLE, and PRESENT.
SET_SOBEL is IDLE-only. SOBEL PRESENT additionally requires
`sobel_config_valid=1`. Long-running operations do not dispatch another
command. Degenerate, backface, and empty-bbox triangles are geometry results,
not protocol errors.

`CMD_ERROR` is sticky until global reset. Error codes are:

```text
0x01 UNKNOWN_OPCODE       0x02 RESERVED_NONZERO
0x03 ILLEGAL_STATE        0x04 COORD_RANGE
0x05 FIELD_RANGE          0x06 FRONT_INVALID
0x07 SOBEL_CONFIG_MISSING 0x08 SOBEL_PROTOCOL
0x09 INTERNAL_PROTOCOL
```

Errors 0x01–0x07 reject only the offending command, have no side effects, and
emit an ERROR response. Fatal 0x08/0x09 stop malformed destination writes, keep
the current FRONT, do not rotate roles, abandon the active frame, emit ERROR,
and recover to IDLE after the ERROR response transfers.

The FIFO is 1024 words. The guaranteed frame list is 48 DRAW packets (768
words), BEGIN_FRAME (2), PRESENT (2), and optional SET_SOBEL (2), totalling
774 words; diagnostic/NOP traffic is not included in that guarantee.

## Responses

Response header:

```text
31:28 response_type
27:16 reserved = 0
15:0  echoed command tag
```

Types are 0x8 FRAME_DONE, 0x9 ERROR, 0xA STATUS, 0xB COUNTERS, 0xC
READBACK_BEGIN, and 0xD READBACK_END. FRAME_DONE and ERROR are 2 words;
STATUS is 3 words; COUNTERS is 15 words. STATUS does not expose internal FSM
encoding.

GET_COUNTERS is IDLE-only and snapshots values before transmission. The exact
COUNTERS order is:

```text
W0 header
W1 frames_completed             W2 triangles_submitted
W3 triangles_degenerate         W4 triangles_backface_rejected
W5 candidate_pixels             W6 covered_fragments
W7 z_pass                       W8 z_fail
W9 clear_cycles                 W10 render_cycles
W11 triangle_setup_cycles       W12 present_wait_cycles
W13 sobel_cycles                W14 command_fifo_high_watermark
```

## GFX-023 response payload clarification (D-037)

The response packet lengths and header above remain unchanged. The previously
unspecified trailing words are frozen as follows:

```text
FRAME_DONE W1 = 32'h00000000
ERROR      W1[7:0] = error_code; W1[31:8] = 0

STATUS W1 flags:
  bit 0 frame_active
  bit 1 front_valid
  bit 2 presentation_pending
  bit 3 readback_active
  bit 4 sobel_busy
  bit 5 sticky CMD_ERROR
  bit 6 sobel_config_valid
  bits 31:7 = 0

STATUS W2 roles:
  bits 1:0 FRONT_ID
  bits 3:2 RENDER_ID
  bits 5:4 SPARE_ID
  bits 31:6 = 0
```

The status flags are architectural conditions, not internal FSM encodings.
FRAME_DONE carries its tag in W0; W1 is reserved zero for forward-compatible
success status. The ERROR code is the existing frozen 0x01–0x09 code.

NOP, BEGIN_FRAME, DRAW_TRIANGLE, and SET_SOBEL have no success response.
PRESENT produces FRAME_DONE after synchronized presentation acknowledgment
and role update. Syntax/runtime rejection produces ERROR. READ_FRONT,
GET_STATUS, and GET_COUNTERS produce their specified response streams.

## GFX-023 UART word transport (D-038)

The UART adapter is a byte transport around the canonical 32-bit word
ready/valid interface; it does not add command framing or opcodes. Both
directions use asynchronous 8N1 bytes (one low start bit, eight data bits LSB
first, one high stop bit). Within each 32-bit word, byte 0 carries bits 7:0,
then bits 15:8, 23:16, and 31:24. The word is handed to the command/response
interface only when all four bytes have been received/transmitted as a word.

The baud divider is `CLKS_PER_BIT`, default 217 for a nominal 25 MHz system
clock and 115200 baud; simulation may override it. This is a logical transport
setting, not a board clock or physical UART claim. There is no hardware flow
control. The bridge has one pending command-word register. If a further
complete RX word arrives while that register is occupied and downstream
`cmd_ready` is low, it sets sticky `rx_overrun`, drops the overflowing word,
and disables further command delivery until reset. A bad stop bit sets sticky
`rx_framing_error`, discards the partial word, and likewise blocks command
delivery until reset. The host shall submit no more than the documented
774-word guaranteed frame list and wait for FRAME_DONE/ERROR before submitting
the next frame. Status remains available to host software through the logical
command interface; the UART wrapper does not invent an in-band error packet.

The TX bridge accepts a response word only when its 32-bit holding register is
free, then serializes its four bytes in the same little-endian order. It holds
the upstream response stable by deasserting `rsp_ready` while that word is
being serialized. UART simulation verifies digital framing/ordering only.

## READ_FRONT framing

READ_FRONT is legal only in IDLE with `front_valid_sys=1` and no presentation
outstanding. It snapshots FRONT and blocks role rotation during readback.

READBACK_BEGIN is three words: header; word count 19200; and a packed descriptor
with width 320 in bits 9:0, height 240 in bits 18:10, front_id in bits 20:19,
bytes-per-pixel 1 in bits 28:21, and reserved bits 31:29. Exactly 19200 data
words follow, packing four RGB332 pixels little-endian per word. The checksum is
the modulo-2^32 sum of all data words. READBACK_END is three words: header,
status (0 means success), and checksum. A successful sequence is 19206 words.
The checksum is a framing aid, not framebuffer correctness evidence.
