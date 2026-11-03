#!/usr/bin/env python3
"""Generate a multi-size MiddleFlow ICO from the shared 1024px source art."""

from __future__ import annotations

import sys
import struct
import zlib
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    Image = None

SIZE = 256
ORANGE = (242, 106, 61, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)


def inside_rounded_rect(x: int, y: int, left: int, top: int, right: int, bottom: int, radius: int) -> bool:
    if x < left or x >= right or y < top or y >= bottom:
        return False
    cx = min(max(x, left + radius), right - radius - 1)
    cy = min(max(y, top + radius), bottom - radius - 1)
    dx = x - cx
    dy = y - cy
    return dx * dx + dy * dy <= radius * radius


def make_pixels() -> bytearray:
    pixels = bytearray(CLEAR * (SIZE * SIZE))
    bar_heights = [82, 132, 178, 112, 154]
    bar_left = 72
    for index, height in enumerate(bar_heights):
        left = bar_left + index * 25
        top = (SIZE - height) // 2
        for y in range(top, top + height):
            for x in range(left, left + 13):
                offset = (y * SIZE + x) * 4
                pixels[offset : offset + 4] = bytes(WHITE)

    for y in range(SIZE):
        for x in range(SIZE):
            if not inside_rounded_rect(x, y, 8, 8, SIZE - 8, SIZE - 8, 54):
                continue
            offset = (y * SIZE + x) * 4
            # Keep the waveform white and the tile warm orange.
            if pixels[offset + 3] == 0:
                pixels[offset : offset + 4] = bytes(ORANGE)
    return pixels


def png_bytes(pixels: bytearray) -> bytes:
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)
        start = y * SIZE * 4
        rows.extend(pixels[start : start + SIZE * 4])

    def chunk(tag: bytes, payload: bytes) -> bytes:
        body = tag + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b"")
    )


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    output = root / "src" / "MiddleFlow.Windows" / "Assets" / "MiddleFlow.ico"
    output.parent.mkdir(parents=True, exist_ok=True)
    source = root.parent / "Resources" / "MiddleFlow-1024.png"
    if Image is not None and source.exists():
        with Image.open(source) as image:
            image.convert("RGBA").save(
                output,
                format="ICO",
                sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
                bitmap_format="png",
            )
        print(output)
        return

    # The source asset is optional for a source-only checkout. Keep a
    # deterministic fallback so local builds still have a real app icon.
    print("Pillow or source PNG unavailable; writing vector fallback icon.", file=sys.stderr)
    image = png_bytes(make_pixels())
    # ICO directory entry uses 0 for a 256px dimension.
    directory = struct.pack("<BBBBHHII", 0, 0, 0, 0, 1, 32, len(image), 22)
    output.write_bytes(struct.pack("<HHH", 0, 1, 1) + directory + image)
    print(output)


if __name__ == "__main__":
    main()
