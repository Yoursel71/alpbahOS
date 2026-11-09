#!/usr/bin/env python3
"""REBUILD-R8 evidence tool: renders captured terminal output (SGR colour codes only) to a PNG with PIL.

Handles ESC[...m with 0, 1, 30-37, 40-47, 90-97, 100-107, 38;5;N and 48;5;N. Other sequences are dropped.
Usage: ansi-render-r8.py <INPUT_ANSI> <OUTPUT_PNG>
"""
import re
import sys
from PIL import Image, ImageDraw, ImageFont
SRC, OUT = sys.argv[1], sys.argv[2]
BASE = [(0, 0, 0), (205, 0, 0), (0, 205, 0), (205, 205, 0), (0, 0, 238), (205, 0, 205), (0, 205, 205),
        (229, 229, 229), (127, 127, 127), (255, 0, 0), (0, 255, 0), (255, 255, 0), (92, 92, 255),
        (255, 0, 255), (0, 255, 255), (255, 255, 255)]


def c256(n):
    if n < 16:
        return BASE[n]
    if n < 232:
        n -= 16
        steps = [0, 95, 135, 175, 215, 255]
        return (steps[n // 36], steps[(n // 6) % 6], steps[n % 6])
    v = 8 + 10 * (n - 232)
    return (v, v, v)


FONT = None
for cand in ("/usr/share/fonts/dejavu/DejaVuSansMono.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"):
    try:
        FONT = ImageFont.truetype(cand, 16)
        break
    except OSError:
        pass
if FONT is None:
    FONT = ImageFont.load_default()
text = open(SRC, "r", encoding="utf-8", errors="replace").read()
lines = text.split("\n")
CW, CH = 10, 19
W = max(len(re.sub(r"\x1b\[[0-9;]*m", "", ln)) for ln in lines) + 2
img = Image.new("RGB", (W * CW, len(lines) * CH + 8), (16, 16, 16))
draw = ImageDraw.Draw(img)
for row, ln in enumerate(lines):
    fg, bg, bold, col = (220, 220, 220), None, False, 0
    pos = 0
    for m in re.finditer(r"\x1b\[([0-9;]*)m|([^\x1b]+)", ln):
        if m.group(2) is not None:
            for ch in m.group(2):
                x, y = col * CW, row * CH + 4
                if bg is not None:
                    draw.rectangle([x, y, x + CW - 1, y + CH - 1], fill=bg)
                if ch == "█":
                    draw.rectangle([x, y, x + CW - 1, y + CH - 1], fill=fg)
                elif ch != " ":
                    draw.text((x, y), ch, font=FONT, fill=fg)
                col += 1
            continue
        codes = [int(c) if c else 0 for c in m.group(1).split(";")]
        i = 0
        while i < len(codes):
            c = codes[i]
            if c == 0:
                fg, bg, bold = (220, 220, 220), None, False
            elif c == 1:
                bold = True
            elif 30 <= c <= 37:
                fg = BASE[c - 30]
            elif 90 <= c <= 97:
                fg = BASE[c - 90 + 8]
            elif 40 <= c <= 47:
                bg = BASE[c - 40]
            elif 100 <= c <= 107:
                bg = BASE[c - 100 + 8]
            elif c in (38, 48) and i + 2 < len(codes) and codes[i + 1] == 5:
                rgb = c256(codes[i + 2])
                if c == 38:
                    fg = rgb
                else:
                    bg = rgb
                i += 2
            i += 1
img.save(OUT)
print("rendered", OUT, img.size)
