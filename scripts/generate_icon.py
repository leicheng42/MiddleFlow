#!/usr/bin/env python3
"""Generate the MiddleFlow app icon without external design assets."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Resources"
ICONSET = RESOURCES / "MiddleFlow.iconset"
SIZE = 1024


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    for y in range(size):
        t = y / (size - 1)
        eased = t * t * (3 - 2 * t)
        color = tuple(round(top[i] * (1 - eased) + bottom[i] * eased) for i in range(3))
        for x in range(size):
            pixels[x, y] = color
    return image


def add_glow(base: Image.Image, center: tuple[int, int], radius: int, color: tuple[int, int, int], opacity: int) -> None:
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(*color, opacity))
    glow = glow.filter(ImageFilter.GaussianBlur(radius // 3))
    base.alpha_composite(glow)


def main() -> None:
    random.seed(42)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    mask = rounded_mask(SIZE, 232)

    background = gradient(SIZE, (31, 31, 29), (7, 7, 7)).convert("RGBA")
    canvas.paste(background, (0, 0), mask)

    # Fine grain keeps the large dark surface from looking flat.
    grain = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    grain_pixels = grain.load()
    for y in range(SIZE):
        for x in range(SIZE):
            noise = random.randint(0, 18)
            grain_pixels[x, y] = (255, 240, 220, noise)
    canvas.alpha_composite(grain)

    add_glow(canvas, (740, 250), 360, (255, 126, 35), 58)
    add_glow(canvas, (250, 760), 300, (65, 216, 166), 24)

    draw = ImageDraw.Draw(canvas, "RGBA")
    # Ambient rings.
    for radius, alpha in [(330, 24), (270, 18), (215, 14)]:
        draw.ellipse(
            (512 - radius, 512 - radius, 512 + radius, 512 + radius),
            outline=(255, 255, 255, alpha),
            width=3,
        )

    # Stylized mouse body.
    mouse = (302, 190, 722, 850)
    draw.rounded_rectangle(mouse, radius=190, fill=(18, 18, 17, 235), outline=(255, 255, 255, 40), width=4)
    draw.line((512, 190, 512, 430), fill=(255, 255, 255, 24), width=3)
    draw.line((302, 430, 722, 430), fill=(255, 255, 255, 20), width=3)

    # Center wheel becomes the voice waveform.
    wheel = (476, 260, 548, 540)
    draw.rounded_rectangle(wheel, radius=36, fill=(255, 132, 42, 238))
    for i, height in enumerate([120, 185, 245, 178, 96]):
        x = 492 + i * 12
        y1 = 400 - height / 2
        y2 = 400 + height / 2
        draw.rounded_rectangle((x, y1, x + 5, y2), radius=3, fill=(28, 18, 11, 170))

    # Bottom voice tail.
    for index, (x, height, alpha) in enumerate(
        [(380, 70, 230), (430, 128, 238), (480, 205, 255), (530, 150, 238), (580, 96, 220), (630, 56, 190)]
    ):
        half = height / 2
        draw.rounded_rectangle(
            (x, 630 - half, x + 18, 630 + half),
            radius=9,
            fill=(255, 139, 52, alpha),
        )

    # Outer rim and soft top highlight.
    draw.rounded_rectangle((8, 8, SIZE - 9, SIZE - 9), radius=226, outline=(255, 255, 255, 54), width=4)
    draw.arc((28, 24, SIZE - 28, SIZE - 24), 200, 340, fill=(255, 255, 255, 54), width=3)

    RESOURCES.mkdir(parents=True, exist_ok=True)
    ICONSET.mkdir(exist_ok=True)
    master = RESOURCES / "MiddleFlow-1024.png"
    canvas.save(master, "PNG")

    for size in [16, 32, 64, 128, 256, 512, 1024]:
        image = canvas.resize((size, size), Image.LANCZOS)
        image.save(ICONSET / f"icon_{size}x{size}.png")
        if size <= 512:
            image2 = canvas.resize((size * 2, size * 2), Image.LANCZOS)
            image2.save(ICONSET / f"icon_{size}x{size}@2x.png")

    print(master)
    print(ICONSET)


if __name__ == "__main__":
    main()
