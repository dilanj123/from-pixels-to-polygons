from __future__ import annotations

import unittest

from gfx_primitives import Q4Point, TriangleClassification
from reference_renderer import (
    FRAME_PIXELS,
    AttributePlane,
    BeginFrameCommand,
    CommandError,
    DrawTriangleCommand,
    PresentCommand,
    encode_begin_frame,
    encode_draw_triangle,
    encode_nop,
    encode_present_normal,
    parse_command_stream,
    random_frame_words,
    random_regression,
    render_frame,
)


def constant_triangle(tag: int, color: tuple[int, int, int], depth: int) -> DrawTriangleCommand:
    return DrawTriangleCommand(
        tag,
        (Q4Point(8, 8), Q4Point(40, 8), Q4Point(8, 40)),
        tuple(AttributePlane(channel << 8, 0, 0) for channel in (*color, depth)),
    )


class CommandCodecTests(unittest.TestCase):
    def test_known_answer_packets_and_round_trip(self) -> None:
        draw = DrawTriangleCommand(
            0x1234,
            (Q4Point(8, 8), Q4Point(40, 8), Q4Point(8, 40)),
            (
                AttributePlane(0x4000, 0x100, 0x500),
                AttributePlane(-0x100, -0x200, -0x600),
                AttributePlane(0x7FFF, 0x300, 0x700),
                AttributePlane(-1, -0x400, -0x800),
            ),
        )
        expected = (
            0x20001234,
            0x00010008,
            0x00010028,
            0x00050008,
            0x00004000,
            0xFFFFFF00,
            0x00007FFF,
            0xFFFFFFFF,
            0x00000100,
            0xFFFFFE00,
            0x00000300,
            0xFFFFFC00,
            0x00000500,
            0xFFFFFA00,
            0x00000700,
            0xFFFFF800,
        )
        self.assertEqual(encode_nop(0x0001), (0x00000001,))
        self.assertEqual(encode_begin_frame(0xA5, 0x0002), (0x10000002, 0xA5))
        self.assertEqual(encode_present_normal(0x0003), (0x40000003, 0x00000000))
        self.assertEqual(encode_draw_triangle(draw), expected)
        parsed = parse_command_stream((*encode_nop(1), *encode_begin_frame(0xA5, 2), *expected, *encode_present_normal(3)))
        self.assertEqual(parsed[0].tag, 1)
        self.assertIsInstance(parsed[1], BeginFrameCommand)
        self.assertEqual(parsed[1].clear_rgb332, 0xA5)
        self.assertEqual(parsed[2], draw)
        self.assertEqual(parsed[3], PresentCommand(3, False))

    def test_parser_rejects_reserved_and_truncated_packets(self) -> None:
        with self.assertRaises(CommandError):
            parse_command_stream((0x00010000,))
        with self.assertRaises(CommandError):
            parse_command_stream((0x10000000,))
        with self.assertRaises(CommandError):
            parse_command_stream((0x20000000, *([0] * 5)))
        with self.assertRaises(CommandError):
            parse_command_stream((0x40000000, 0x00000002))


class FrameClearAndTriangleTests(unittest.TestCase):
    def test_clear_values_fill_all_colour_and_z_entries(self) -> None:
        for clear in (0x00, 0xFF, 0xA5):
            with self.subTest(clear=clear):
                result = render_frame((*encode_begin_frame(clear), *encode_present_normal()))
                self.assertEqual(len(result.framebuffer), FRAME_PIXELS)
                self.assertEqual(len(result.zbuffer), FRAME_PIXELS)
                self.assertEqual(result.framebuffer, bytes([clear]) * FRAME_PIXELS)
                self.assertEqual(result.zbuffer, b"\xFF" * FRAME_PIXELS)

    def test_constant_triangle_updates_exact_covered_samples(self) -> None:
        command = constant_triangle(1, (64, 128, 192), 16)
        result = render_frame((*encode_begin_frame(0xA5), *encode_draw_triangle(command), *encode_present_normal()))
        expected_pixels = {(0, 0), (1, 0), (0, 1)}
        for y in range(240):
            for x in range(320):
                index = y * 320 + x
                if (x, y) in expected_pixels:
                    self.assertEqual(result.framebuffer[index], 0x53)
                    self.assertEqual(result.zbuffer[index], 16)
                else:
                    self.assertEqual(result.framebuffer[index], 0xA5)
                    self.assertEqual(result.zbuffer[index], 0xFF)

    def test_direct_colour_and_z_plane_interpolation(self) -> None:
        command = DrawTriangleCommand(
            1,
            (Q4Point(8, 8), Q4Point(40, 8), Q4Point(8, 40)),
            (
                AttributePlane(0, 64 * 256, 128 * 256),
                AttributePlane(200 * 256, -100 * 256, -50 * 256),
                AttributePlane(300 * 256, 50 * 256, -400 * 256),
                AttributePlane(1 * 256, 1 * 256, -1 * 256),
            ),
        )
        result = render_frame((*encode_begin_frame(0), *encode_draw_triangle(command), *encode_present_normal()))
        expected = {
            (0, 0): (0x1B, 1),
            (1, 0): (0x4F, 2),
            (0, 1): (0x90, 0),
        }
        for (x, y), (color, depth) in expected.items():
            index = y * 320 + x
            self.assertEqual((result.framebuffer[index], result.zbuffer[index]), (color, depth))

    def test_colour_and_z_clamps(self) -> None:
        command = DrawTriangleCommand(
            1,
            (Q4Point(8, 8), Q4Point(40, 8), Q4Point(8, 40)),
            (
                AttributePlane(-1000 * 256, 0, 0),
                AttributePlane(1000 * 256, 0, 0),
                AttributePlane(1000 * 256, 0, 0),
                AttributePlane(1000 * 256, 0, 0),
            ),
        )
        result = render_frame((*encode_begin_frame(0), *encode_draw_triangle(command), *encode_present_normal()))
        self.assertEqual(result.framebuffer[0], 0x1F)
        self.assertEqual(result.zbuffer[0], 254)


class DepthAndGeometryTests(unittest.TestCase):
    def _draw_pair(self, first_depth: int, second_depth: int, first_color: tuple[int, int, int], second_color: tuple[int, int, int]) -> tuple[bytes, bytes]:
        first = constant_triangle(1, first_color, first_depth)
        second = constant_triangle(2, second_color, second_depth)
        result = render_frame((*encode_begin_frame(0), *encode_draw_triangle(first), *encode_draw_triangle(second), *encode_present_normal()))
        return result.framebuffer, result.zbuffer

    def test_near_far_and_equal_depth_ordering(self) -> None:
        framebuffer, zbuffer = self._draw_pair(100, 10, (255, 0, 0), (0, 0, 255))
        self.assertEqual((framebuffer[0], zbuffer[0]), (0x03, 10))
        framebuffer, zbuffer = self._draw_pair(10, 100, (255, 0, 0), (0, 0, 255))
        self.assertEqual((framebuffer[0], zbuffer[0]), (0xE0, 10))
        framebuffer, zbuffer = self._draw_pair(10, 10, (255, 0, 0), (0, 0, 255))
        self.assertEqual((framebuffer[0], zbuffer[0]), (0xE0, 10))

    def test_rejected_and_empty_geometry_do_not_write(self) -> None:
        degenerate = DrawTriangleCommand(1, (Q4Point(0, 0), Q4Point(16, 0), Q4Point(32, 0)), (AttributePlane(0xFFFF, 0, 0),) * 4)
        backface = DrawTriangleCommand(2, (Q4Point(0, 0), Q4Point(0, 16), Q4Point(16, 0)), (AttributePlane(0, 0, 0),) * 4)
        empty = DrawTriangleCommand(3, (Q4Point(0, 0), Q4Point(7, 0), Q4Point(0, 7)), (AttributePlane(0, 0, 0),) * 4)
        result = render_frame((*encode_begin_frame(0x5A), *encode_draw_triangle(degenerate), *encode_draw_triangle(backface), *encode_draw_triangle(empty), *encode_present_normal()))
        self.assertEqual(result.framebuffer, bytes([0x5A]) * FRAME_PIXELS)
        self.assertEqual(result.zbuffer, b"\xFF" * FRAME_PIXELS)

    def test_multi_triangle_frame_exact_overlap(self) -> None:
        first = constant_triangle(1, (255, 0, 0), 100)
        second = DrawTriangleCommand(
            2,
            (Q4Point(24, 8), Q4Point(56, 8), Q4Point(24, 40)),
            tuple(AttributePlane(channel << 8, 0, 0) for channel in (0, 0, 255, 50)),
        )
        result = render_frame((*encode_begin_frame(0x11), *encode_draw_triangle(first), *encode_draw_triangle(second), *encode_present_normal()))
        expected = {(0, 0): (0xE0, 100), (0, 1): (0xE0, 100), (1, 0): (0x03, 50), (1, 1): (0x03, 50), (2, 0): (0x03, 50)}
        for y in range(240):
            for x in range(320):
                index = y * 320 + x
                self.assertEqual((result.framebuffer[index], result.zbuffer[index]), expected.get((x, y), (0x11, 0xFF)))

    def test_empty_frame(self) -> None:
        result = render_frame((*encode_begin_frame(0xC3), *encode_nop(7), *encode_present_normal(8)))
        self.assertEqual(result.framebuffer, bytes([0xC3]) * FRAME_PIXELS)
        self.assertEqual(result.zbuffer, b"\xFF" * FRAME_PIXELS)


class RandomRegressionTests(unittest.TestCase):
    def test_fixed_seed_regression_is_repeatable(self) -> None:
        seeds = (1, 7, 42)
        first = random_regression(seeds)
        second = random_regression(seeds)
        self.assertEqual(first, second)
        for seed, framebuffer_hash, zbuffer_hash in first:
            print(f"seed={seed} framebuffer_sha256={framebuffer_hash} zbuffer_sha256={zbuffer_hash}")

    def test_generator_supports_one_to_forty_eight_triangles(self) -> None:
        for seed, count in ((101, 1), (102, 7), (103, 48)):
            words = random_frame_words(seed, count)
            commands = parse_command_stream(words)
            self.assertEqual(sum(isinstance(command, DrawTriangleCommand) for command in commands), count)
            result = render_frame(words)
            self.assertEqual(len(result.framebuffer), FRAME_PIXELS)


if __name__ == "__main__":
    unittest.main()
