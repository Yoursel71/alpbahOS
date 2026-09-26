#!/usr/bin/env python3
"""build_icons.py -- alpbahOS sembol ikonunu referans logodan üretir (Python 3 + Pillow).

Kaynak: docs/assets/alpbahOS-logo.png (296x359, düz #141414 zemin). Kelime işareti
kırpılır, yalnız dağ+terminal sembolü alınır; zemin rengi saydamlığa çevrilir ve
kare tuvale ortalanır. Mockup §2.2 "Sembol-only logo" varyantının GEÇİCİ raster
karşılığıdır: §16-17 üretim için vektör (SVG) kaynak ister; SVG gelince bu betik
emekliye ayrılmalı. Sembol ~261 px genişliğinde olduğundan 256 px üstü üretilmez.

Çıktı: branding/icons/hicolor/<N>x<N>/apps/alpbahos.png (freedesktop hicolor düzeni).

Kullanım:
    python build_icons.py          # üret
    python build_icons.py --check  # depodaki dosyalar yeniden üretimle aynı mı
"""

from __future__ import annotations

import argparse
import hashlib
import io
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SOURCE = REPO / "docs" / "assets" / "alpbahOS-logo.png"
SOURCE_SHA256 = "f49d6c382d9ce4c01e2806ac8d1db87ab8d074b8a3a3fa4f63491e6cb2dd0ceb"
OUT = HERE / "hicolor"
ICON_NAME = "alpbahos"
SIZES = (32, 48, 64, 128, 256)
BACKGROUND = (20, 20, 20)
SYMBOL_BOX = (15, 40, 276, 218)  # renk uzaklığıyla ölçüldü: sütun 15-275, satır 40-217
KEY_RANGE = 40  # zeminden bu kadar uzak renk tam opak sayılır


def key_background(image: Image.Image) -> Image.Image:
    rgba = []
    raw = image.tobytes()
    for i in range(0, len(raw), 3):
        r, g, b = raw[i], raw[i + 1], raw[i + 2]
        distance = max(abs(r - BACKGROUND[0]), abs(g - BACKGROUND[1]), abs(b - BACKGROUND[2]))
        alpha = min(255, round(distance * 255 / KEY_RANGE))
        if alpha == 0:
            rgba.append((0, 0, 0, 0))
            continue
        a = alpha / 255
        # Kenar yumuşatmasındaki zemin katkısını geri al (un-premultiply).
        color = tuple(max(0, min(255, round(bg + (c - bg) / a))) for c, bg in zip((r, g, b), BACKGROUND))
        rgba.append(color + (alpha,))
    out = Image.new("RGBA", image.size)
    out.putdata(rgba)
    return out


def build() -> dict[Path, bytes]:
    data = SOURCE.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SOURCE_SHA256:
        raise SystemExit(f"HATA: logo SHA-256 uyuşmuyor: {digest}")
    logo = Image.open(io.BytesIO(data)).convert("RGB")
    symbol = key_background(logo.crop(SYMBOL_BOX))
    side = max(symbol.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(symbol, ((side - symbol.width) // 2, (side - symbol.height) // 2))
    outputs = {}
    for size in SIZES:
        icon = square.resize((size, size), Image.LANCZOS)
        buffer = io.BytesIO()
        icon.save(buffer, "PNG", optimize=True)
        outputs[OUT / f"{size}x{size}" / "apps" / f"{ICON_NAME}.png"] = buffer.getvalue()
    return outputs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    outputs = build()
    stale = []
    for path, data in outputs.items():
        rel = path.relative_to(REPO).as_posix()
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
