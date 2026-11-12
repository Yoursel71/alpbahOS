#!/usr/bin/env python3
"""REBUILD-R7 record (alp): KDE System Settings "About this System" shows AlpbahOS.

The keys were read from r4-root's kcm_about-distro.so (kcm-about-distrorc, group [General]): LogoPath, Name,
ShowBuild, UseOSReleaseVersion, Variant, Website. The KCM has no Version key: with UseOSReleaseVersion=true the
version comes from /etc/os-release (VERSION="0.9 Beta", the branding-r5fix record).
Files: etc/xdg/kcm-about-distrorc, usr/share/pixmaps/alpbahos-logo.png and
usr/share/icons/hicolor/256x256/apps/alpbahos-logo.png (the same PNG; the hicolor icon cache is not regenerated).
Writes the files into an R4 root and a manifest (alp adopt-base input). Run as root.
Usage: kcm-about-r7fix.py <R4_ROOT> <ALP_PY> <LEDGER_DIR> <LOGO_PNG>
"""
import datetime
import hashlib
import json
import os
import shutil
import stat
import sys
R4, ALP, LEDGER, LOGO = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
NAME = "kcm-about-r7fix"
VER = "0.9-r7fix"
REPO_SRC = "https://github.com/alperenyardim30-hash/alpbahOS/blob/ai/t2-kisayol-2026-11-05/scripts/rebuild/r7/kcm-about-r7fix.py"
RC = (
    "[General]\n"
    "LogoPath=/usr/share/pixmaps/alpbahos-logo.png\n"
    "Name=AlpbahOS\n"
    "ShowBuild=false\n"
    "UseOSReleaseVersion=true\n"
    "Variant=Beta\n"
    "Website=https://github.com/alperenyardim30-hash/alpbahOS\n")
logo_bytes = open(LOGO, "rb").read()
files = {
    "etc/xdg/kcm-about-distrorc": (RC.encode(), 0o644),
    "usr/share/pixmaps/alpbahos-logo.png": (logo_bytes, 0o644),
    "usr/share/icons/hicolor/256x256/apps/alpbahos-logo.png": (logo_bytes, 0o644),
}
os.makedirs(LEDGER, exist_ok=True)
entries = []
for rel, (content, mode) in sorted(files.items()):
    p = os.path.join(R4, rel)
    if os.path.lexists(p):
        raise SystemExit(f"{p} already exists: this record is for a root without it")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "wb") as f:
        f.write(content)
    os.chmod(p, mode)
    os.chown(p, 0, 0)
    st = os.lstat(p)
    entries.append({"path": "/" + rel, "type": "file", "mode": stat.S_IMODE(st.st_mode),
                    "uid": 0, "gid": 0, "size": st.st_size,
                    "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest()})
src_sha = hashlib.sha256(open(os.path.abspath(__file__), "rb").read()).hexdigest()
doc = {"schema": "alpbahOS.package-files/v1",
       "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
       "package": {"name": NAME, "version": VER, "source": {"url": REPO_SRC, "sha256": src_sha}},
       "entries": entries}
man = os.path.join(LEDGER, "manifest.json")
json.dump(doc, open(man, "w"), indent=1, sort_keys=True)
print("entries", len(entries))
print("manifest", man)
