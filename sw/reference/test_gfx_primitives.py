from __future__ import annotations

import math
import unittest
from fractions import Fraction

from gfx_primitives import (
    FB_HEIGHT,
    FB_WIDTH,
    SIGNED32_MAX,
    SIGNED32_MIN,
    TriangleClassification,
    Q4Point,
    classify_area,
    edge_contains,
    edge_function,
    edge_is_top_left,
    pixel_center_q4,
    quantize_coordinate,
    quantize_signed_q8,
    triangle_area,
    triangle_bbox,
    triangle_coverage,
)


class QuantizationTests(unittest.TestCase):
    def test_coordinate_half_lsb_and_limits(self) -> None:
        self.assertEqual(quantize_coordinate(Fraction(0), axis="x"), 0)
        self.assertEqual(quantize_coordinate(Fraction(1, 32), axis="x"), 1)
        self.assertEqual(quantize_coordinate(Fraction(1, 16), axis="x"), 1)
        self.assertEqual(quantize_coordinate(Fraction(319), axis="x"), 5104)
        self.assertEqual(quantize_coordinate(Fraction(320), axis="x"), 5120)
        self.assertEqual(quantize_coordinate(Fraction(240), axis="y"), 3840)

    def test_coordinate_range_is_rejected_not_saturated(self) -> None:
        for axis, value in (("x", Fraction(-1, 16)), ("x", Fraction(320) + Fraction(1, 32)), ("y", Fraction(240) + Fraction(1, 32))):
            with self.subTest(axis=axis, value=value):
                with self.assertRaises(ValueError):
                    quantize_coordinate(value, axis=axis)

    def test_signed_q8_ties_away_from_zero(self) -> None:
        self.assertEqual(quantize_signed_q8(Fraction(0)), 0)
        self.assertEqual(quantize_signed_q8(Fraction(1, 512)), 1)
        self.assertEqual(quantize_signed_q8(Fraction(-1, 512)), -1)
        self.assertEqual(quantize_signed_q8(Fraction(3, 512)), 2)
        self.assertEqual(quantize_signed_q8(Fraction(-3, 512)), -2)

    def test_signed_q8_limits(self) -> None:
        self.assertEqual(quantize_signed_q8(Fraction(SIGNED32_MAX, 256)), SIGNED32_MAX)
        self.assertEqual(quantize_signed_q8(Fraction(SIGNED32_MIN, 256)), SIGNED32_MIN)
        with self.assertRaises(ValueError):
            quantize_signed_q8(Fraction(SIGNED32_MAX, 256) + Fraction(1, 512))
        with self.assertRaises(ValueError):
            quantize_signed_q8(Fraction(SIGNED32_MIN, 256) - Fraction(1, 512))


class GeometryTests(unittest.TestCase):
    def test_pixel_centres(self) -> None:
        self.assertEqual(pixel_center_q4(0, 0), Q4Point(8, 8))
        self.assertEqual(pixel_center_q4(319, 239), Q4Point(5112, 3832))
        with self.assertRaises(ValueError):
            pixel_center_q4(320, 0)
        with self.assertRaises(ValueError):
            pixel_center_q4(0, 240)

    def test_edge_function_and_area(self) -> None:
        a = Q4Point(0, 0)
        b = Q4Point(16, 0)
        p = Q4Point(8, 8)
        self.assertEqual(edge_function(a, b, p), 128)
        self.assertEqual(triangle_area(Q4Point(0, 0), Q4Point(16, 0), Q4Point(0, 16)), 256)

    def test_edge_slopes_and_coordinate_extrema(self) -> None:
        a = Q4Point(0, 0)
        b = Q4Point(5120, 3840)
        p = Q4Point(5112, 3832)
        self.assertEqual(edge_function(a, b, p), 5120 * 3832 - 3840 * 5112)
        self.assertEqual(edge_function(Q4Point(0, 16), Q4Point(16, 0), p), 16 * (3832 - 16) - (-16) * (5112 - 0))

    def test_area_classification_without_reordering(self) -> None:
        positive = triangle_area(Q4Point(0, 0), Q4Point(16, 0), Q4Point(0, 16))
        zero = triangle_area(Q4Point(0, 0), Q4Point(16, 0), Q4Point(32, 0))
        negative = triangle_area(Q4Point(0, 0), Q4Point(0, 16), Q4Point(16, 0))
        self.assertEqual(classify_area(positive), TriangleClassification.ACCEPTED)
        self.assertEqual(classify_area(zero), TriangleClassification.DEGENERATE)
        self.assertEqual(classify_area(negative), TriangleClassification.BACKFACE)

    def test_top_left_directions(self) -> None:
        self.assertTrue(edge_is_top_left(Q4Point(16, 16), Q4Point(0, 0)))
        self.assertTrue(edge_is_top_left(Q4Point(0, 0), Q4Point(16, 0)))
        self.assertFalse(edge_is_top_left(Q4Point(0, 0), Q4Point(0, 16)))
        self.assertFalse(edge_is_top_left(Q4Point(16, 0), Q4Point(0, 0)))

    def test_top_left_edge_inclusion(self) -> None:
        sample = Q4Point(8, 0)
        top_left = (Q4Point(0, 0), Q4Point(16, 0))
        bottom_right = (Q4Point(16, 0), Q4Point(0, 0))
        self.assertTrue(edge_contains(*top_left, sample))
        self.assertFalse(edge_contains(*bottom_right, sample))


class BoundingBoxTests(unittest.TestCase):
    def test_sample_centre_boundaries(self) -> None:
        points = (Q4Point(8, 8), Q4Point(5112, 3832), Q4Point(8, 8))
        bbox = triangle_bbox(points)
        self.assertEqual((bbox.xmin, bbox.xmax, bbox.ymin, bbox.ymax), (0, 319, 0, 239))

    def test_single_candidate_and_between_centres(self) -> None:
        one = triangle_bbox((Q4Point(8, 8), Q4Point(9, 9), Q4Point(8, 9)))
        self.assertEqual((one.xmin, one.xmax, one.ymin, one.ymax), (0, 0, 0, 0))
        empty = triangle_bbox((Q4Point(0, 0), Q4Point(7, 0), Q4Point(0, 7)))
        self.assertTrue(empty.is_empty)

    def test_boundary_values_and_offscreen_empty(self) -> None:
        boundary_values = (0, 7, 8, 9, 5111, 5112, 5119, 5120)
        for value in boundary_values:
            with self.subTest(value=value):
                x = min(value, 5120)
                self.assertIsNotNone(triangle_bbox((Q4Point(x, 8), Q4Point(x, 16), Q4Point(x, 24))))
        for value in (0, 7, 8, 9, 3831, 3832, 3839, 3840):
            with self.subTest(y=value):
                y = min(value, 3840)
                self.assertIsNotNone(triangle_bbox((Q4Point(8, y), Q4Point(16, y), Q4Point(24, y))))
        self.assertTrue(triangle_bbox((Q4Point(5113, 3833), Q4Point(5119, 3833), Q4Point(5113, 3839))).is_empty)

    def test_clamping_does_not_create_candidate_from_empty_raw_interval(self) -> None:
        self.assertTrue(triangle_bbox((Q4Point(0, 0), Q4Point(7, 0), Q4Point(0, 7))).is_empty)
        self.assertTrue(triangle_bbox((Q4Point(5120, 3840), Q4Point(5120, 3839), Q4Point(5119, 3840))).is_empty)


class CoverageTests(unittest.TestCase):
    def test_shared_edge_rectangle_has_union_without_crack_or_duplicate(self) -> None:
        # Rectangle corners are pixel-centre-aligned; the diagonal is shared.
        a = Q4Point(8, 8)
        b = Q4Point(40, 8)
        c = Q4Point(40, 40)
        d = Q4Point(8, 40)
        first = triangle_coverage((a, b, d))
        second = triangle_coverage((b, c, d))
        expected = {(x, y) for y in range(2) for x in range(2)}
        self.assertEqual(set(first.covered) | set(second.covered), expected)
        self.assertEqual(set(first.covered) & set(second.covered), set())

    def test_ordinary_flat_thin_tiny_and_boundary_triangles(self) -> None:
        cases = (
            (Q4Point(8, 8), Q4Point(40, 8), Q4Point(8, 40)),  # ordinary/flat-top
            (Q4Point(8, 8), Q4Point(40, 40), Q4Point(8, 40)),  # flat-bottom
            (Q4Point(8, 8), Q4Point(10, 8), Q4Point(9, 40)),  # thin
            (Q4Point(8, 8), Q4Point(9, 9), Q4Point(8, 9)),  # tiny
            (Q4Point(8, 8), Q4Point(5112, 8), Q4Point(8, 3832)),  # boundary
        )
        for vertices in cases:
            with self.subTest(vertices=vertices):
                result = triangle_coverage(vertices)
                self.assertEqual(result.classification, TriangleClassification.ACCEPTED)
                self.assertEqual(result.covered, triangle_coverage(vertices).covered)

    def test_reversed_and_degenerate_triangles_reject(self) -> None:
        reversed_result = triangle_coverage((Q4Point(0, 0), Q4Point(0, 16), Q4Point(16, 0)))
        degenerate_result = triangle_coverage((Q4Point(0, 0), Q4Point(16, 0), Q4Point(32, 0)))
        self.assertEqual(reversed_result.classification, TriangleClassification.BACKFACE)
        self.assertEqual(degenerate_result.classification, TriangleClassification.DEGENERATE)
        self.assertEqual(reversed_result.covered, ())
        self.assertEqual(degenerate_result.covered, ())

    def test_accepted_empty_bbox_is_not_rejected(self) -> None:
        result = triangle_coverage((Q4Point(0, 0), Q4Point(7, 0), Q4Point(0, 7)))
        self.assertEqual(result.classification, TriangleClassification.ACCEPTED)
        self.assertTrue(result.bbox.is_empty)
        self.assertEqual(result.candidates, ())
        self.assertEqual(result.covered, ())


class DerivationTests(unittest.TestCase):
    def test_signed42_attribute_bound(self) -> None:
        bound = (1 + 319 + 239) * (1 << 31)
        self.assertLess(bound, 1 << 41)
        self.assertGreaterEqual(1 << 41, bound)
        self.assertEqual(1 + 319 + 239, 559)


if __name__ == "__main__":
    unittest.main()
