"""Quantized-command software reference for one logical render frame.

The implementation is intentionally mathematical: it uses the GFX-002 edge,
bbox, and coverage primitives and evaluates attribute planes directly. It does
not model ready/valid, FIFO, RAM latency, RTL stages, or hardware counters.
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import random
from typing import Iterable, Sequence

try:
    from .gfx_primitives import FB_HEIGHT, FB_WIDTH, Q4Point, triangle_coverage
except ImportError:  # Supports unittest discovery with sw/reference on sys.path.
    from gfx_primitives import FB_HEIGHT, FB_WIDTH, Q4Point, triangle_coverage


FRAME_PIXELS = FB_WIDTH * FB_HEIGHT
UINT32_MASK = 0xFFFFFFFF
SIGNED32_MIN = -(1 << 31)
SIGNED32_MAX = (1 << 31) - 1

OP_NOP = 0x0
OP_BEGIN_FRAME = 0x1
OP_DRAW_TRIANGLE = 0x2
OP_PRESENT = 0x4


class CommandError(ValueError):
    """Raised for malformed or unsupported reference command streams."""


@dataclass(frozen=True)
class AttributePlane:
    start: int
    dx: int
    dy: int

    def __post_init__(self) -> None:
        for name, value in (("start", self.start), ("dx", self.dx), ("dy", self.dy)):
            if not isinstance(value, int) or isinstance(value, bool):
                raise TypeError(f"{name} must be an integer")
            if not SIGNED32_MIN <= value <= SIGNED32_MAX:
                raise ValueError(f"{name} must fit signed32")


@dataclass(frozen=True)
class NopCommand:
    tag: int


@dataclass(frozen=True)
class BeginFrameCommand:
    tag: int
    clear_rgb332: int


@dataclass(frozen=True)
class DrawTriangleCommand:
    tag: int
    vertices: tuple[Q4Point, Q4Point, Q4Point]
    planes: tuple[AttributePlane, AttributePlane, AttributePlane, AttributePlane]


@dataclass(frozen=True)
class PresentCommand:
    tag: int
    sobel: bool = False


Command = NopCommand | BeginFrameCommand | DrawTriangleCommand | PresentCommand


@dataclass(frozen=True)
class FrameResult:
    framebuffer: bytes
    zbuffer: bytes

    @property
    def framebuffer_sha256(self) -> str:
        return hashlib.sha256(self.framebuffer).hexdigest()

    @property
    def zbuffer_sha256(self) -> str:
        return hashlib.sha256(self.zbuffer).hexdigest()


def _u32(word: int) -> int:
    if not isinstance(word, int) or isinstance(word, bool) or not 0 <= word <= UINT32_MASK:
        raise CommandError(f"command word is not uint32: {word!r}")
    return word


def _header(opcode: int, tag: int) -> int:
    if not 0 <= tag <= 0xFFFF:
        raise ValueError("command tag must fit 16 bits")
    return (opcode << 28) | tag


def _signed32(value: int) -> int:
    value &= UINT32_MASK
    return value - (1 << 32) if value & (1 << 31) else value


def _pack_vertex(vertex: Q4Point) -> int:
    return vertex.x | (vertex.y << 13)


def _unpack_vertex(word: int) -> Q4Point:
    if word & 0xFC000000:
        raise CommandError("DRAW_TRIANGLE vertex reserved bits are non-zero")
    return Q4Point(word & 0x1FFF, (word >> 13) & 0x1FFF)


def encode_nop(tag: int = 0) -> tuple[int, ...]:
    return (_header(OP_NOP, tag),)


def encode_begin_frame(clear_rgb332: int, tag: int = 0) -> tuple[int, ...]:
    if not 0 <= clear_rgb332 <= 0xFF:
        raise ValueError("clear RGB332 must fit 8 bits")
    return (_header(OP_BEGIN_FRAME, tag), clear_rgb332)


def encode_draw_triangle(command: DrawTriangleCommand) -> tuple[int, ...]:
    words = [_header(OP_DRAW_TRIANGLE, command.tag)]
    words.extend(_pack_vertex(vertex) for vertex in command.vertices)
    for plane in command.planes:
        words.append(plane.start & UINT32_MASK)
    for plane in command.planes:
        words.append(plane.dx & UINT32_MASK)
    for plane in command.planes:
        words.append(plane.dy & UINT32_MASK)
    return tuple(words)


def encode_present_normal(tag: int = 0) -> tuple[int, ...]:
    return (_header(OP_PRESENT, tag), 0)


def parse_command_stream(words: Sequence[int]) -> tuple[Command, ...]:
    """Parse complete fixed packets; no ready/valid or FIFO behavior is modeled."""

    parsed: list[Command] = []
    index = 0
    while index < len(words):
        header = _u32(words[index])
        opcode = header >> 28
        if (header >> 16) & 0xFFF:
            raise CommandError(f"reserved header bits are non-zero at word {index}")
        tag = header & 0xFFFF
        if opcode == OP_NOP:
            parsed.append(NopCommand(tag))
            index += 1
        elif opcode == OP_BEGIN_FRAME:
            if index + 2 > len(words):
                raise CommandError("truncated BEGIN_FRAME packet")
            payload = _u32(words[index + 1])
            if payload & 0xFFFFFF00:
                raise CommandError("BEGIN_FRAME reserved bits are non-zero")
            parsed.append(BeginFrameCommand(tag, payload & 0xFF))
            index += 2
        elif opcode == OP_DRAW_TRIANGLE:
            if index + 16 > len(words):
                raise CommandError("truncated DRAW_TRIANGLE packet")
            packet = [_u32(word) for word in words[index : index + 16]]
            vertices = tuple(_unpack_vertex(packet[offset]) for offset in (1, 2, 3))
            values = tuple(_signed32(packet[offset]) for offset in range(4, 16))
            planes = tuple(
                AttributePlane(values[offset], values[4 + offset], values[8 + offset])
                for offset in range(4)
            )
            parsed.append(DrawTriangleCommand(tag, vertices, planes))
            index += 16
        elif opcode == OP_PRESENT:
            if index + 2 > len(words):
                raise CommandError("truncated PRESENT packet")
            payload = _u32(words[index + 1])
            if payload & 0xFFFFFFFE:
                raise CommandError("PRESENT reserved bits are non-zero")
            parsed.append(PresentCommand(tag, bool(payload & 1)))
            index += 2
        else:
            raise CommandError(f"unsupported reference opcode 0x{opcode:X}")
    return tuple(parsed)


def _arithmetic_shift_q8(value: int) -> int:
    return value >> 8


def _clamp(value: int, low: int, high: int) -> int:
    return max(low, min(high, value))


def _pack_rgb332(r_raw: int, g_raw: int, b_raw: int) -> int:
    r8 = _clamp(_arithmetic_shift_q8(r_raw), 0, 255)
    g8 = _clamp(_arithmetic_shift_q8(g_raw), 0, 255)
    b8 = _clamp(_arithmetic_shift_q8(b_raw), 0, 255)
    return ((r8 >> 5) << 5) | ((g8 >> 5) << 2) | (b8 >> 6)


def _quantize_z(z_raw: int) -> int:
    return _clamp(_arithmetic_shift_q8(z_raw), 0, 254)


class ReferenceRenderer:
    """Execute one logical RENDER colour/Z frame from quantized commands."""

    def __init__(self) -> None:
        self.framebuffer = bytearray(FRAME_PIXELS)
        self.zbuffer = bytearray([0xFF] * FRAME_PIXELS)
        self._begun = False
        self._presented = False

    def begin_frame(self, clear_rgb332: int) -> None:
        self.framebuffer[:] = bytes([clear_rgb332]) * FRAME_PIXELS
        self.zbuffer[:] = b"\xFF" * FRAME_PIXELS
        self._begun = True
        self._presented = False

    def draw_triangle(self, command: DrawTriangleCommand) -> None:
        if not self._begun or self._presented:
            raise CommandError("DRAW_TRIANGLE requires an active unpresented frame")
        coverage = triangle_coverage(command.vertices)
        if coverage.bbox.is_empty or not coverage.covered:
            return
        assert coverage.bbox.xmin is not None
        assert coverage.bbox.ymin is not None
        for x, y in coverage.covered:
            dx = x - coverage.bbox.xmin
            dy = y - coverage.bbox.ymin
            raw = tuple(
                plane.start + dx * plane.dx + dy * plane.dy
                for plane in command.planes
            )
            index = y * FB_WIDTH + x
            new_z = _quantize_z(raw[3])
            if new_z < self.zbuffer[index]:
                self.zbuffer[index] = new_z
                self.framebuffer[index] = _pack_rgb332(raw[0], raw[1], raw[2])

    def present_normal(self) -> None:
        if not self._begun:
            raise CommandError("PRESENT requires BEGIN_FRAME")
        self._presented = True

    def execute(self, words: Sequence[int]) -> FrameResult:
        for command in parse_command_stream(words):
            if isinstance(command, NopCommand):
                continue
            if isinstance(command, BeginFrameCommand):
                if self._begun and not self._presented:
                    raise CommandError("BEGIN_FRAME while a frame is active")
                self.begin_frame(command.clear_rgb332)
            elif isinstance(command, DrawTriangleCommand):
                self.draw_triangle(command)
            elif isinstance(command, PresentCommand):
                if command.sobel:
                    raise CommandError("reference renderer supports PRESENT NORMAL only")
                self.present_normal()
        if not self._begun:
            raise CommandError("command stream did not contain BEGIN_FRAME")
        return FrameResult(bytes(self.framebuffer), bytes(self.zbuffer))


def render_frame(words: Sequence[int]) -> FrameResult:
    return ReferenceRenderer().execute(words)


def _random_triangle(rng: random.Random, mode: int) -> tuple[Q4Point, Q4Point, Q4Point]:
    if mode == 1:
        return Q4Point(0, 0), Q4Point(16, 0), Q4Point(32, 0)
    if mode == 2:
        positive = _random_triangle(rng, 0)
        return positive[0], positive[2], positive[1]
    if mode == 3:
        return Q4Point(5113, 3833), Q4Point(5119, 3833), Q4Point(5113, 3839)
    for _ in range(1000):
        vertices = tuple(
            Q4Point(rng.randrange(0, 5121), rng.randrange(0, 3841))
            for _ in range(3)
        )
        if triangle_coverage(vertices).area > 0:
            return vertices
    return Q4Point(8, 8), Q4Point(40, 8), Q4Point(8, 40)


def random_frame_words(seed: int, triangle_count: int | None = None) -> tuple[int, ...]:
    """Generate a legal deterministic frame stream for reference regression."""

    rng = random.Random(seed)
    count = triangle_count if triangle_count is not None else rng.randint(1, 48)
    if not 1 <= count <= 48:
        raise ValueError("triangle_count must be in 1..48")
    words: list[int] = list(encode_begin_frame(rng.randrange(256), tag=seed & 0xFFFF))
    for index in range(count):
        mode = index % 7
        vertices = _random_triangle(rng, mode if mode in (1, 2, 3) else 0)
        planes = tuple(
            AttributePlane(
                rng.randint(-65536, 65535),
                rng.randint(-65536, 65535),
                rng.randint(-65536, 65535),
            )
            for _ in range(4)
        )
        words.extend(encode_draw_triangle(DrawTriangleCommand(index, vertices, planes)))
    words.extend(encode_present_normal(tag=0xF000 | (seed & 0x0FFF)))
    return tuple(words)


def random_regression(seeds: Iterable[int]) -> tuple[tuple[int, str, str], ...]:
    results = []
    for seed in seeds:
        result = render_frame(random_frame_words(seed))
        results.append((seed, result.framebuffer_sha256, result.zbuffer_sha256))
    return tuple(results)
