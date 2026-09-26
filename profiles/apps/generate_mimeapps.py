#!/usr/bin/env python3
"""generate_mimeapps.py -- alpbahOS varsayılan uygulama profilini mimeapps.list'e çevirir (stdlib-only).

Tek kaynak `profiles/apps/apps.json` (MASTER_PLAN §11). Çıktı, freedesktop
"Association between MIME types and applications" belirtimine göre
`$XDG_CONFIG_DIRS/mimeapps.list` (kurulum: /etc/xdg/mimeapps.list) dosyasıdır;
kullanıcının ~/.config/mimeapps.list seçimi her zaman önce gelir.

Doğrulama: her uygulama kimliği ve masaüstü dosyası tektir; bir MIME türü yalnız bir
uygulamaya varsayılan olur; MIME türü `tür/alt-tür` biçimindedir; `karar_bekleyen`
listesindekiler (Wine, Steam, mağaza) dosyaya hiç girmez.

Kullanım:
    python generate_mimeapps.py          # generated/mimeapps.list yazar
    python generate_mimeapps.py --check  # güncel değilse çıkış 1
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_PROFILE = HERE / "apps.json"
DEFAULT_OUTPUT = HERE / "generated" / "mimeapps.list"
MIME_RE = re.compile(r"^(application|audio|font|image|inode|message|model|multipart|text|video|x-scheme-handler)/[A-Za-z0-9.+_-]+$")
DESKTOP_RE = re.compile(r"^[A-Za-z0-9._-]+\.desktop$")


def load_profile(path: Path = DEFAULT_PROFILE) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def validate(profile: dict) -> list[str]:
    errors = []
    codes = profile.get("dogrulama_kodlari", {})
    ids, desktops, owners = set(), set(), {}
    for app in profile.get("apps", []):
        aid = app.get("id")
        if not aid or aid in ids:
            errors.append(f"uygulama id eksik ya da tekrar ediyor: {aid!r}")
        ids.add(aid)
        desktop = app.get("desktop") or ""
        if not DESKTOP_RE.match(desktop):
            errors.append(f"{aid}: geçersiz masaüstü dosyası adı {desktop!r}")
        if desktop in desktops:
            errors.append(f"{aid}: {desktop} başka bir uygulamada da var")
        desktops.add(desktop)
        if app.get("dogrulama") not in codes:
            errors.append(f"{aid}: bilinmeyen doğrulama kodu {app.get('dogrulama')!r}")
        for mime in app.get("mime", []):
            if not MIME_RE.match(mime):
                errors.append(f"{aid}: geçersiz MIME türü {mime!r}")
            if mime in owners:
                errors.append(f"{mime}: hem {owners[mime]} hem {aid} için varsayılan")
            owners[mime] = aid
    for pending in profile.get("karar_bekleyen", []):
        if not pending.get("neden"):
            errors.append(f"karar bekleyen {pending.get('id')!r}: neden eksik")
        for mime in pending.get("mime", []):
            if mime in owners:
                errors.append(f"{mime}: karar bekleyen {pending.get('id')} türü {owners[mime]} uygulamasına atanmış")
    return errors


def render(profile: dict) -> str:
    rows = sorted((mime, app["desktop"]) for app in profile["apps"] for mime in app.get("mime", []))
    lines = [
        "# alpbahOS varsayılan uygulamaları -- ÜRETİLMİŞ DOSYA, elle düzenlemeyin.",
        "# Kaynak: profiles/apps/apps.json; üretici: profiles/apps/generate_mimeapps.py",
        "# Kurulum hedefi: /etc/xdg/mimeapps.list (kullanıcı ~/.config/mimeapps.list önce gelir).",
        "# Uygulamalar Gen2 test imajında kurulu değil; ilişkiler gerçek oturumda test edilmedi.",
        "",
        "[Default Applications]",
    ]
    lines += [f"{mime}={desktop};" for mime, desktop in rows]
    lines += ["", "[Added Associations]"]
    lines += [f"{mime}={desktop};" for mime, desktop in rows]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    profile = load_profile(args.profile)
    errors = validate(profile)
    if errors:
        for error in errors:
            print(f"HATA: {error}", file=sys.stderr)
        return 1
    text = render(profile)
    if args.check:
        current = args.output.read_text(encoding="utf-8") if args.output.exists() else None
        if current != text:
            print(f"GÜNCEL DEĞİL: {args.output} -- üreticiyi yeniden çalıştırın", file=sys.stderr)
            return 1
        print(f"güncel: {args.output}")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print(f"yazıldı: {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
