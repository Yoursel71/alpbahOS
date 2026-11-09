#!/usr/bin/env python3
"""REBUILD-R9: the AlpbahOS brand logo as a transparent PNG and as terminal ANSI art (truecolor).

Source: docs/assets/alpbahOS-logo.png (296x359, opaque #141414 box). The box is keyed out like
branding/alpbahos-brand/tools/build_brand_wallpaper.py (distance <= 18 transparent, ramp to 30). The source file is not
changed. Outputs:
  --png OUT.png --height H   transparent logo, height H (aspect kept)
  --ansi OUT.txt --cols C    ANSI art: half-block characters, 38;2 / 48;2 truecolor, transparent cells use the terminal
                             background (no colour code). Each text line ends with a reset.
Usage: brand-logo-r9.py <SOURCE_PNG> [--png OUT --height H] [--ansi OUT --cols C]
"""
import argparse
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("source")
ap.add_argument("--png")
ap.add_argument("--height", type=int, default=320)
ap.add_argument("--ansi")
ap.add_argument("--cols", type=int, default=40)
a = ap.parse_args()
BG = (20, 20, 20)
TOL, RAMP = 18, 12


def keyed(img):
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, al = px[x, y]
            d = ((r - BG[0]) ** 2 + (g - BG[1]) ** 2 + (b - BG[2]) ** 2) ** 0.5
            if d <= TOL:
                na = 0
            elif d >= TOL + RAMP:
                na = al
            else:
                na = int(al * (d - TOL) / RAMP)
            px[x, y] = (r, g, b, min(al, na))
    return img


src = keyed(Image.open(a.source))
if a.png:
    w = round(src.width * a.height / src.height)
    src.resize((w, a.height), Image.LANCZOS).save(a.png)
    print("png", a.png, (w, a.height))
if a.ansi:
    rows = round(src.height * a.cols / src.width / 2 * 2) // 2 * 2
    small = src.resize((a.cols, rows), Image.LANCZOS)
    p = small.load()
    out = []
    for y in range(0, rows, 2):
        line = []
        last = None
        for x in range(a.cols):
            t, b = p[x, y], p[x, y + 1]
            ta, ba = t[3] >= 128, b[3] >= 128
            if not ta and not ba:
                seq = " "
            elif ta and ba:
                seq = f"\x1b[38;2;{t[0]};{t[1]};{t[2]};48;2;{b[0]};{b[1]};{b[2]}m▀"
            elif ta:
                seq = f"\x1b[38;2;{t[0]};{t[1]};{t[2]}m▀"
            else:
                seq = f"\x1b[38;2;{b[0]};{b[1]};{b[2]}m▄"
            line.append(seq)
        out.append("".join(line) + "\x1b[0m")
    open(a.ansi, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("ansi", a.ansi, a.cols, "cols", len(out), "rows")
