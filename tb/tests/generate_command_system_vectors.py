#!/usr/bin/env python3
"""Generate one public command-path triangle frame and independent image."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw" / "reference"))

from gfx_primitives import Q4Point  # noqa: E402
from reference_renderer import (  # noqa: E402
    AttributePlane,
    DrawTriangleCommand,
    encode_begin_frame,
    encode_draw_triangle,
    encode_present_normal,
    render_frame,
)

out = Path("/tmp/gfx_command_system_vectors")
out.mkdir(parents=True, exist_ok=True)
planes = (
    AttributePlane(190 * 256, 0, 0),
    AttributePlane(48 * 256, 0, 0),
    AttributePlane(120 * 256, 0, 0),
    AttributePlane(80 * 256, 0, 0),
)
draw = DrawTriangleCommand(
    0x1026,
    (Q4Point(160, 160), Q4Point(1120, 160), Q4Point(160, 960)),
    planes,
)
words = (*encode_begin_frame(0xA6, 0x1022), *encode_draw_triangle(draw),
         *encode_present_normal(0x1023))
result = render_frame(words)
(out / "command_words.hex").write_text(
    "".join(f"{word:08x}\n" for word in words), encoding="ascii"
)
(out / "framebuffer.hex").write_text(
    "".join(f"{byte:02x}\n" for byte in result.framebuffer), encoding="ascii"
)
print(f"command_path_vector words={len(words)} bytes={len(result.framebuffer)} "
      f"fb_sha256={result.framebuffer_sha256} z_sha256={result.zbuffer_sha256}")
