#!/usr/bin/env python3
"""scale_samples.py -- Atatürk duvar kâğıdının yaygın ekranlarda nasıl görüneceğini hesaplar (UI-03).

Plasma 6.4.4 Image duvar kâğıdı davranışı kaynaktan birebir alınmıştır:
- Görüntü seçimi: wallpapers/image/plugin/finder/packagefinder.cpp distance():
  |en-boy(aday) - en-boy(ekran)| * 25000 + genişlik farkı (aday dar ise fark x2, büyütme cezası).
- Doldurma: imagepackage/contents/config/main.xml FillMode varsayılanı 2 =
  Image.PreserveAspectCrop, ortalı ("Ölçekle ve kırp").
- Hedef boyut fiziksel pikseldir (main.qml sourceSize = boyut * Screen.devicePixelRatio): ekran
  ölçek faktörü görüntü seçimini değiştirmez, ama üst panelin fiziksel yüksekliğini büyütür.
  Bu yüzden her çözünürlük, mantıksal yüksekliği en az 720 kalan ölçek faktörlerinde de denetlenir.

Her çözünürlük için seçilen görüntü, ölçek katsayısı (>1 büyütme demektir) ve portrenin yüz
kutusunun build_wallpaper.py güvenli alan kurallarına (üst panel, dock bölgesi, sol üst simge
bölgesi, kadraj) uyup uymadığı raporlanır. Görüntüler paketteki dosyalardan okunmaz; yüz kutusu
build_wallpaper.compose() ile aynı hesaptan gelir (kaynak fotoğraf ve Pillow gerekir).

Kullanım:
    python scale_samples.py                 # tablo
    python scale_samples.py --sheet out.png # panel/dock bindirmeli örnek sayfası
    python scale_samples.py --check         # güvenli alan ihlali varsa çıkış 1
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("alpbah_wallpaper_builder", HERE / "build_wallpaper.py")
BUILDER = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(BUILDER)

# Fiziksel piksel. Dizüstü/masaüstü yaygın boyutlar, 4:3/5:4 eski ekranlar, ultra geniş ve 4K.
RESOLUTIONS = [
    (1024, 768), (1280, 720), (1280, 800), (1280, 1024), (1366, 768), (1440, 900), (1536, 864),
    (1600, 900), (1680, 1050), (1920, 1080), (1920, 1200), (2560, 1080), (2560, 1440), (2560, 1600),
    (2880, 1800), (3440, 1440), (3840, 2160), (5120, 1440),
]

SCALE_FACTORS = [1.0, 1.25, 1.5, 1.75, 2.0]
MIN_LOGICAL_HEIGHT = 720  # bunun altındaki mantıksal masaüstü gerçekçi bir yapılandırma değil


def scale_factors_for(screen: tuple[int, int]) -> list[float]:
    return [f for f in SCALE_FACTORS if f == 1.0 or screen[1] / f >= MIN_LOGICAL_HEIGHT]


def plasma_distance(candidate: tuple[int, int], desired: tuple[int, int]) -> float:
    """packagefinder.cpp distance() ile aynı."""
    desired_ratio = desired[0] / desired[1] if desired[1] > 0 else 0.0
    candidate_ratio = candidate[0] / candidate[1] if candidate[1] > 0 else float("inf")
    delta = candidate[0] - desired[0]
    delta = delta if delta >= 0 else -delta * 2
    return abs(candidate_ratio - desired_ratio) * 25000 + delta


def pick_image(sizes: list[tuple[int, int]], screen: tuple[int, int]) -> tuple[int, int]:
    best, best_dist = None, None
    for size in sizes:  # Plasma ilk en küçük mesafeyi tutar (eşitlikte önceki kalır)
        dist = plasma_distance(size, screen)
        if best is None or dist < best_dist:
            best, best_dist = size, dist
    assert best is not None
    return best


def crop_map(image: tuple[int, int], screen: tuple[int, int]) -> tuple[float, float, float]:
    """PreserveAspectCrop, ortalı: ölçek ve ekran üzerindeki kaydırma."""
    scale = max(screen[0] / image[0], screen[1] / image[1])
    return scale, (screen[0] - image[0] * scale) / 2, (screen[1] - image[1] * scale) / 2


def analyse(face_boxes: dict[tuple[int, int], tuple[int, int, int, int]],
            resolutions: list[tuple[int, int]] = RESOLUTIONS) -> list[dict]:
    rows = []
    sizes = list(face_boxes)
    for screen in resolutions:
        image = pick_image(sizes, screen)
        scale, ox, oy = crop_map(image, screen)
        fx0, fy0, fx1, fy1 = face_boxes[image]
        face = (round(fx0 * scale + ox), round(fy0 * scale + oy), round(fx1 * scale + ox), round(fy1 * scale + oy))
        problems = []
        factors = scale_factors_for(screen)
        for factor in factors:
            try:
                BUILDER.check_safe_area(screen, face, panel_height=BUILDER.PANEL_HEIGHT * factor)
            except BUILDER.CompositionError as exc:
                problems.append(f"%{round(factor * 100)}: " + str(exc).split(": ", 1)[1].split(" (yüz kutusu")[0])
        rows.append({"ekran": screen, "goruntu": image, "olcek": scale, "yuz": face, "faktorler": factors,
                     "panel_payi": face[1] - BUILDER.PANEL_HEIGHT * factors[-1], "sorun": "; ".join(problems)})
    return rows


def face_boxes_from_builder() -> tuple[dict, dict]:
    photo = BUILDER.load_source()
    images, faces = {}, {}
    for size in BUILDER.SIZES:
        images[size], faces[size] = BUILDER.compose(size, photo)
    return images, faces


def render_sheet(rows: list[dict], images: dict, out: Path, cell_w: int = 480) -> None:
    from PIL import Image, ImageDraw

    cells = []
    for row in rows:
        sw, sh = row["ekran"]
        scale, ox, oy = crop_map(row["goruntu"], row["ekran"])
        shown = images[row["goruntu"]].resize((round(row["goruntu"][0] * scale), round(row["goruntu"][1] * scale)))
        screen = Image.new("RGB", (sw, sh))
        screen.paste(shown, (round(ox), round(oy)))
        k = cell_w / sw
        cell = screen.resize((cell_w, max(1, round(sh * k))))
        draw = ImageDraw.Draw(cell, "RGBA")
        draw.rectangle((0, 0, cell_w, round(BUILDER.PANEL_HEIGHT * k)), fill=(17, 23, 28, 200))
        draw.rectangle((0, round(sh * (1 - BUILDER.DOCK_ZONE) * k), cell_w, cell.height), outline=(245, 166, 35, 160))
        fx0, fy0, fx1, fy1 = (round(v * k) for v in row["yuz"])
        draw.rectangle((fx0, fy0, fx1, fy1), outline=(255, 101, 117) if row["sorun"] else (53, 208, 127), width=2)
        label = f"{sw}x{sh} <- {row['goruntu'][0]}x{row['goruntu'][1]}  x{row['olcek']:.2f}" + (f"  {row['sorun']}" if row["sorun"] else "")
        draw.rectangle((0, cell.height - 18, cell_w, cell.height), fill=(0, 0, 0, 190))
        draw.text((6, cell.height - 15), label, fill=(244, 248, 251))
        cells.append(cell)
    cols = 3
    col_h = [0] * cols
    heights = [c.height for c in cells]
    rows_n = (len(cells) + cols - 1) // cols
    row_h = [max(heights[r * cols:(r + 1) * cols]) for r in range(rows_n)]
    sheet = Image.new("RGB", (cols * (cell_w + 8) + 8, sum(row_h) + 8 * (rows_n + 1)), (11, 16, 20))
    y = 8
    for r in range(rows_n):
        for c in range(cols):
            i = r * cols + c
            if i < len(cells):
                sheet.paste(cells[i], (8 + c * (cell_w + 8), y))
                col_h[c] += cells[i].height
        y += row_h[r] + 8
    sheet.save(out, quality=85, optimize=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--sheet", type=Path, help="panel/dock bindirmeli örnek sayfası (JPEG/PNG)")
    parser.add_argument("--check", action="store_true", help="güvenli alan ihlalinde çıkış 1")
    args = parser.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    images, faces = face_boxes_from_builder()
    rows = analyse(faces)
    print(f"{'ekran':>10}  {'görüntü':>10}  ölçek  {'faktörler':<22} panel payı  sonuç")
    for row in rows:
        s, g = row["ekran"], row["goruntu"]
        factors = "/".join(f"{round(f * 100)}" for f in row["faktorler"]) + "%"
        note = row["sorun"] or ("uygun" + (" (büyütme)" if row["olcek"] > 1.001 else ""))
        print(f"{s[0]:>5}x{s[1]:<4}  {g[0]:>5}x{g[1]:<4}  {row['olcek']:.2f}  {factors:<22} {row['panel_payi']:>6.0f} px  {note}")
    if args.sheet:
        render_sheet(rows, images, args.sheet)
        print(f"yazıldı: {args.sheet}")
    return 1 if args.check and any(r["sorun"] for r in rows) else 0


if __name__ == "__main__":
    sys.exit(main())
