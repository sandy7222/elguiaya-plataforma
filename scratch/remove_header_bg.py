"""Quita el fondo azul oscuro del banner header de El Guía YA."""

from __future__ import annotations

import os
from collections import Counter

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INPUT_PATH = os.path.join(ROOT, "assets", "images", "logo_elguiaya_header.png")
OUTPUT_PATH = INPUT_PATH


def sample_background_color(img: Image.Image) -> tuple[int, int, int]:
    pixels = img.load()
    width, height = img.size
    samples: list[tuple[int, int, int]] = []
    margin = max(2, min(width, height) // 40)

    for x in range(margin, width - margin, max(1, width // 20)):
        for y in (margin, height - margin - 1):
            r, g, b, _ = pixels[x, y]
            samples.append((r, g, b))

    for y in range(margin, height - margin, max(1, height // 20)):
        for x in (margin, width - margin - 1):
            r, g, b, _ = pixels[x, y]
            samples.append((r, g, b))

    return Counter(samples).most_common(1)[0][0]


def color_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def remove_background(
    input_path: str,
    output_path: str,
    tolerance: float = 28.0,
    feather: float = 1.2,
) -> None:
    img = Image.open(input_path).convert("RGBA")
    bg = sample_background_color(img)
    pixels = img.load()
    width, height = img.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            dist = color_distance((r, g, b), bg)

            if dist <= tolerance:
                pixels[x, y] = (r, g, b, 0)
            elif dist <= tolerance + feather:
                blend = (dist - tolerance) / feather
                new_alpha = int(a * blend)
                pixels[x, y] = (r, g, b, new_alpha)

    alpha = img.split()[3]
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))
    img.putalpha(alpha)

    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)

    img.save(output_path, "PNG")
    print(f"Background color sampled: {bg}")
    print(f"Saved transparent logo to {output_path} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    remove_background(INPUT_PATH, OUTPUT_PATH)
