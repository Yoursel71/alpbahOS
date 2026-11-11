#!/usr/bin/env python3
"""trace_logo_svg.py -- the alpbahOS logo as SVG (user request 2026-11-11).

Mark (mountain, snow face, ">" prompt, "_" cursor): traced with potrace from docs/assets/alpbahOS-logo.png (296x359).
Each colour layer is traced from its own mask (soft coverage, upscaled 8x, smoothed, thresholded); bottom to top:
  navy  -- the whole mark silhouette (every non-background pixel), so the layers above leave no gaps
  cyan  -- the snow face;  white -- ">";  orange -- "_"
Wordmark: the live wordmark of D155 ("alpbah" + "OS" in Inter Bold, as branding/plymouth-theme renders it), not the
low-resolution lettering of the PNG: the text is rendered 8x with Pillow from Inter-Bold.ttf (Inter 4.1) and traced,
so it is a real outline and needs no font at display time. Layout as live_wordmark() in
branding/alpbahos-brand/tools/build_brand_wallpaper.py: the trimmed mark, a gap of 12 % of its height, the wordmark at
56 px, both centred, in the PNG's pixel units.
Outputs (branding/alpbahos-brand/logo/):
  alpbahOS-logo.svg       light backgrounds: "alpbah" navy, "OS" cyan
  alpbahOS-logo-dark.svg  dark backgrounds (D155): "alpbah" #f4f8fb, "OS" #00aeef
  alpbahOS-mark.svg       the mark only
Colours: the mark's are the medians of each layer's core pixels in the PNG; the wordmark's are D155's.
Host tools: python3 + Pillow, potrace (version written into the SVG comment).
Usage: python3 -B trace_logo_svg.py [--inter DIR]
"""
from __future__ import annotations

import argparse
import re
import statistics
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent.parent
SRC = REPO / "docs" / "assets" / "alpbahOS-logo.png"
OUT = HERE.parent / "logo"
INTER_DEFAULT = Path("/home/yrslf/alpbahOS/scratch-lfs-bench/d-fonts/x-inter/extras/ttf")
SCALE = 8
BG = (20, 20, 20)
WORD_PX = 56                       # branding/plymouth-theme/tools/build_plymouth_theme.py WORD_PX
WORD_LIGHT, WORD_OS = "#f4f8fb", "#00aeef"
POTRACE = ["potrace", "-s", "--flat", "-t", "24", "-a", "1.0", "-O", "0.6"]


def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def classify(p):
    r, g, b = p
    if dist(p, BG) < 26:
        return None
    if r > 200 and g > 200 and b > 200:
        return "white"
    if r > 170 and 90 < g < 200 and b < 90:
        return "orange"
    if r < 60 and g > 100 and b > 170:
        return "cyan"
    return "navy"


def coverage(p, a, b):
    """How far p lies from colour a towards colour b (0..1): the anti-aliased edge pixels of the PNG carry the
    sub-pixel position of the edge, which a yes/no classification would lose (jagged diagonals)."""
    ab = [y - x for x, y in zip(a, b)]
    n = sum(v * v for v in ab) or 1
    t = sum((pc - ac) * v for pc, ac, v in zip(p, a, ab)) / n
    return max(0.0, min(1.0, t))


def mask_of(im, cov, blur=0.15):
    """cov(pixel, x, y) -> 0..1 coverage; upscaled 8x with bicubic interpolation, lightly smoothed, cut at 50 %."""
    m = Image.new("L", im.size, 0)
    src, dst = im.load(), m.load()
    for y in range(im.height):
        for x in range(im.width):
            dst[x, y] = round(255 * cov(src[x, y], x, y))
    big = m.resize((im.width * SCALE, im.height * SCALE), Image.BICUBIC)
    big = big.filter(ImageFilter.GaussianBlur(SCALE * blur))
    return big.point(lambda v: 255 if v >= 128 else 0)


def trace(mask: Image.Image, opts=POTRACE) -> list[str]:
    """Path data in the mask's own pixel grid (potrace's flipped, 10x units are undone by the caller's transform)."""
    with tempfile.TemporaryDirectory() as tmp:
        pbm = Path(tmp) / "m.pbm"
        mask.point(lambda v: 0 if v else 255).convert("1").save(pbm)
        svg = subprocess.run(opts + ["-o", "-", str(pbm)], check=True, capture_output=True, text=True).stdout
    return [" ".join(p.split()) for p in re.findall(r'<path d="([^"]+)"', svg, re.S)]


def median_colour(im, layer):
    px = [p for p in (im.load()[x, y] for y in range(im.height) for x in range(im.width)) if classify(p) == layer]
    meds = [statistics.median(ch) for ch in zip(*px)]
    core = [p for p in px if all(abs(c - m) < 40 for c, m in zip(p, meds))] or px
    return "#%02x%02x%02x" % tuple(round(statistics.median(ch)) for ch in zip(*core))


def text_mask(text: str, font: ImageFont.FreeTypeFont) -> tuple[Image.Image, int]:
    asc, desc = font.getmetrics()
    w = round(font.getlength(text)) + 4 * SCALE
    img = Image.new("L", (w, asc + desc + 4 * SCALE), 0)
    ImageDraw.Draw(img).text((2 * SCALE, 2 * SCALE), text, font=font, fill=255)
    return img.point(lambda v: 255 if v >= 128 else 0), 2 * SCALE


def path_el(fill, d, height_px, dx=0.0, dy=0.0):
    """potrace path (units 0.1 px of a bitmap height_px tall, y up) -> source pixel units, offset by (dx, dy)."""
    return (f'<path fill="{fill}" transform="translate({dx:.3f},{dy:.3f}) scale({1 / SCALE}) '
            f'translate(0,{height_px}) scale(0.1,-0.1)" d="{d}"/>')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--inter", type=Path, default=INTER_DEFAULT)
    a = ap.parse_args()
    im = Image.open(SRC).convert("RGB")
    version = subprocess.run(["potrace", "--version"], capture_output=True, text=True).stdout.splitlines()[0]
    rows = [y for y in range(im.height) if any(classify(im.load()[x, y]) for x in range(im.width))]
    cut = next(rows[i] for i in range(1, len(rows)) if rows[i] - rows[i - 1] > 1)   # first row of the PNG wordmark
    colours = {k: median_colour(im, k) for k in ("navy", "cyan", "white", "orange")}
    in_mark = lambda y: y < cut
    navy_c, cyan_c = (tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in (colours["navy"], colours["cyan"]))
    white_c, orange_c = (tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in (colours["white"], colours["orange"]))
    near = lambda x, y, kind: any(classify(im.load()[i, j]) == kind
                                  for i in range(max(0, x - 2), min(im.width, x + 3))
                                  for j in range(max(0, y - 2), min(im.height, y + 3)))
    layers = {
        # silhouette: distance from the background box towards navy (any non-background colour counts as full)
        "navy": mask_of(im, lambda p, x, y: in_mark(y) and (1.0 if classify(p) not in (None, "navy") else
                                                            coverage(p, BG, navy_c)), blur=0.4),
        "cyan": mask_of(im, lambda p, x, y: in_mark(y) and near(x, y, "cyan") and coverage(p, navy_c, cyan_c)),
        "white": mask_of(im, lambda p, x, y: in_mark(y) and near(x, y, "white") and coverage(p, navy_c, white_c)),
        "orange": mask_of(im, lambda p, x, y: in_mark(y) and near(x, y, "orange") and coverage(p, navy_c, orange_c)),
    }
    traced = {k: trace(m) for k, m in layers.items()}
    H8 = im.height * SCALE
    pts = [(x, y) for y in range(cut) for x in range(im.width) if classify(im.load()[x, y])]
    mx0, my0 = min(p[0] for p in pts), min(p[1] for p in pts)
    mx1, my1 = max(p[0] for p in pts) + 1, max(p[1] for p in pts) + 1
    mark_w, mark_h = mx1 - mx0, my1 - my0

    # wordmark: Inter Bold at WORD_PX, rendered 8x and traced
    font = ImageFont.truetype(str(a.inter / "Inter-Bold.ttf"), WORD_PX * SCALE)
    word = {}
    x = 0.0
    inks = []
    for part in ("alpbah", "OS"):
        mask, pad = text_mask(part, font)
        word[part] = (trace(mask, ["potrace", "-s", "--flat", "-t", "2", "-a", "1.0", "-O", "0.2"]),
                      mask.height, x - pad / SCALE)
        inks.append((x - pad / SCALE, mask.getbbox()))
        x += font.getlength(part) / SCALE
    word_w = x
    asc, desc = font.getmetrics()
    ink = Image.new("L", (round(word_w * SCALE) + 8 * SCALE, (asc + desc) + 8 * SCALE), 0)
    ImageDraw.Draw(ink).text((0, 0), "alpbahOS", font=font, fill=255)
    _, iy0, _, iy1 = ink.getbbox()
    gap = round(mark_h * 0.12)
    total_w = max(mark_w, word_w)
    word_top = my0 + mark_h + gap - iy0 / SCALE        # ink top of the wordmark right under the gap
    word_left = mx0 + (mark_w - word_w) / 2
    # exact ink box of the placed wordmark (source units), from the traced masks
    wy_img = word_top - 2
    wx0 = min(word_left + dx + bb[0] / SCALE for dx, bb in inks)
    wx1 = max(word_left + dx + bb[2] / SCALE for dx, bb in inks)
    view_bottom = max(wy_img + bb[3] / SCALE for _, bb in inks)

    def svg(word_fills, with_word=True) -> str:
        pad = 2
        vx0 = min(mx0, wx0 if with_word else mx0) - pad
        vx1 = max(mx1, wx1 if with_word else mx1) + pad
        vy0, vy1 = my0 - pad, (view_bottom if with_word else my1) + pad
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vx0:.2f} {vy0:.2f} {vx1 - vx0:.2f} {vy1 - vy0:.2f}" '
               f'width="{vx1 - vx0:.0f}" height="{vy1 - vy0:.0f}">',
               f"<!-- alpbahOS logo. Mark traced from docs/assets/alpbahOS-logo.png, wordmark Inter Bold (Inter 4.1, "
               f"SIL OFL 1.1) as in D155; {version.split('.')[0]}.{version.split('.')[1][:2]} "
               f"(branding/alpbahos-brand/tools/trace_logo_svg.py). -->"]
        for k in ("navy", "cyan", "white", "orange"):
            out.append(path_el(colours[k], " ".join(traced[k]), H8))
        if with_word:
            for part, fill in zip(("alpbah", "OS"), word_fills):
                paths, h, dx = word[part]
                out.append(path_el(fill, " ".join(paths), h, word_left + dx, wy_img))
        out.append("</svg>")
        return "\n".join(out) + "\n"

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "alpbahOS-logo.svg").write_text(svg((colours["navy"], WORD_OS)), encoding="utf-8")
    (OUT / "alpbahOS-logo-dark.svg").write_text(svg((WORD_LIGHT, WORD_OS)), encoding="utf-8")
    (OUT / "alpbahOS-mark.svg").write_text(svg(None, with_word=False), encoding="utf-8")
    print("mark colours:", colours, "mark box:", (mx0, my0, mx1, my1), "word width:", round(word_w, 1))
    for f in sorted(OUT.glob("*.svg")):
        print(f.relative_to(REPO), f.stat().st_size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
