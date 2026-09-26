#!/usr/bin/env python3
"""build_wallpaper.py -- Atatürk varsayılan duvar kâğıdı paketini üretir (Python 3 + Pillow).

Girdi yalnız kaynağı ve lisansı kayıtlı fotoğraftır:
`branding/ataturk-theme/source/Ataturk1930s.jpg` (PD-Turkey, SHA-256 aşağıda sabit).
Hash tutmazsa üretim durur. Fotoğrafa metin, imza veya söz eklenmez; kırpılmaz,
yalnız ölçeklenir, tonlanır ve kenarları arka plana yumuşatılır.

Kompozisyon (MASTER_PLAN §7.1, branding/ataturk-theme/README.md §3-5):
- Zemin: tasarım token'larından koyu lacivert degrade + geometrik dağ silüeti
  (docs/alpbahOS-design-mockups.md §14, alternatif 2).
- Portre: kaynak çözünürlüğünün üstüne büyütülmez (ölçek <= 1.0). 16:9/16:10'da
  ortanın sağında, 21:9'da ortada.
- Güvenli alanlar: yüz üst panelin (36 px) altında, dock bölgesinin (alt %15)
  üstünde ve sol üst simge bölgesinin (genişliğin %25'i) dışında kalır; aksi hâlde
  üretim hata verir.

Kullanım:
    python build_wallpaper.py              # paketi yeniden üretir
    python build_wallpaper.py --check      # mevcut görüntüler bu betiğin çıktısıyla aynı mı

Çıktı: branding/ataturk-theme/wallpaper/alpbahOS-Ataturk/contents/images/<G>x<Y>.jpg
ve contents/screenshot.png. Paket biçimi KDE `Wallpaper/Images` KPackage yapısıdır.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
THEME = HERE.parent
SOURCE = THEME / "source" / "Ataturk1930s.jpg"
SOURCE_SHA256 = "f1dad1a903de0d8930b44020fc77e4aea647ddd3cb21d110d447f1fe63694bbf"
PACKAGE = THEME / "wallpaper" / "alpbahOS-Ataturk"

SIZES = [(1366, 768), (1920, 1080), (1920, 1200), (2560, 1440), (3440, 1440)]
SCREENSHOT_SIZE = (400, 250)

# profiles/desktop/tokens.json
BG_950 = (0x0B, 0x10, 0x14)
NAVY = (0x06, 0x27, 0x46)
NAVY_STRONG = (0x03, 0x1A, 0x31)
SURFACE_800 = (0x16, 0x23, 0x2D)
CYAN = (0x00, 0xAE, 0xEF)
ORANGE = (0xF5, 0xA6, 0x23)
TEXT_STRONG = (0xF4, 0xF8, 0xFB)

# Kaynak fotoğrafta yüz/baş kutusu (piksel, 732x987 üzerinde elle ölçüldü).
FACE_BOX = (230, 0, 500, 360)

PANEL_HEIGHT = 36          # tokens.json panel.height_max
DOCK_ZONE = 0.15           # alt %15 dock için düşük detay
ICON_ZONE_WIDTH = 0.25     # sol üst masaüstü simgeleri
JPEG_QUALITY = 90


class CompositionError(Exception):
    pass


def lerp(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(size: tuple[int, int], top: tuple, bottom: tuple) -> Image.Image:
    width, height = size
    column = Image.new("RGB", (1, height))
    column.putdata([lerp(top, bottom, y / max(1, height - 1)) for y in range(height)])
    return column.resize(size)


def radial_glow(size: tuple[int, int], center: tuple[float, float], radius: float, color: tuple, strength: float) -> Image.Image:
    """Merkezde `strength` opaklıkta, kenara doğru sönen yumuşak ışık (RGBA)."""
    width, height = size
    scale = 8  # küçük maske üret, sonra büyüt: hızlı ve pürüzsüz
    small = Image.new("L", (max(1, width // scale), max(1, height // scale)), 0)
    draw = ImageDraw.Draw(small)
    cx, cy, r = center[0] / scale, center[1] / scale, radius / scale
    steps = 48
    for i in range(steps, 0, -1):
        t = i / steps
        alpha = round(255 * strength * (1 - t) ** 2)
        draw.ellipse((cx - r * t, cy - r * t, cx + r * t, cy + r * t), fill=alpha)
    mask = small.resize(size, Image.BILINEAR).filter(ImageFilter.GaussianBlur(radius / 12))
    layer = Image.new("RGBA", size, color + (0,))
    layer.putalpha(mask)
    return layer


def tone_portrait(photo: Image.Image) -> Image.Image:
    """Siyah-beyaz fotoğrafı marka lacivertine tonla; arka perdeyi koyulaştır."""
    gray = photo.convert("L")
    stops = [(0.0, (0x05, 0x0B, 0x11)), (0.45, (0x12, 0x2C, 0x45)), (0.75, (0x7C, 0x93, 0xA4)), (1.0, (0xE6, 0xEE, 0xF4))]
    lut_r, lut_g, lut_b = [], [], []
    for value in range(256):
        t = (value / 255) ** 1.9  # perde (~0.45-0.75) koyulaşır, yüz/gömlek parlak kalır
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t <= t1:
                color = lerp(c0, c1, (t - t0) / (t1 - t0))
                break
        lut_r.append(color[0])
        lut_g.append(color[1])
        lut_b.append(color[2])
    toned = Image.merge("RGB", (gray.point(lut_r), gray.point(lut_g), gray.point(lut_b)))
    # Yüzden uzaklaştıkça perdeyi koyulaştır: dikdörtgen kenarı zemine karışsın.
    width, height = toned.size
    shade = Image.radial_gradient("L").resize((width, height), Image.BILINEAR)
    shade = shade.point(lambda v: 255 - round(0.60 * 255 * min(1.0, max(0.0, (v - 110) / 145)) ** 1.2))
    cx, cy = round(width * 0.5), round(height * 0.33)
    vignette = Image.new("L", (width, height), 255 - round(0.60 * 255))
    vignette.paste(shade, (cx - shade.width // 2, cy - shade.height // 2))
    return ImageChops.multiply(toned, Image.merge("RGB", (vignette, vignette, vignette)))


def portrait_mask(size: tuple[int, int]) -> Image.Image:
    """Fotoğraf dikdörtgenini zemine eriten alfa maskesi."""
    width, height = size

    def ramp(n: int, feather: float) -> list[float]:
        edge = max(1, int(n * feather))
        values = []
        for i in range(n):
            d = min(i, n - 1 - i)
            x = min(1.0, d / edge)
            values.append(x * x * (3 - 2 * x))  # smoothstep
        return values

    horizontal = ramp(width, 0.30)
    top_band = max(1, int(height * 0.12))
    top = [min(1.0, y / top_band) for y in range(height)]
    bottom_start = 0.50
    vertical = []
    for y in range(height):
        t = y / max(1, height - 1)
        fade = 1.0 if t < bottom_start else max(0.0, 1 - (t - bottom_start) / (1 - bottom_start))
        vertical.append(min(top[y], fade * fade * (3 - 2 * fade)))
    row = Image.new("L", (width, 1))
    row.putdata([round(255 * v) for v in horizontal])
    col = Image.new("L", (1, height))
    col.putdata([round(255 * v) for v in vertical])
    return ImageChops.multiply(row.resize(size), col.resize(size))


def mountain_layer(size: tuple[int, int]) -> Image.Image:
    """Alt kenarda düşük kontrastlı geometrik dağ silüeti; dock bölgesi sade kalır."""
    width, height = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    base = height

    def y(frac: float) -> float:
        return base - height * frac

    far = [(0, y(0.16)), (width * 0.12, y(0.23)), (width * 0.24, y(0.17)), (width * 0.38, y(0.27)),
           (width * 0.52, y(0.18)), (width * 0.70, y(0.25)), (width * 0.86, y(0.17)), (width, y(0.22)),
           (width, base), (0, base)]
    draw.polygon(far, fill=lerp(NAVY, BG_950, 0.35) + (255,))
    near = [(0, y(0.10)), (width * 0.18, y(0.16)), (width * 0.30, y(0.11)), (width * 0.46, y(0.19)),
            (width * 0.60, y(0.10)), (width * 0.78, y(0.15)), (width, y(0.09)), (width, base), (0, base)]
    draw.polygon(near, fill=NAVY_STRONG + (255,))
    # Logo dilindeki zirve ışığı: yalnız en yüksek yakın zirvenin sağ yamacında ince cyan.
    peak = (width * 0.46, y(0.19))
    draw.line([peak, (width * 0.60, y(0.10))], fill=CYAN + (170,), width=max(2, height // 540))
    return layer


def horizon_warmth(size: tuple[int, int]) -> Image.Image:
    """Ufukta çok az turuncu sıcaklık (mockup §14)."""
    width, height = size
    return radial_glow(size, (width * 0.30, height * 0.80), width * 0.35, ORANGE, 0.07)


def compose(size: tuple[int, int], photo: Image.Image) -> tuple[Image.Image, tuple[int, int, int, int]]:
    width, height = size
    ratio = width / height
    scale = min(1.0, 0.90 * height / photo.height)
    pw, ph = round(photo.width * scale), round(photo.height * scale)
    center_x = 0.5 if ratio >= 2.2 else 0.66
    left = round(width * center_x - pw / 2)
    # Portre hedef yükseklikten (0.90*H) küçük kaldıysa (büyütme yok) biraz yukarı al.
    top = height - ph - round(max(0, 0.90 * height - ph) * 0.6)

    canvas = vertical_gradient(size, BG_950, lerp(NAVY_STRONG, NAVY, 0.35)).convert("RGBA")
    canvas.alpha_composite(radial_glow(size, (left + pw / 2, top + ph * 0.28), ph * 0.75, SURFACE_800, 0.85))
    canvas.alpha_composite(horizon_warmth(size))

    toned = tone_portrait(photo).resize((pw, ph), Image.LANCZOS)
    mask = portrait_mask((pw, ph)).point(lambda v: round(v * 0.96))
    toned_rgba = toned.convert("RGBA")
    toned_rgba.putalpha(mask)
    canvas.alpha_composite(toned_rgba, (left, top))
    canvas.alpha_composite(mountain_layer(size))

    fx0, fy0, fx1, fy1 = FACE_BOX
    face = (left + round(fx0 * scale), top + round(fy0 * scale), left + round(fx1 * scale), top + round(fy1 * scale))
    return canvas.convert("RGB"), face


def check_safe_area(size: tuple[int, int], face: tuple[int, int, int, int]) -> None:
    width, height = size
    x0, y0, x1, y1 = face
    problems = []
    if x0 < 0 or x1 > width or y0 < 0 or y1 > height:
        problems.append("yüz kadraj dışına taşıyor")
    if y0 < PANEL_HEIGHT:
        problems.append("yüz üst panelin altında kalıyor")
    if y1 > height * (1 - DOCK_ZONE):
        problems.append("yüz dock bölgesine giriyor")
    if x0 < width * ICON_ZONE_WIDTH:
        problems.append("yüz sol üst simge bölgesine giriyor")
    if problems:
        raise CompositionError(f"{width}x{height}: " + "; ".join(problems) + f" (yüz kutusu {face})")


def load_source() -> Image.Image:
    data = SOURCE.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SOURCE_SHA256:
        raise CompositionError(f"kaynak SHA-256 uyuşmuyor: {digest} != {SOURCE_SHA256}")
    return Image.open(io.BytesIO(data)).convert("RGB")


def encode_jpeg(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, "JPEG", quality=JPEG_QUALITY, optimize=True, progressive=True, subsampling="4:2:0")
    return buffer.getvalue()


def encode_png(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, "PNG", optimize=True)
    return buffer.getvalue()


def build() -> dict[Path, bytes]:
    photo = load_source()
    outputs: dict[Path, bytes] = {}
    for size in SIZES:
        image, face = compose(size, photo)
        check_safe_area(size, face)
        outputs[PACKAGE / "contents" / "images" / f"{size[0]}x{size[1]}.jpg"] = encode_jpeg(image)
        if size == (1920, 1200):
            preview = image.resize(SCREENSHOT_SIZE, Image.LANCZOS)
            outputs[PACKAGE / "contents" / "screenshot.png"] = encode_png(preview)
    return outputs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="yazmadan, depodaki görüntüleri yeniden üretimle karşılaştır")
    args = parser.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    try:
        outputs = build()
    except CompositionError as exc:
        print(f"HATA: {exc}", file=sys.stderr)
        return 1
    stale = []
    for path, data in outputs.items():
        rel = path.relative_to(THEME.parent.parent).as_posix()
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                stale.append(rel)
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        print(f"{hashlib.sha256(data).hexdigest()}  {rel}")
    if args.check:
        if stale:
            print("GÜNCEL DEĞİL: " + ", ".join(stale), file=sys.stderr)
            return 1
        print(f"güncel: {len(outputs)} dosya")
    return 0


if __name__ == "__main__":
    sys.exit(main())
