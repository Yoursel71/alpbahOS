#!/usr/bin/env python3
"""verify_shortcuts_live.py -- çalışan Plasma oturumunda kısayol profilini denetler (stdlib-only).

Salt okunur: kglobalaccel D-Bus servisinden (org.kde.kglobalaccel) tüm bileşenlerin
kayıtlı kısayollarını `busctl --user --json=short` ile okur; hiçbir kısayolu
değiştirmez, hiçbir eylemi tetiklemez.

Her profil satırı için:
  GEÇTİ    satırın vaat ettiği tuşların hepsi hedef eylemde etkin ve başka hiçbir
           eylemde değil
  KALDI    tuş eksik ya da başka eyleme de bağlı (çakışma)
  KAYITSIZ hedef eylemi kaydeden bileşen oturumda yok (ör. Dolphin kurulu değil,
           KScreenLocker derlenmemiş) -- test edilemedi, geçti sayılmaz
Çözüm satırlarında (cakisma_cozumleri) kaldırılan tuşun eylemde kalmadığı denetlenir.

Plasma oturumunun kullanıcısıyla çalıştırılmalı (ör. Gen2 test VM'de admin):
    XDG_RUNTIME_DIR=/run/user/$(id -u) python3 verify_shortcuts_live.py --dump /var/tmp/kga.json

Çevrimdışı çözümleme (kaydedilmiş döküm):
    python verify_shortcuts_live.py --from-dump kga.json

Çıkış kodu: 0 tüm satırlar GEÇTİ, 1 en az bir KALDI/KAYITSIZ, 2 ortam hatası.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("alpbah_shortcuts_gen", HERE / "generate_kglobalshortcutsrc.py")
gen = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(gen)

SERVICE = "org.kde.kglobalaccel"


def busctl(args: list[str], busctl_path: str) -> dict:
    cmd = [busctl_path, "--user", "--json=short", "call", SERVICE, *args]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
    if proc.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} başarısız: {proc.stderr.strip()}")
    return json.loads(proc.stdout)


def collect(busctl_path: str) -> list[dict]:
    """kglobalaccel'deki tüm kısayol kayıtlarını düz liste olarak döndür."""
    components = busctl(["/kglobalaccel", "org.kde.KGlobalAccel", "allComponents"], busctl_path)["data"][0]
    records = []
    for path in components:
        reply = busctl([path, "org.kde.kglobalaccel.Component", "allShortcutInfos"], busctl_path)
        for info in reply["data"][0]:
            action, friendly, component, component_friendly, _ctx, _ctx_friendly, keys, defaults = info
            records.append(
                {
                    "component": component,
                    "action": action,
                    "friendly": friendly,
                    "component_friendly": component_friendly,
                    "keys": [k for k in keys if k],
                    "default_keys": [k for k in defaults if k],
                }
            )
    return records


def describe(code: int) -> str:
    names = {v: k for k, v in gen.KEYS.items()}
    mods = [m for m in gen.MODIFIER_ORDER if code & gen.MODIFIERS[m]]
    base = code & 0x01FFFFFF
    return "+".join(mods + [names.get(base, hex(base))])


def analyze(profile: dict, records: list[dict]) -> list[dict]:
    by_action = {(r["component"], r["action"]): r for r in records}
    holders: dict[int, list[str]] = {}
    for r in records:
        for code in r["keys"]:
            holders.setdefault(code, []).append(f"{r['component']}/{r['action']}")

    def owners(code: int) -> list[str]:
        found: list[str] = []
        for alt in gen.equivalent_codes(code):
            found.extend(holders.get(alt, []))
        return sorted(set(found))

    results = []
    for row in profile["shortcuts"]:
        if not row.get("bindings"):
            results.append({"id": row["id"], "sonuc": "KAPSAM DIŞI", "ayrinti": "uygulama katmanı; sistem kısayolu değil"})
            continue
        problems, missing_components = [], []
        for key in row["keys"]:
            code = gen.qt_key_code(key)
            target = next(
                (b for b in row["bindings"] if gen.normalize_key(key) in {gen.normalize_key(k) for k in b["set"]}),
                None,
            )
            label = f"{target['component']}/{target['action']}"
            if (target["component"], target["action"]) not in by_action:
                missing_components.append(label)
                continue
            holding = owners(code)
            if label not in holding:
                problems.append(f"{gen.normalize_key(key)} {label} üzerinde etkin değil")
            others = [h for h in holding if h != label]
            if others:
                problems.append(f"{gen.normalize_key(key)} çakışıyor: {', '.join(others)}")
        if problems:
            results.append({"id": row["id"], "sonuc": "KALDI", "ayrinti": "; ".join(problems)})
        elif missing_components:
            results.append({"id": row["id"], "sonuc": "KAYITSIZ", "ayrinti": "kayıtlı değil: " + ", ".join(sorted(set(missing_components)))})
        else:
            results.append({"id": row["id"], "sonuc": "GEÇTİ", "ayrinti": ", ".join(gen.normalize_key(k) for k in row["keys"])})

    for res in profile.get("cakisma_cozumleri", []):
        ident = (res["component"], res["action"])
        rid = f"cozum:{res['for']}:{res['action']}"
        if ident not in by_action:
            results.append({"id": rid, "sonuc": "KAYITSIZ", "ayrinti": f"{res['component']} oturumda kayıtlı değil"})
            continue
        active = set(by_action[ident]["keys"])
        released = [k for k in res["upstream_default"] if k not in res["set"]]
        leftovers = [gen.normalize_key(k) for k in released if gen.qt_key_code(k) is not None and active & gen.equivalent_codes(gen.qt_key_code(k))]
        if leftovers:
            results.append({"id": rid, "sonuc": "KALDI", "ayrinti": "hâlâ etkin: " + ", ".join(leftovers)})
        else:
            results.append({"id": rid, "sonuc": "GEÇTİ", "ayrinti": "serbest: " + ", ".join(gen.normalize_key(k) for k in released)})
    return results


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--profile", type=Path, default=gen.DEFAULT_PROFILE)
    parser.add_argument("--busctl", default="busctl")
    parser.add_argument("--dump", type=Path, help="okunan ham kayıtları JSON olarak buraya yaz (kanıt)")
    parser.add_argument("--from-dump", type=Path, help="canlı oturum yerine kaydedilmiş dökümü çözümle")
    args = parser.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")

    profile = gen.load_profile(args.profile)
    errors = gen.validate(profile)
    if errors:
        for error in errors:
            print(f"PROFİL HATASI: {error}", file=sys.stderr)
        return 2
    try:
        if args.from_dump:
            records = json.loads(args.from_dump.read_text(encoding="utf-8"))["records"]
        else:
            records = collect(args.busctl)
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        print(f"ORTAM HATASI: {exc}", file=sys.stderr)
        return 2
    if args.dump:
        args.dump.write_text(json.dumps({"records": records}, ensure_ascii=False, indent=1), encoding="utf-8")

    results = analyze(profile, records)
    width = max(len(r["id"]) for r in results)
    for r in results:
        print(f"{r['id']:<{width}}  {r['sonuc']:<11}  {r['ayrinti']}")
    counts: dict[str, int] = {}
    for r in results:
        counts[r["sonuc"]] = counts.get(r["sonuc"], 0) + 1
    print("özet: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    return 0 if all(r["sonuc"] in ("GEÇTİ", "KAPSAM DIŞI") for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
