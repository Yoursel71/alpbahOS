"""Generate a colored terminal logo from the alpbahOS PNG.

The output uses ANSI truecolor and half-block characters. It is intended for
terminal previews and fastfetch/neofetch-style logo files.
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image


RESET = "\x1b[0m"
BG = (11, 16, 20)


def near_background(rgb: tuple[int, int, int], reference: tuple[int, int, int]) -> bool:
    distance = math.sqrt(sum((a - b) ** 2 for a, b in zip(rgb, reference)))
    return distance < 18


def rgb_escape(kind: str, rgb: tuple[int, int, int]) -> str:
    return f"\x1b[{38 if kind == 'fg' else 48};2;{rgb[0]};{rgb[1]};{rgb[2]}m"


def render(path: Path, width: int) -> str:
    image = Image.open(path).convert("RGB")

    # The supplied logo is a dark rectangular image. Crop only the unused edge
    # margin while keeping the complete mark and wordmark.
    image = image.crop((8, 20, image.width - 8, image.height - 14))
    reference = image.getpixel((0, 0))

    target_height = max(2, round(image.height * width / image.width))
    image = image.resize((width, target_height), Image.Resampling.LANCZOS)

    rows: list[str] = []
    for y in range(0, image.height, 2):
        row: list[str] = []
        for x in range(image.width):
            top = image.getpixel((x, y))
            bottom = image.getpixel((x, min(y + 1, image.height - 1)))

            top_is_bg = near_background(top, reference)
            bottom_is_bg = near_background(bottom, reference)

            if top_is_bg and bottom_is_bg:
                row.append(" ")
            elif bottom_is_bg:
                row.append(rgb_escape("fg", top) + "▀")
            elif top_is_bg:
                row.append(rgb_escape("fg", bottom) + "▄")
            else:
                row.append(rgb_escape("fg", top) + rgb_escape("bg", bottom) + "▀")
        rows.append("".join(row) + RESET)

    return "\n".join(rows) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Render alpbahOS logo as ANSI half-block art")
    parser.add_argument("image", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--width", type=int, default=48)
    args = parser.parse_args()

    if args.width < 16 or args.width > 120:
        raise SystemExit("--width 16 ile 120 arasında olmalı")

    args.output.write_text(render(args.image, args.width), encoding="utf-8")
    print(f"Yazıldı: {args.output}")


if __name__ == "__main__":
    main()
