"""Render an ANSI truecolor text file as a terminal-style PNG preview."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ANSI = re.compile(r"\x1b\[(?:(38|48);2;(\d+);(\d+);(\d+)|0)m")


def main() -> None:
    source = Path(sys.argv[1])
    output = Path(sys.argv[2])
    text = source.read_text(encoding="utf-8")

    font_path = Path(r"C:\Windows\Fonts\consola.ttf")
    font = ImageFont.truetype(str(font_path), 22) if font_path.exists() else ImageFont.load_default()
    cell_w, cell_h = 14, 25
    lines = text.splitlines()
    width = max(len(re.sub(r"\x1b\[[0-9;]+m", "", line)) for line in lines)
    image = Image.new("RGB", (width * cell_w + 64, len(lines) * cell_h + 100), (11, 16, 20))
    draw = ImageDraw.Draw(image)

    draw.rounded_rectangle((20, 18, image.width - 20, image.height - 18), radius=14, outline=(41, 64, 79), width=2)
    draw.ellipse((38, 34, 50, 46), fill=(255, 95, 105))
    draw.ellipse((58, 34, 70, 46), fill=(245, 166, 35))
    draw.ellipse((78, 34, 90, 46), fill=(0, 174, 239))
    draw.text((110, 28), "alpbahOS terminal preview", font=font, fill=(212, 224, 232))

    for row, raw in enumerate(lines):
        x = 34
        fg = (212, 224, 232)
        bg = (11, 16, 20)
        pos = 0
        for match in ANSI.finditer(raw):
            segment = raw[pos:match.start()]
            for char in segment:
                if char != " ":
                    draw.text((x, 68 + row * cell_h), char, font=font, fill=fg, stroke_width=0)
                x += cell_w
            if match.group(1) == "38":
                fg = tuple(map(int, match.groups()[1:4]))
            elif match.group(1) == "48":
                bg = tuple(map(int, match.groups()[1:4]))
            else:
                fg = (212, 224, 232)
                bg = (11, 16, 20)
            pos = match.end()
        for char in raw[pos:]:
            if char != " ":
                draw.text((x, 68 + row * cell_h), char, font=font, fill=fg, stroke_width=0)
            x += cell_w

    image.save(output)
    print(output)


if __name__ == "__main__":
    main()
