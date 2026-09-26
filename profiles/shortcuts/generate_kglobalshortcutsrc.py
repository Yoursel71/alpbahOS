#!/usr/bin/env python3
"""generate_kglobalshortcutsrc.py -- alpbahOS kısayol profilini KDE biçimine çevirir (stdlib-only).

Tek kaynak `profiles/shortcuts/shortcuts.json` (MASTER_PLAN §6). Çıktı, sistem
genelinde varsayılan olarak `/etc/xdg/kglobalshortcutsrc` konumuna kurulacak bir
KConfig dosyasıdır. KConfig bu dosyayı XDG_CONFIG_DIRS üzerinden katmanlı okur;
kullanıcının `~/.config/kglobalshortcutsrc` içindeki değişikliği her zaman önce gelir.

Biçim (kglobalacceld, Plasma 6):
  [kwin]
  Window Maximize=Meta+Up\\tMeta+PgUp,Meta+PgUp,Maximize Window   # etkin,varsayılan,ad
  [services][org.kde.krunner.desktop]
  _launch=Meta+R\\tAlt+Space\\tAlt+F2\\tSearch                       # yalnız etkin tuşlar
Boş liste `none` yazılır.

Üretmeden önce profil doğrulanır: bilinmeyen tuş adı, tekrar eden eylem, iki
eyleme bağlı aynı tuş, satırın vaat ettiği tuşun bağlamada olmaması ve gerekçesiz
kaldırılan upstream tuşu hata sayılır.

Kullanım:
    python generate_kglobalshortcutsrc.py            # generated/kglobalshortcutsrc yazar
    python generate_kglobalshortcutsrc.py --check    # dosya güncel değilse çıkış 1
    python generate_kglobalshortcutsrc.py --output /tmp/kglobalshortcutsrc

Çıkış kodu: 0 başarı, 1 doğrulama hatası veya --check farkı.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_PROFILE = HERE / "shortcuts.json"
DEFAULT_OUTPUT = HERE / "generated" / "kglobalshortcutsrc"

# Qt 6 qnamespace.h değerleri. Yalnız profilde kullanılan tuşlar; yeni tuş
# eklenirse değeri qnamespace.h'den doğrulanarak buraya yazılmalı.
MODIFIERS = {
    "Meta": 0x10000000,
    "Ctrl": 0x04000000,
    "Alt": 0x08000000,
    "Shift": 0x02000000,
}
MODIFIER_ORDER = ("Meta", "Ctrl", "Alt", "Shift")  # QKeySequence::toString sırası
KEYS = {
    "Esc": 0x01000000,
    "Tab": 0x01000001,
    "Backtab": 0x01000002,
    "Print": 0x01000009,
    "Left": 0x01000012,
    "Up": 0x01000013,
    "Right": 0x01000014,
    "Down": 0x01000015,
    "PgUp": 0x01000016,
    "PgDown": 0x01000017,
    "Meta": 0x01000022,
    "Space": 0x20,
}
KEYS.update({f"F{n}": 0x01000030 + n - 1 for n in range(1, 13)})
KEYS.update({chr(c): c for c in range(ord("A"), ord("Z") + 1)})
KEYS.update({str(d): 0x30 + d for d in range(10)})
# Upstream'in korunmuş özel tuşları. Kod değeri burada doğrulanmadığı için
# canlı doğrulayıcı bunları zorunlu kontrol etmez; yalnız isim olarak kabul edilir.
NAME_ONLY_KEYS = {"Search", "Tools", "Screensaver"}


class ProfileError(Exception):
    pass


def normalize_key(text: str) -> str:
    """'shift+meta+s' -> 'Meta+Shift+S'. Bilinmeyen parça ProfileError verir."""
    parts = [p.strip() for p in text.split("+")]
    if not parts or any(not p for p in parts):
        raise ProfileError(f"boş tuş parçası: {text!r}")
    base = parts[-1]
    mods = parts[:-1]
    canon_mods = []
    for mod in mods:
        match = next((m for m in MODIFIERS if m.lower() == mod.lower()), None)
        if match is None:
            raise ProfileError(f"bilinmeyen değiştirici {mod!r}: {text!r}")
        if match in canon_mods:
            raise ProfileError(f"tekrarlanan değiştirici {mod!r}: {text!r}")
        canon_mods.append(match)
    key = next((k for k in list(KEYS) + sorted(NAME_ONLY_KEYS) if k.lower() == base.lower()), None)
    if key is None:
        raise ProfileError(f"bilinmeyen tuş {base!r}: {text!r}")
    if key == "Meta" and canon_mods:
        raise ProfileError(f"Meta tek başına kullanılmalı: {text!r}")
    ordered = [m for m in MODIFIER_ORDER if m in canon_mods]
    return "+".join(ordered + [key])


def qt_key_code(text: str) -> int | None:
    """Normalize edilmiş tuşun Qt birleşik int değeri; NAME_ONLY tuşlarda None."""
    norm = normalize_key(text)
    parts = norm.split("+")
    if parts[-1] in NAME_ONLY_KEYS:
        return None
    code = KEYS[parts[-1]]
    for mod in parts[:-1]:
        code |= MODIFIERS[mod]
    return code


def equivalent_codes(code: int) -> set[int]:
    """Shift+Tab, Qt'de Shift+Backtab olarak da gelebilir; ikisini eş say."""
    codes = {code}
    shift = MODIFIERS["Shift"]
    base = code & 0x01FFFFFF
    mods = code & ~0x01FFFFFF
    if mods & shift and base == KEYS["Tab"]:
        codes.add(mods | KEYS["Backtab"])
    if mods & shift and base == KEYS["Backtab"]:
        codes.add(mods | KEYS["Tab"])
    return codes


def load_profile(path: Path = DEFAULT_PROFILE) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def iter_bindings(profile: dict):
    """(kaynak, binding) çiftleri: kaynak satır id'si ya da 'cozum:<for>'."""
    for row in profile.get("shortcuts", []):
        for binding in row.get("bindings", []):
            yield row["id"], binding
    for binding in profile.get("cakisma_cozumleri", []):
        yield f"cozum:{binding.get('for')}", binding


def validate(profile: dict) -> list[str]:
    errors: list[str] = []
    row_ids = set()
    for row in profile.get("shortcuts", []):
        rid = row.get("id")
        if not rid or rid in row_ids:
            errors.append(f"satır id eksik ya da tekrar ediyor: {rid!r}")
        row_ids.add(rid)
        if row.get("durum") not in profile.get("durum_kodlari", {}):
            errors.append(f"{rid}: bilinmeyen durum {row.get('durum')!r}")

    seen_actions: dict[tuple, str] = {}
    owner: dict[str, list[str]] = {}
    for source, binding in iter_bindings(profile):
        kind = binding.get("kind")
        if kind not in ("component", "service"):
            errors.append(f"{source}: kind component/service olmalı, {kind!r}")
            continue
        for field in ("component", "action", "friendly", "upstream_kaynak"):
            if not binding.get(field):
                errors.append(f"{source}: {field} eksik")
        ident = (kind, binding.get("component"), binding.get("action"))
        if ident in seen_actions:
            errors.append(f"{source}: eylem {ident} zaten {seen_actions[ident]} içinde tanımlı")
        seen_actions[ident] = source
        for field in ("set", "upstream_default"):
            keys = binding.get(field)
            if not isinstance(keys, list):
                errors.append(f"{source}: {field} liste olmalı")
                continue
            try:
                normalized = [normalize_key(k) for k in keys]
            except ProfileError as exc:
                errors.append(f"{source}: {exc}")
                continue
            if len(set(normalized)) != len(normalized):
                errors.append(f"{source}: {field} içinde tekrar eden tuş")
            if field == "set":
                label = f"{binding.get('component')}/{binding.get('action')}"
                for key in normalized:
                    owner.setdefault(key, []).append(label)

    for key, labels in sorted(owner.items()):
        if len(labels) > 1:
            errors.append(f"çakışma: {key} birden fazla eyleme bağlı: {', '.join(labels)}")

    for row in profile.get("shortcuts", []):
        promised = row.get("keys", [])
        bound = set()
        for binding in row.get("bindings", []):
            try:
                bound.update(normalize_key(k) for k in binding.get("set", []))
            except ProfileError:
                pass
        for key in promised:
            try:
                norm = normalize_key(key)
            except ProfileError as exc:
                errors.append(f"{row.get('id')}: {exc}")
                continue
            if norm not in bound:
                errors.append(f"{row.get('id')}: vaat edilen {norm} hiçbir bağlamada yok")

    for row in profile.get("cakisma_cozumleri", []):
        if row.get("for") not in row_ids:
            errors.append(f"çözüm {row.get('action')!r}: bilinmeyen satır {row.get('for')!r}")
        if not row.get("neden"):
            errors.append(f"çözüm {row.get('action')!r}: neden eksik")

    # Upstream'den kaldırılan her tuş profilde başka bir eyleme verilmiş olmalı.
    for source, binding in iter_bindings(profile):
        try:
            active = {normalize_key(k) for k in binding.get("set", [])}
            upstream = {normalize_key(k) for k in binding.get("upstream_default", [])}
        except ProfileError:
            continue
        released = binding.get("birakilan", {})
        try:
            released_keys = {normalize_key(k) for k in released}
        except ProfileError as exc:
            errors.append(f"{source}: birakilan: {exc}")
            continue
        for key in sorted(upstream - active):
            if key not in owner and key not in released_keys:
                errors.append(f"{source}: upstream {key} gerekçesiz kaldırıldı (başka eyleme verilmedi, 'birakilan' içinde yok)")
        for key in sorted(released_keys - (upstream - active)):
            errors.append(f"{source}: birakilan {key} upstream'den kaldırılan bir tuş değil")
    return errors


def _keylist(keys: list[str]) -> str:
    return "\\t".join(normalize_key(k) for k in keys) if keys else "none"


def render(profile: dict, profile_name: str = "profiles/shortcuts/shortcuts.json") -> str:
    components: dict[str, list[str]] = {}
    services: dict[str, list[str]] = {}
    for _source, binding in iter_bindings(profile):
        action = binding["action"]
        if binding["kind"] == "component":
            line = f"{action}={_keylist(binding['set'])},{_keylist(binding['upstream_default'])},{binding['friendly']}"
            components.setdefault(binding["component"], []).append(line)
        else:
            line = f"{action}={_keylist(binding['set'])}"
            services.setdefault(binding["component"], []).append(line)

    out = [
        "# alpbahOS kısayol profili -- ÜRETİLMİŞ DOSYA, elle düzenlemeyin.",
        f"# Kaynak: {profile_name}",
        "# Üretici: profiles/shortcuts/generate_kglobalshortcutsrc.py",
        "# Kurulum hedefi: /etc/xdg/kglobalshortcutsrc (kullanıcı ayarı ~/.config/kglobalshortcutsrc önce gelir)",
        f"# Hedef sürüm: Plasma {profile.get('hedef_surum', {}).get('plasma', '?')}; gerçek oturumda doğrulanmadı.",
    ]
    for name in sorted(components):
        out.append("")
        out.append(f"[{name}]")
        out.extend(sorted(components[name]))
    for name in sorted(services):
        out.append("")
        out.append(f"[services][{name}]")
        out.extend(sorted(services[name]))
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true", help="yazmadan, mevcut çıktının güncel olduğunu denetle")
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
