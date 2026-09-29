#!/usr/bin/env python3
"""collect_session_metrics.py -- Plasma oturumunun bellek/renderer anlık görüntüsü (stdlib-only).

Salt okunur. Plasma oturumunun kullanıcısıyla, oturum boştayken çalıştırılır:
    XDG_RUNTIME_DIR=/run/user/$(id -u) python3 collect_session_metrics.py --label solid-idle --out /var/tmp/perf-solid-idle.json

Toplanan (P08: 4 GiB eski x86_64, boşta bellek <= 1 GiB tasarım hedefi):
  memory      /proc/meminfo: MemTotal, MemAvailable, kullanılan = Total - Available, Swap
  processes   izlenen masaüstü süreçlerinin PSS/RSS değeri (/proc/<pid>/smaps_rollup, status)
  user_pss    oturum kullanıcısına ait tüm süreçlerin PSS toplamı
  kwin        KWin supportInformation'dan compositing türü, renderer ve sürücü; etkin efektler
  profile     alpbah-gorunum profili (~/.config/alpbahrc)
D-Bus'a erişilemezse kwin alanı boş kalır ve nedeni yazılır; bellek ölçümü yine alınır.

Çevrimdışı test için --proc-root sahte bir /proc ağacını gösterebilir, --no-dbus D-Bus'ı atlar.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

WATCHED = ("kwin_wayland", "plasmashell", "kactivitymanagerd", "Xwayland", "kded6", "ksmserver",
           "polkit-kde-authentication-agent-1", "xdg-desktop-portal-kde", "pipewire", "wireplumber",
           "baloo_file", "krunner", "konsole", "dolphin")
IDLE_BUDGET_MIB = 1024


def read_meminfo(proc: Path) -> dict:
    values = {}
    for line in (proc / "meminfo").read_text(encoding="utf-8").splitlines():
        match = re.match(r"^(\w+):\s+(\d+) kB$", line)
        if match:
            values[match.group(1)] = int(match.group(2))
    total, available = values["MemTotal"], values["MemAvailable"]
    return {
        "total_mib": round(total / 1024, 1),
        "available_mib": round(available / 1024, 1),
        "used_mib": round((total - available) / 1024, 1),
        "swap_used_mib": round((values.get("SwapTotal", 0) - values.get("SwapFree", 0)) / 1024, 1),
        "idle_budget_mib": IDLE_BUDGET_MIB,
        "within_idle_budget": (total - available) / 1024 <= IDLE_BUDGET_MIB,
    }


def process_table(proc: Path, uid: int) -> tuple[list[dict], float]:
    rows, user_pss = [], 0.0
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            status = (entry / "status").read_text(encoding="utf-8")
            name = re.search(r"^Name:\s+(.+)$", status, re.M).group(1).strip()
            owner = int(re.search(r"^Uid:\s+(\d+)", status, re.M).group(1))
            rss = re.search(r"^VmRSS:\s+(\d+) kB$", status, re.M)
            rollup = (entry / "smaps_rollup").read_text(encoding="utf-8")
            pss = re.search(r"^Pss:\s+(\d+) kB$", rollup, re.M)
        except (OSError, AttributeError):
            continue  # süreç kapanmış ya da erişim yok
        pss_mib = int(pss.group(1)) / 1024 if pss else 0.0
        if owner == uid:
            user_pss += pss_mib
        if name in WATCHED:
            rows.append({"pid": int(entry.name), "name": name, "pss_mib": round(pss_mib, 1),
                         "rss_mib": round(int(rss.group(1)) / 1024, 1) if rss else None, "uid": owner})
    rows.sort(key=lambda r: -r["pss_mib"])
    return rows, round(user_pss, 1)


def busctl_json(args: list[str]):
    busctl = shutil.which("busctl")
    if not busctl:
        raise RuntimeError("busctl yok")
    proc = subprocess.run([busctl, "--user", "--json=short", *args], capture_output=True, text=True, timeout=20)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"busctl çıkış {proc.returncode}")
    return json.loads(proc.stdout)


def kwin_state() -> dict:
    info = busctl_json(["call", "org.kde.KWin", "/KWin", "org.kde.KWin", "supportInformation"])["data"][0]
    state = {"compositing": "Compositing is active" in info}
    for key, prefix in (("type", "Compositing Type:"), ("renderer", "OpenGL renderer string:"), ("driver", "Driver:")):
        match = re.search(rf"^{re.escape(prefix)}\s*(.+)$", info, re.M)
        state[key] = match.group(1).strip() if match else None
    effects = busctl_json(["get-property", "org.kde.KWin", "/Effects", "org.kde.kwin.Effects", "activeEffects"])
    state["active_effects"] = sorted(effects.get("data", []))
    return state


def appearance_profile(home: Path) -> str | None:
    rc = home / ".config" / "alpbahrc"
    if not rc.exists():
        return None
    match = re.search(r"^\[Gorunum\][^\[]*?^Profil=(\w+)", rc.read_text(encoding="utf-8"), re.M | re.S)
    return match.group(1) if match else None


def collect(proc: Path, uid: int, home: Path, use_dbus: bool, label: str) -> dict:
    processes, user_pss = process_table(proc, uid)
    result = {
        "label": label,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "kernel": (proc / "sys" / "kernel" / "osrelease").read_text(encoding="utf-8").strip()
        if (proc / "sys" / "kernel" / "osrelease").exists() else None,
        "uptime_s": float((proc / "uptime").read_text(encoding="utf-8").split()[0]) if (proc / "uptime").exists() else None,
        "memory": read_meminfo(proc),
        "processes": processes,
        "user_pss_mib": user_pss,
        "profile": appearance_profile(home),
        "kwin": None,
        "kwin_error": None,
    }
    if use_dbus:
        try:
            result["kwin"] = kwin_state()
        except (RuntimeError, OSError, ValueError, KeyError, IndexError, subprocess.SubprocessError) as exc:
            result["kwin_error"] = str(exc)
    else:
        result["kwin_error"] = "atlandı (--no-dbus)"
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--label", required=True, help="senaryo etiketi, ör. solid-idle")
    parser.add_argument("--out", type=Path, help="JSON çıktısı (yoksa stdout)")
    parser.add_argument("--proc-root", type=Path, default=Path("/proc"))
    parser.add_argument("--uid", type=int, default=os.getuid() if hasattr(os, "getuid") else -1)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--no-dbus", action="store_true")
    args = parser.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    try:
        data = collect(args.proc_root, args.uid, args.home, not args.no_dbus, args.label)
    except (OSError, KeyError) as exc:
        print(f"HATA: {exc}", file=sys.stderr)
        return 2
    text = json.dumps(data, ensure_ascii=False, indent=1)
    if args.out:
        args.out.write_text(text + "\n", encoding="utf-8")
    else:
        print(text)
    mem = data["memory"]
    print(f"kullanılan bellek {mem['used_mib']} MiB / hedef {mem['idle_budget_mib']} MiB "
          f"({'içinde' if mem['within_idle_budget'] else 'AŞILDI'})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
