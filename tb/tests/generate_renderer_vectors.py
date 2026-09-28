#!/usr/bin/env python3
"""Generate decoded renderer frames and independent expected memories."""

from __future__ import annotations

import hashlib
import os
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw" / "reference"))

from gfx_primitives import Q4Point, triangle_coverage  # noqa: E402
from reference_renderer import (  # noqa: E402
    AttributePlane,
    BeginFrameCommand,
    DrawTriangleCommand,
    NopCommand,
    ReferenceRenderer,
    encode_begin_frame,
    encode_draw_triangle,
    encode_nop,
    parse_command_stream,
    random_frame_words,
    render_frame,
)


OUT = Path(os.environ.get("GFX012_VECTOR_DIR", "/tmp/gfx012_vectors"))


def plane(r: int, g: int, b: int, z: int):
    return (
        AttributePlane(r, 0, 0),
        AttributePlane(g, 0, 0),
        AttributePlane(b, 0, 0),
        AttributePlane(z, 0, 0),
    )


def draw(tag, vertices, planes):
    return DrawTriangleCommand(tag, tuple(vertices), tuple(planes))


def find_zero_covered():
    for scale in range(1, 16):
        for ox in range(0, 16):
            for oy in range(0, 16):
                v = (Q4Point(ox, oy), Q4Point(ox + scale, oy), Q4Point(ox, oy + scale))
                cov = triangle_coverage(v)
                if cov.area > 0 and not cov.bbox.is_empty and not cov.covered:
                    return v
    raise RuntimeError("could not find positive-area zero-covered triangle")


def command_words(commands):
    words = []
    for command in commands:
        if isinstance(command, NopCommand):
            words.extend(encode_nop(command.tag))
        elif isinstance(command, BeginFrameCommand):
            words.extend(encode_begin_frame(command.clear_rgb332, command.tag))
        elif isinstance(command, DrawTriangleCommand):
            words.extend(encode_draw_triangle(command))
    return words


def write_command_file(index, commands):
    path = OUT / f"frame_{index}.cmd"
    with path.open("w", encoding="ascii") as f:
        for command in commands:
            row = [0] * 21
            if isinstance(command, NopCommand):
                row[0], row[1] = 0, command.tag
            elif isinstance(command, BeginFrameCommand):
                row[0], row[1], row[2] = 1, command.tag, command.clear_rgb332
            elif isinstance(command, DrawTriangleCommand):
                row[0], row[1] = 2, command.tag
                for i, vertex in enumerate(command.vertices):
                    row[3 + 2 * i] = vertex.x
                    row[4 + 2 * i] = vertex.y
                for i, p in enumerate(command.planes):
                    row[9 + i] = p.start
                    row[13 + i] = p.dx
                    row[17 + i] = p.dy
            f.write(" ".join(str(x) for x in row) + "\n")


def write_expected(index, result):
    for suffix, payload in (("fb", result.framebuffer), ("z", result.zbuffer)):
        with (OUT / f"frame_{index}_{suffix}.hex").open("w", encoding="ascii") as f:
            f.writelines(f"{byte:02x}\n" for byte in payload)
    print(
        f"frame={index} fb_sha256={result.framebuffer_sha256} "
        f"z_sha256={result.zbuffer_sha256}"
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    frames = []

    frames.append([BeginFrameCommand(1, 0x00), NopCommand(1)])
    frames.append([
        BeginFrameCommand(2, 0xA5),
        NopCommand(3),
        draw(4, (Q4Point(80, 80), Q4Point(800, 80), Q4Point(80, 800)),
             plane(80 * 256, 40 * 256, 20 * 256, 100 * 256)),
    ])
    frames.append([
        BeginFrameCommand(5, 0x11),
        draw(6, (Q4Point(160, 160), Q4Point(800, 160), Q4Point(160, 800)),
             plane(220 * 256, 20 * 256, 40 * 256, 120 * 256)),
        draw(7, (Q4Point(800, 160), Q4Point(800, 800), Q4Point(160, 800)),
             plane(20 * 256, 220 * 256, 80 * 256, 121 * 256)),
    ])
    frames.append([
        BeginFrameCommand(8, 0x33),
        draw(9, (Q4Point(160, 160), Q4Point(800, 160), Q4Point(160, 800)),
             plane(10 * 256, 20 * 256, 30 * 256, 160 * 256)),
        draw(10, (Q4Point(160, 160), Q4Point(800, 160), Q4Point(160, 800)),
             plane(220 * 256, 200 * 256, 180 * 256, 160 * 256)),
        draw(11, (Q4Point(160, 160), Q4Point(800, 160), Q4Point(160, 800)),
             plane(40 * 256, 60 * 256, 80 * 256, 100 * 256)),
    ])
    zero = find_zero_covered()
    frames.append([
        BeginFrameCommand(12, 0x5A),
        draw(13, (Q4Point(0, 0), Q4Point(16, 0), Q4Point(32, 0)), plane(1, 2, 3, 4)),
        draw(14, (Q4Point(0, 0), Q4Point(16, 0), Q4Point(0, 16)), plane(1, 2, 3, 4)),
        draw(15, zero, plane(5, 6, 7, 8)),
        draw(16, (Q4Point(0, 0), Q4Point(800, 0), Q4Point(0, 800)),
             plane(100 * 256, 110 * 256, 120 * 256, 80 * 256)),
        draw(17, (Q4Point(160, 160), Q4Point(800, 160), Q4Point(480, 640)),
             plane(140 * 256, 30 * 256, 60 * 256, 90 * 256)),
        draw(18, (Q4Point(160, 160), Q4Point(480, 640), Q4Point(160, 640)),
             plane(30 * 256, 140 * 256, 70 * 256, 100 * 256)),
        draw(19, (Q4Point(160, 160), Q4Point(3200, 176), Q4Point(160, 3200)),
             plane(50 * 256, 160 * 256, 90 * 256, 110 * 256)),
        draw(20, (Q4Point(8, 8), Q4Point(24, 8), Q4Point(8, 24)),
             plane(200 * 256, 40 * 256, 180 * 256, 120 * 256)),
    ])
    frames.append([
        BeginFrameCommand(17, 0xFF),
        draw(18, (Q4Point(0, 0), Q4Point(5120, 0), Q4Point(0, 3840)),
             plane(255 * 256, 128 * 256, 64 * 256, 10 * 256)),
    ])

    for seed, count in ((1201, 4), (1207, 9), (1219, 16)):
        parsed = parse_command_stream(random_frame_words(seed, triangle_count=count))
        frames.append([c for c in parsed if not c.__class__.__name__ == "PresentCommand"])

    for index, commands in enumerate(frames):
        words = command_words(commands)
        result = render_frame(words)
        write_command_file(index, commands)
        write_expected(index, result)
    (OUT / "frame_count.txt").write_text(f"{len(frames)}\n", encoding="ascii")


if __name__ == "__main__":
    main()
