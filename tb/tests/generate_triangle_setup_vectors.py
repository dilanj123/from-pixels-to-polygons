"""Generate independent Python-oracle vectors for triangle_setup_tb.sv."""

from __future__ import annotations

import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "sw" / "reference"))

from gfx_primitives import (  # noqa: E402
    Q4Point,
    TriangleClassification,
    edge_function,
    edge_is_top_left,
    pixel_center_q4,
    triangle_bbox,
    triangle_area,
)


MASK32 = 0xFFFFFFFF


def s32(value: int) -> int:
    return value & MASK32


def vertex_word(point: Q4Point) -> int:
    return (point.y << 13) | point.x


def expected(points: tuple[Q4Point, Q4Point, Q4Point], attrs: list[int]):
    v0, v1, v2 = points
    edges = ((v0, v1), (v1, v2), (v2, v0))
    deltas = [(b.x - a.x, b.y - a.y) for a, b in edges]
    area = triangle_area(v0, v1, v2)
    bbox = triangle_bbox(points)
    if area == 0:
        classification = 2
    elif area < 0:
        classification = 3
    elif bbox.is_empty:
        classification = 1
    else:
        classification = 0

    words = [classification, s32(area)]
    for dx, dy in deltas:
        words += [s32(dx), s32(dy)]
    words.append(sum((int(edge_is_top_left(a, b)) << i) for i, (a, b) in enumerate(edges)))
    for dx, dy in deltas:
        words += [s32(-(dy << 4)), s32(dx << 4)]

    if classification == 0:
        words += [bbox.xmin, bbox.xmax, bbox.ymin, bbox.ymax]
        sample = pixel_center_q4(bbox.xmin, bbox.ymin)
        words += [s32(edge_function(a, b, sample)) for a, b in edges]
    else:
        words += [0, 0, 0, 0, 0, 0, 0]
    words += [s32(value) for value in attrs]
    assert len(words) == 34
    return words, classification


def make_vectors() -> list[tuple[tuple[Q4Point, Q4Point, Q4Point], list[int]]]:
    vectors = []

    def add(points, salt, forced_attrs=None):
        attrs = forced_attrs if forced_attrs is not None else [((salt * 0x10203 + i * 0x11111111) & MASK32) for i in range(12)]
        vectors.append((tuple(Q4Point(x, y) for x, y in points), attrs))

    directed = [
        ((16, 16), (160, 16), (16, 160)),
        ((0, 0), (1, 0), (0, 1)),                 # positive AREA, EMPTY
        ((0, 0), (160, 160), (320, 320)),         # degenerate
        ((16, 16), (16, 160), (160, 16)),         # backface
        ((8, 8), (5120, 8), (8, 3840)),
        ((8, 3840), (5120, 3840), (8, 8)),
        ((0, 0), (5120, 0), (0, 3840)),
        ((5120, 0), (5120, 3840), (0, 3840)),
        ((7, 7), (9, 7), (7, 9)),
        ((8, 8), (9, 8), (8, 9)),
        ((5111, 3831), (5112, 3831), (5111, 3832)),
        ((5119, 3839), (5120, 3839), (5119, 3840)),
        ((0, 0), (5120, 0), (5120, 3840)),
        ((0, 0), (0, 3840), (5120, 3840)),
        ((128, 128), (320, 128), (128, 320)),
        ((128, 128), (128, 320), (320, 128)),
    ]
    for index, points in enumerate(directed):
        if index == 0:
            add(points, index + 1, [0x00000000, 0x00000001, 0x7FFFFFFF, 0x80000000,
                                   0xFFFFFFFF, 0x12345678, 0x89ABCDEF, 0x01010101,
                                   0xFEDCBA98, 0x00000000, 0x7FFFFFFF, 0x80000000])
        else:
            add(points, index + 1)

    rng = random.Random(0x8008)
    while len(vectors) < 160:
        points = tuple((rng.randrange(0, 5121), rng.randrange(0, 3841)) for _ in range(3))
        add(points, rng.getrandbits(32))
    return vectors


def main() -> None:
    vectors = make_vectors()
    output = Path(__file__).with_name("triangle_setup_vectors.mem")
    class_counts = [0, 0, 0, 0]
    with output.open("w", encoding="ascii") as handle:
        for points, attrs in vectors:
            expected_words, classification = expected(points, attrs)
            class_counts[classification] += 1
            input_words = [0x8000 + len(class_counts) * 0 + 0x1234]
            input_words += [vertex_word(point) for point in points]
            input_words += attrs
            assert len(input_words) == 16
            handle.write("\n".join(f"{word & MASK32:08x}" for word in input_words + expected_words))
            handle.write("\n")
    print(f"generated={len(vectors)} file={output}")
    print(f"class_counts raster={class_counts[0]} empty={class_counts[1]} degenerate={class_counts[2]} backface={class_counts[3]}")


if __name__ == "__main__":
    main()
