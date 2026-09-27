"""Independent mathematical primitives for the fixed-point graphics contract.

This module intentionally evaluates edge functions directly at pixel centres.
It does not model RTL cycle timing, accumulator scheduling, memory, or depth.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
import math
from typing import Iterable, Sequence


FB_WIDTH = 320
FB_HEIGHT = 240
X_Q4_MAX = FB_WIDTH * 16
Y_Q4_MAX = FB_HEIGHT * 16
SIGNED32_MIN = -(1 << 31)
SIGNED32_MAX = (1 << 31) - 1


class FixedPointError(ValueError):
    """Raised when a value violates a frozen fixed-point contract."""


class TriangleClassification(Enum):
    ACCEPTED = "accepted"
    DEGENERATE = "degenerate"
    BACKFACE = "backface"


@dataclass(frozen=True)
class Q4Point:
    x: int
    y: int

    def __post_init__(self) -> None:
        if not isinstance(self.x, int) or isinstance(self.x, bool):
            raise TypeError("Q4 x must be an integer")
        if not isinstance(self.y, int) or isinstance(self.y, bool):
            raise TypeError("Q4 y must be an integer")
        if not 0 <= self.x <= X_Q4_MAX:
            raise FixedPointError(f"Q4 x outside 0..{X_Q4_MAX}: {self.x}")
        if not 0 <= self.y <= Y_Q4_MAX:
            raise FixedPointError(f"Q4 y outside 0..{Y_Q4_MAX}: {self.y}")


@dataclass(frozen=True)
class BoundingBox:
    xmin: int | None
    xmax: int | None
    ymin: int | None
    ymax: int | None

    @classmethod
    def empty(cls) -> "BoundingBox":
        return cls(None, None, None, None)

    @property
    def is_empty(self) -> bool:
        return (
            self.xmin is None
            or self.xmax is None
            or self.ymin is None
            or self.ymax is None
            or self.xmin > self.xmax
            or self.ymin > self.ymax
        )


@dataclass(frozen=True)
class TriangleCoverage:
    classification: TriangleClassification
    area: int
    bbox: BoundingBox
    candidates: tuple[tuple[int, int], ...]
    covered: tuple[tuple[int, int], ...]


def _finite(value: object) -> None:
    if isinstance(value, float) and not math.isfinite(value):
        raise FixedPointError("fixed-point input must be finite")


def quantize_coordinate(real_coord: object, *, axis: str) -> int:
    """Quantize a non-negative real screen coordinate to unsigned Q4."""

    _finite(real_coord)
    if axis not in {"x", "y"}:
        raise ValueError("axis must be 'x' or 'y'")
    if real_coord < 0:
        raise FixedPointError("screen coordinates must be non-negative")
    quantized = math.floor(real_coord * 16 + 0.5)
    limit = X_Q4_MAX if axis == "x" else Y_Q4_MAX
    if quantized > limit:
        raise FixedPointError(f"{axis} coordinate quantizes outside 0..{limit}")
    return quantized


def quantize_signed_q8(real_value: object) -> int:
    """Quantize a real signed Q8 coefficient, with ties away from zero."""

    _finite(real_value)
    scaled = real_value * 256
    if scaled >= 0:
        fixed = math.floor(scaled + 0.5)
    else:
        fixed = -math.floor(abs(scaled) + 0.5)
    if not SIGNED32_MIN <= fixed <= SIGNED32_MAX:
        raise FixedPointError("signed Q8 coefficient is not signed32-representable")
    return fixed


def pixel_center_q4(x: int, y: int) -> Q4Point:
    """Return the Q4 sample centre for a legal framebuffer pixel."""

    if not isinstance(x, int) or isinstance(x, bool) or not 0 <= x < FB_WIDTH:
        raise ValueError(f"pixel x must be an integer in 0..{FB_WIDTH - 1}")
    if not isinstance(y, int) or isinstance(y, bool) or not 0 <= y < FB_HEIGHT:
        raise ValueError(f"pixel y must be an integer in 0..{FB_HEIGHT - 1}")
    return Q4Point((x << 4) + 8, (y << 4) + 8)


def edge_function(a: Q4Point, b: Q4Point, p: Q4Point) -> int:
    """Evaluate E(a,b,p) directly from the mathematical definition."""

    dx = b.x - a.x
    dy = b.y - a.y
    return dx * (p.y - a.y) - dy * (p.x - a.x)


def triangle_area(v0: Q4Point, v1: Q4Point, v2: Q4Point) -> int:
    return edge_function(v0, v1, v2)


def classify_area(area: int) -> TriangleClassification:
    if area > 0:
        return TriangleClassification.ACCEPTED
    if area == 0:
        return TriangleClassification.DEGENERATE
    return TriangleClassification.BACKFACE


def edge_is_top_left(a: Q4Point, b: Q4Point) -> bool:
    dy = b.y - a.y
    dx = b.x - a.x
    return dy < 0 or (dy == 0 and dx > 0)


def edge_contains(a: Q4Point, b: Q4Point, p: Q4Point) -> bool:
    value = edge_function(a, b, p)
    return value > 0 or (value == 0 and edge_is_top_left(a, b))


def _ceil_div(numerator: int, denominator: int) -> int:
    return -((-numerator) // denominator)


def triangle_bbox(vertices: Sequence[Q4Point]) -> BoundingBox:
    """Calculate the exact clamped pixel-centre candidate rectangle."""

    if len(vertices) != 3:
        raise ValueError("triangle_bbox requires exactly three vertices")
    min_x = min(vertex.x for vertex in vertices)
    max_x = max(vertex.x for vertex in vertices)
    min_y = min(vertex.y for vertex in vertices)
    max_y = max(vertex.y for vertex in vertices)

    xmin_raw = _ceil_div(min_x - 8, 16)
    xmax_raw = (max_x - 8) // 16
    ymin_raw = _ceil_div(min_y - 8, 16)
    ymax_raw = (max_y - 8) // 16

    if xmin_raw > xmax_raw or ymin_raw > ymax_raw:
        return BoundingBox.empty()

    xmin = max(0, xmin_raw)
    xmax = min(FB_WIDTH - 1, xmax_raw)
    ymin = max(0, ymin_raw)
    ymax = min(FB_HEIGHT - 1, ymax_raw)
    if xmin > xmax or ymin > ymax:
        return BoundingBox.empty()
    return BoundingBox(xmin, xmax, ymin, ymax)


def iter_bbox_pixels(bbox: BoundingBox) -> Iterable[tuple[int, int]]:
    if bbox.is_empty:
        return
    assert bbox.xmin is not None
    assert bbox.xmax is not None
    assert bbox.ymin is not None
    assert bbox.ymax is not None
    for y in range(bbox.ymin, bbox.ymax + 1):
        for x in range(bbox.xmin, bbox.xmax + 1):
            yield x, y


def triangle_coverage(vertices: Sequence[Q4Point]) -> TriangleCoverage:
    """Return deterministic row-major candidate and covered pixel coordinates."""

    if len(vertices) != 3:
        raise ValueError("triangle_coverage requires exactly three vertices")
    v0, v1, v2 = vertices
    area = triangle_area(v0, v1, v2)
    classification = classify_area(area)
    if classification is not TriangleClassification.ACCEPTED:
        return TriangleCoverage(classification, area, BoundingBox.empty(), (), ())

    bbox = triangle_bbox(vertices)
    candidates = tuple(iter_bbox_pixels(bbox))
    covered = tuple(
        (x, y)
        for x, y in candidates
        if all(
            edge_contains(a, b, pixel_center_q4(x, y))
            for a, b in ((v0, v1), (v1, v2), (v2, v0))
        )
    )
    return TriangleCoverage(classification, area, bbox, candidates, covered)
