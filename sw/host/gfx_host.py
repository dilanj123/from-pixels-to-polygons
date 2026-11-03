#!/usr/bin/env python3
"""Small UART host for the canonical 32-bit graphics command stream."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
from typing import BinaryIO, Iterable

RSP_FRAME_DONE = 0x8
RSP_ERROR = 0x9
RSP_STATUS = 0xA
RSP_COUNTERS = 0xB
RSP_READBACK_BEGIN = 0xC
RSP_READBACK_END = 0xD


def header(opcode: int, tag: int) -> int:
    if not 0 <= opcode <= 0xF or not 0 <= tag <= 0xFFFF:
        raise ValueError("opcode/tag out of range")
    return (opcode << 28) | tag


def words_to_bytes(words: Iterable[int]) -> bytes:
    return b"".join(struct.pack("<I", word & 0xFFFFFFFF) for word in words)


def command_nop(tag: int) -> list[int]:
    return [header(0x0, tag)]


def command_begin_frame(tag: int, clear_rgb332: int) -> list[int]:
    return [header(0x1, tag), clear_rgb332 & 0xFF]


def command_draw_triangle(tag: int, encoded_words: Iterable[int]) -> list[int]:
    payload = list(encoded_words)
    if len(payload) != 15:
        raise ValueError("DRAW_TRIANGLE requires 15 already-packed payload words")
    return [header(0x2, tag), *(w & 0xFFFFFFFF for w in payload)]


def command_set_sobel(tag: int, threshold: int, bypass: bool = False) -> list[int]:
    if not 0 <= threshold <= 255:
        raise ValueError("threshold must be an unsigned byte")
    return [header(0x3, tag), threshold | (int(bypass) << 8)]


def command_present(tag: int, sobel: bool = False) -> list[int]:
    return [header(0x4, tag), int(sobel)]


def command_read_front(tag: int) -> list[int]:
    return [header(0x5, tag)]


def command_status(tag: int) -> list[int]:
    return [header(0x6, tag)]


def command_counters(tag: int) -> list[int]:
    return [header(0x7, tag)]


def read_word(port: BinaryIO) -> int:
    raw = port.read(4)
    if len(raw) != 4:
        raise TimeoutError("incomplete 32-bit response word")
    return struct.unpack("<I", raw)[0]


def read_packet(port: BinaryIO) -> list[int]:
    first = read_word(port)
    typ = first >> 28
    lengths = {
        RSP_FRAME_DONE: 2,
        RSP_ERROR: 2,
        RSP_STATUS: 3,
        RSP_COUNTERS: 15,
        RSP_READBACK_BEGIN: 19206,
    }
    if typ not in lengths:
        raise ValueError(f"unknown response type 0x{typ:x}")
    return [first, *(read_word(port) for _ in range(lengths[typ] - 1))]


def send_words(port: BinaryIO, words: Iterable[int]) -> None:
    payload = words_to_bytes(words)
    count = port.write(payload)
    if count is not None and count != len(payload):
        raise IOError(f"short UART write: {count}/{len(payload)} bytes")


def submit_frame(port: BinaryIO, words: Iterable[int]) -> list[int]:
    """Send a legal command batch (at most 774 words), then await terminal reply."""
    batch = list(words)
    if len(batch) > 774:
        raise ValueError("batch exceeds the guaranteed 774-word frame list")
    send_words(port, batch)
    while True:
        packet = read_packet(port)
        if packet[0] >> 28 in (RSP_FRAME_DONE, RSP_ERROR):
            return packet


def fetch_readback(port: BinaryIO, tag: int, output: Path) -> list[int]:
    send_words(port, command_read_front(tag))
    packet = read_packet(port)
    if packet[0] >> 28 != RSP_READBACK_BEGIN or len(packet) != 19206:
        raise ValueError("invalid READ_FRONT response")
    if packet[0] & 0xFFFF != tag:
        raise ValueError("READBACK_BEGIN tag mismatch")
    if packet[1] != 19200:
        raise ValueError("unexpected framebuffer word count")
    descriptor = packet[2]
    if ((descriptor & 0x3FF) != 320 or ((descriptor >> 10) & 0x1FF) != 240 or
            ((descriptor >> 21) & 0xFF) != 1 or (descriptor >> 29) != 0 or
            ((descriptor >> 19) & 0x3) > 2):
        raise ValueError("invalid framebuffer descriptor")
    data_words = packet[3:19203]
    data = b"".join(struct.pack("<I", word) for word in data_words)
    if (packet[19203] >> 28 != RSP_READBACK_END or
            (packet[19203] & 0xFFFF) != tag or packet[19204] != 0):
        raise ValueError("invalid READBACK_END header/status")
    checksum = sum(data_words) & 0xFFFFFFFF
    if packet[19205] != checksum:
        raise ValueError("readback checksum mismatch")
    output.write_bytes(data)
    return packet


def query_status(port: BinaryIO, tag: int = 1) -> list[int]:
    send_words(port, command_status(tag))
    return read_packet(port)


def query_counters(port: BinaryIO, tag: int = 1) -> list[int]:
    send_words(port, command_counters(tag))
    return read_packet(port)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", help="serial device path")
    parser.add_argument("--baud", type=int, default=115200)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--read-front", type=Path, help="save READ_FRONT bytes to this path")
    action.add_argument("--commands-json", type=Path,
                        help="send a JSON list of canonical 32-bit command words and await FRAME_DONE/ERROR")
    action.add_argument("--status", action="store_true", help="request GET_STATUS")
    action.add_argument("--counters", action="store_true", help="request GET_COUNTERS")
    parser.add_argument("--tag", type=lambda x: int(x, 0), default=1)
    args = parser.parse_args()
    try:
        import serial  # type: ignore[import-not-found]
    except ImportError as exc:
        parser.error("pyserial is required only for hardware use: " + str(exc))
    with serial.Serial(args.port, args.baud, timeout=30, write_timeout=30) as port:
        if args.read_front:
            packet = fetch_readback(port, args.tag, args.read_front)
            print(f"saved {len(packet)} response words to {args.read_front}")
        elif args.commands_json:
            words = json.loads(args.commands_json.read_text())
            if not isinstance(words, list) or any(not isinstance(w, int) for w in words):
                raise ValueError("commands JSON must be a list of integer words")
            packet = submit_frame(port, words)
            print("response=" + " ".join(f"{w:08x}" for w in packet))
            if packet[0] >> 28 == RSP_ERROR:
                return 1
        elif args.status:
            packet = query_status(port, args.tag)
            print("status=" + " ".join(f"{w:08x}" for w in packet))
        else:
            packet = query_counters(port, args.tag)
            print("counters=" + " ".join(f"{w:08x}" for w in packet))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
