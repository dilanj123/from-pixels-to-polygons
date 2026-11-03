#!/usr/bin/env python3
"""Generate independent full-frame vectors for GFX-021 integration."""

from pathlib import Path
import random
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "ip/rtl-to-pixels/tb/reference"))
from sobel_reference import sobel_rgb  # noqa: E402

WIDTH, HEIGHT = 320, 240
PIXELS = WIDTH * HEIGHT


def expand_rgb332(pixel: int) -> tuple[int, int, int]:
    r3, g3, b2 = (pixel >> 5) & 7, (pixel >> 2) & 7, pixel & 3
    return ((r3 << 5) | (r3 << 2) | (r3 >> 1),
            (g3 << 5) | (g3 << 2) | (g3 >> 1),
            (b2 << 6) | (b2 << 4) | (b2 << 2) | b2)


def pack_edge(edge: int) -> int:
    return (((edge >> 5) & 7) << 5) | (((edge >> 5) & 7) << 2) | ((edge >> 6) & 3)


def write_hex(path: Path, data: np.ndarray) -> None:
    path.write_text("".join(f"{int(v):02x}\n" for v in data.reshape(-1)))


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/gfx021_vectors")
    renderer_dir = Path(sys.argv[2] if len(sys.argv) > 2 else "/tmp/gfx012_vectors")
    out.mkdir(parents=True, exist_ok=True)
    yy, xx = np.indices((HEIGHT, WIDTH))
    images: list[np.ndarray] = []
    images.append(np.zeros((HEIGHT, WIDTH), dtype=np.uint8))
    edge = np.zeros((HEIGHT, WIDTH), dtype=np.uint8)
    edge[:, WIDTH // 3:] = 0xFF
    edge[HEIGHT // 2:, :] ^= 0xFF
    images.append(edge)
    gradient = ((xx * 3 + yy * 5) & 0xFF).astype(np.uint8)
    images.append(gradient)
    rng = random.Random(0x62021)
    images.append(np.fromiter((rng.randrange(256) for _ in range(PIXELS)), dtype=np.uint8).reshape(HEIGHT, WIDTH))
    scene = np.loadtxt(renderer_dir / "frame_0_fb.hex", dtype=np.uint8)
    if scene.size != PIXELS:
        raise ValueError(f"renderer source has {scene.size} bytes, expected {PIXELS}")
    images.append(scene.reshape(HEIGHT, WIDTH))

    configs = [(128, False), (72, False), (128, True), (210, False), (96, False)]
    for idx, (source, (threshold, bypass)) in enumerate(zip(images, configs)):
        rgb = np.empty((HEIGHT, WIDTH, 3), dtype=np.uint8)
        for byte in range(256):
            rgb[source == byte] = expand_rgb332(byte)
        edge_gray = sobel_rgb(rgb, threshold=threshold, bypass_threshold=bypass)
        packed = np.fromiter((pack_edge(int(v)) for v in edge_gray.reshape(-1)), dtype=np.uint8)
        write_hex(out / f"sobel_source_{idx}.hex", source)
        write_hex(out / f"sobel_expected_{idx}.hex", packed)
        print(f"vector={idx} threshold={threshold} bypass={int(bypass)} bytes={PIXELS}")


if __name__ == "__main__":
    main()
