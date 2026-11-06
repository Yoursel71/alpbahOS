#!/usr/bin/env python3
"""build_brand_wallpaper.py -- alpbahOS varsayılan (marka) duvar kâğıdı paketini üretir (Python 3 + Pillow).

Girdiler (hepsi repoda, hepsi proje özgün içeriği):
- `docs/assets/alpbahOS-logo.png` (296x359, RGBA)
- `profiles/desktop/tokens.json` (renkler: navy, navy-strong, bg-950, cyan, orange)

Kompozisyon (D113, D114):
- Zemin: koyu lacivert, yukarıdan aşağıya hafif degrade (üstte lacivert, altta bg-950).
- Logo: yüksekliği görüntü yüksekliğinin %22'si, yatay ortalı. Logo kaynak boyutunun
  üstüne büyütülmez; küçültme LANCZOS ile yapılır. Kaynağın düz #141414 kutusu bellekte
  şeffaflaştırılır (kaynak dosya değişmez). Logonun arkasında düşük opaklıkta bulanık bir
  açık lacivert/cyan ışıma, harflerin okunması için.
- Vurgu: ince cyan yatay çizgi (genişliğin %16'sı), başında kısa turuncu parça.
- Metin, imza veya sembol eklenmez.

Çıktı yalnızca bu betiğin çıktısıdır: PNG'ler sabit sıkıştırma düzeyiyle yazılır, zaman
damgası ya da meta veri eklenmez; aynı girdi her zaman aynı baytları üretir.

Kullanım:
    python3 -B build_brand_wallpaper.py          # paketi yeniden üretir
    python3 -B build_brand_wallpaper.py --check  # depodaki dosyalar bu betiğin çıktısıyla aynı mı

Çıktı: branding/alpbahos-brand/wallpaper/alpbahOS-Brand/ altında metadata.json,
contents/images/<G>x<Y>.png ve contents/screenshot.png.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
BRAND = HERE.parent
REPO = BRAND.parent.parent
LOGO = REPO / "docs" / "assets" / "alpbahOS-logo.png"
TOKENS = REPO / "profiles" / "desktop" / "tokens.json"
PACKAGE = BRAND / "wallpaper" / "alpbahOS-Brand"

# Aynı çözünürlük kümesi: branding/ataturk-theme/tools/build_wallpaper.py SIZES (test ile eşleşir).
SIZES = [(1366, 768), (1920, 1080), (1920, 1200), (2560, 1440), (3440, 1440)]
PREVIEW_SOURCE = (1920, 1200)
SCREENSHOT_SIZE = (400, 250)

LOGO_HEIGHT_FRACTION = 0.22
ACCENT_WIDTH_FRACTION = 0.16
ACCENT_ORANGE_FRACTION = 0.20   # çizginin sol ucundaki turuncu parçanın payı
GAP_FRACTION = 0.04             # logo ile çizgi arası

# Logo kaynağında düz #141414 bir kutu var (tam opak). Bu renge yakın pikseller bellekte
# şeffaflaştırılır; kaynak dosyaya dokunulmaz.
LOGO_BG = (20, 20, 20)
BG_TOLERANCE = 18               # bu mesafeye kadar tamamen şeffaf (RGB Öklid)
BG_RAMP = 12                    # tolerans..tolerans+12 arası yumuşak kenar
# Logonun arkasında düşük opaklıkta açık lacivert/cyan ışıma: koyu lacivert harfler okunsun.
GLOW_COLOR_MIX = 0.50           # navy -> cyan karışım oranı
GLOW_ALPHA = 0.60               # en yüksek opaklık (0..1)
GLOW_RADIUS_FRACTION = 0.75     # ışıma yarıçapı / logo yüksekliği
GLOW_BLUR_FRACTION = 0.05       # GaussianBlur yarıçapı / görüntü yüksekliği

METADATA = {
    "KPlugin": {
        "Authors": [{"Name": "alpbahOS"}],
        "Description": "alpbahOS marka duvar kâğıdı: koyu lacivert degrade, dağ-terminal logosu, cyan ve turuncu vurgu",
        "Id": "alpbahOS-Brand",
        "License": "GPL-3.0-or-later",
        "Name": "alpbahOS",
    }
}


class BuildError(Exception):
    pass


def load_tokens() -> dict[str, tuple[int, int, int]]:
    data = json.loads(TOKENS.read_text(encoding="utf-8"))["color"]
    wanted = ["navy", "navy-strong", "bg-950", "cyan", "orange"]
    missing = [name for name in wanted if name not in data]
    if missing:
        raise BuildError(f"tokens.json renkleri eksik: {', '.join(missing)}")
    return {name: hex_to_rgb(data[name]) for name in wanted}


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    if len(value) != 6:
        raise BuildError(f"geçersiz renk: {value}")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def lerp(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(size: tuple[int, int], top: tuple, bottom: tuple) -> Image.Image:
    width, height = size
    column = Image.new("RGB", (1, height))
    column.putdata([lerp(top, bottom, y / max(1, height - 1)) for y in range(height)])
    return column.resize(size, Image.NEAREST)


def load_logo() -> Image.Image:
    if not LOGO.exists():
        raise BuildError(f"logo yok: {LOGO}")
    return Image.open(LOGO).convert("RGBA")


def key_background(logo: Image.Image) -> Image.Image:
    """LOGO_BG'ye yakın pikselleri şeffaflaştırır (bellekte; kaynak dosya değişmez)."""
    out = logo.copy()
    pixels = out.load()
    r0, g0, b0 = LOGO_BG
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            distance = ((r - r0) ** 2 + (g - g0) ** 2 + (b - b0) ** 2) ** 0.5
            if distance <= BG_TOLERANCE:
                factor = 0.0
            elif distance >= BG_TOLERANCE + BG_RAMP:
                factor = 1.0
            else:
                factor = (distance - BG_TOLERANCE) / BG_RAMP
            pixels[x, y] = (r, g, b, round(a * factor))
    return out


def logo_box(size: tuple[int, int], logo: Image.Image) -> tuple[int, int, int, int, int]:
    """(x, y, w, h, gap) — logo+çizgi bloğu dikeyde ortalanmış yerleşim. Hem compose hem test kullanır."""
    width, height = size
    target_h = round(height * LOGO_HEIGHT_FRACTION)
    logo_h = min(target_h, logo.height)  # büyütme yok
    logo_w = round(logo.width * logo_h / logo.height)
    line_t = max(2, round(height / 540))
    gap = round(height * GAP_FRACTION)
    top = (height - (logo_h + gap + line_t)) // 2
    return (width - logo_w) // 2, top, logo_w, logo_h, gap


def glow_layer(size: tuple[int, int], center: tuple[float, float], radius: float, colors: dict) -> Image.Image:
    """Logonun arkasında düşük opaklıkta, bulanık açık lacivert/cyan ışıma (kutu yok)."""
    width, height = size
    mask = Image.new("L", size, 0)
    cx, cy = center
    ImageDraw.Draw(mask).ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=round(height * GLOW_BLUR_FRACTION)))
    mask = mask.point(lambda v: round(v * GLOW_ALPHA))
    colour = lerp(colors["navy"], colors["cyan"], GLOW_COLOR_MIX)
    layer = Image.new("RGBA", size, colour + (0,))
    layer.putalpha(mask)
    return layer


def compose(size: tuple[int, int], colors: dict, logo: Image.Image) -> Image.Image:
    width, height = size
    navy = colors["navy"]
    canvas = vertical_gradient(size, lerp(colors["bg-950"], navy, 0.55), colors["bg-950"]).convert("RGBA")

    keyed = key_background(logo)
    logo_x, top, logo_w, logo_h, gap = logo_box(size, keyed)
    scaled = keyed if logo_h == keyed.height else keyed.resize((logo_w, logo_h), Image.LANCZOS)

    centre = (logo_x + logo_w / 2, top + logo_h / 2)
    canvas.alpha_composite(glow_layer(size, centre, logo_h * GLOW_RADIUS_FRACTION, colors))
    canvas.alpha_composite(scaled, (logo_x, top))

    line_t = max(2, round(height / 540))
    line_w = round(width * ACCENT_WIDTH_FRACTION)
    line_y = top + logo_h + gap
    line_x0 = (width - line_w) // 2
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((line_x0, line_y, line_x0 + line_w - 1, line_y + line_t - 1), fill=colors["cyan"] + (255,))
    orange_w = max(1, round(line_w * ACCENT_ORANGE_FRACTION))
    draw.rectangle((line_x0, line_y, line_x0 + orange_w - 1, line_y + line_t - 1), fill=colors["orange"] + (255,))
    return canvas.convert("RGB")


def encode_png(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    # Sabit sıkıştırma düzeyi; meta veri ya da zaman damgası yok.
    image.save(buffer, "PNG", compress_level=9)
    return buffer.getvalue()


def build() -> dict[Path, bytes]:
    colors = load_tokens()
    logo = load_logo()
    outputs: dict[Path, bytes] = {}
    outputs[PACKAGE / "metadata.json"] = (json.dumps(METADATA, indent=4, ensure_ascii=False) + "\n").encode("utf-8")
    for size in SIZES:
        image = compose(size, colors, logo)
        outputs[PACKAGE / "contents" / "images" / f"{size[0]}x{size[1]}.png"] = encode_png(image)
        if size == PREVIEW_SOURCE:
            preview = image.resize(SCREENSHOT_SIZE, Image.LANCZOS)
            outputs[PACKAGE / "contents" / "screenshot.png"] = encode_png(preview)
    return outputs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="yazmadan, depodaki dosyaları yeniden üretimle karşılaştır")
    args = parser.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    try:
        outputs = build()
    except BuildError as exc:
        print(f"HATA: {exc}", file=sys.stderr)
        return 1
    if args.check:
        stale = []
        for path, data in outputs.items():
            if not path.exists() or path.read_bytes() != data:
                stale.append(path.relative_to(REPO).as_posix())
        images_dir = PACKAGE / "contents" / "images"
        expected = {p.name for p in outputs if p.parent == images_dir}
        if images_dir.exists():
            for extra in sorted(p for p in images_dir.iterdir() if p.name not in expected):
                stale.append(extra.relative_to(REPO).as_posix() + " (beklenmeyen dosya)")
        if stale:
            print("GÜNCEL DEĞİL: " + ", ".join(stale), file=sys.stderr)
            return 1
        print(f"güncel: {len(outputs)} dosya")
        return 0
    for path, data in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        print(f"{hashlib.sha256(data).hexdigest()}  {len(data):>7}  {path.relative_to(REPO).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
