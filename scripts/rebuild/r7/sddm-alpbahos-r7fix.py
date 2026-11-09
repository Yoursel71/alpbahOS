#!/usr/bin/env python3
"""REBUILD-R7 record (alp): SDDM login theme "alpbahos" (based on the installed KDE Breeze greeter theme).

Copies the Breeze theme files from the R4 root (LGPL-2.0-or-later; the file headers and a NOTICE file keep the
copyright and license), replaces the background and the logo with the AlpbahOS brand images, and sets the theme
name, the theme id and the config. Adds /etc/sddm.conf.d/alpbahos-theme.conf with [Theme] Current=alpbahos.
/etc/sddm.conf is not changed (its autologin block is used by the live image). The round 4 display-order drop-in is in
/etc/systemd/system/sddm.service.d and is not touched.
Files are written into an R4 root and a manifest is written (alp adopt-base input). Run as root.
Usage: sddm-alpbahos-r7fix.py <R4_ROOT> <ALP_PY> <LEDGER_DIR> <BACKGROUND_PNG> <LOGO_PNG>
"""
import datetime
import hashlib
import json
import os
import re
import shutil
import stat
import sys
R4, ALP, LEDGER, BG, LOGO = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
NAME = "sddm-alpbahos-r7fix"
VER = "0.9-r7fix"
REPO_SRC = "https://github.com/alperenyardim30-hash/alpbahOS/blob/claude/t2-kisayol-2026-11-05/scripts/rebuild/r7/sddm-alpbahos-r7fix.py"
SRC = os.path.join(R4, "usr/share/sddm/themes/breeze")
DST_REL = "usr/share/sddm/themes/alpbahos"
DST = os.path.join(R4, DST_REL)
if os.path.lexists(DST) or os.path.lexists(os.path.join(R4, "etc/sddm.conf.d/alpbahos-theme.conf")):
    raise SystemExit("the alpbahos theme or its drop-in already exists in this root")
written = {}  # rel path -> (bytes, mode)


def put(rel, data, mode=0o644):
    written[rel] = (data, mode)


# 1. Breeze files, as they are (QML, faces, scripts, licence headers in the files)
for dirpath, _dirs, names in os.walk(SRC):
    for n in names:
        full = os.path.join(dirpath, n)
        rel = os.path.relpath(full, SRC)
        if rel in ("metadata.desktop", "theme.conf", "preview.png", "default-logo.svg"):
            continue
        mode = stat.S_IMODE(os.lstat(full).st_mode) & 0o777
        put(os.path.join(DST_REL, rel), open(full, "rb").read(), mode)
# 2. metadata and config, changed
meta = open(os.path.join(SRC, "metadata.desktop"), encoding="utf-8").read()
meta = re.sub(r"(?m)^Name(\[[^\]]*\])?=.*\n", "", meta)
meta = meta.replace("[SddmGreeterTheme]\n", "[SddmGreeterTheme]\nName=AlpbahOS\n", 1)
meta = re.sub(r"(?m)^Theme-Id=.*$", "Theme-Id=alpbahos", meta)
meta = re.sub(r"(?m)^Description=.*$", "Description=AlpbahOS login theme (based on the KDE Breeze greeter, LGPL-2.0-or-later)", meta)
put(DST_REL + "/metadata.desktop", meta.encode())
conf = open(os.path.join(SRC, "theme.conf"), encoding="utf-8").read()
conf = re.sub(r"(?m)^logo=.*$", "logo=" + "/" + DST_REL + "/logo.png", conf)
conf = re.sub(r"(?m)^showlogo=.*$", "showlogo=shown", conf)
conf = re.sub(r"(?m)^background=.*$", "background=/" + DST_REL + "/background.png", conf)
put(DST_REL + "/theme.conf", conf.encode())
# 3. brand images
put(DST_REL + "/background.png", open(BG, "rb").read())
put(DST_REL + "/logo.png", open(LOGO, "rb").read())
put(DST_REL + "/preview.png", open(BG, "rb").read())
# 4. notice (LGPL file headers stay in the QML files)
put(DST_REL + "/NOTICE", (
    "AlpbahOS login theme 'alpbahos'.\n"
    "Based on the KDE Breeze SDDM greeter theme (installed as /usr/share/sddm/themes/breeze). Breeze is licensed\n"
    "under the GNU Lesser General Public License version 2 or later (LGPL-2.0-or-later); the copyright notices and SPDX\n"
    "headers are kept unchanged in the QML and script files. Changed: metadata.desktop, theme.conf, background.png,\n"
    "logo.png, preview.png (AlpbahOS brand images from branding/alpbahos-brand/wallpaper, the logo from\n"
    "scripts/rebuild/iso/live/make-logo.py).\n").encode())
# 5. the drop-in that selects the theme
put("etc/sddm.conf.d/alpbahos-theme.conf", b"# AlpbahOS BETA: login theme (record sddm-alpbahos-r7fix)\n[Theme]\nCurrent=alpbahos\n")

entries = []
for rel, (data, mode) in sorted(written.items()):
    p = os.path.join(R4, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "wb") as f:
        f.write(data)
    os.chmod(p, mode)
    os.chown(p, 0, 0)
    st = os.lstat(p)
    entries.append({"path": "/" + rel, "type": "file", "mode": stat.S_IMODE(st.st_mode),
                    "uid": 0, "gid": 0, "size": st.st_size,
                    "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest()})
os.makedirs(LEDGER, exist_ok=True)
src_sha = hashlib.sha256(open(os.path.abspath(__file__), "rb").read()).hexdigest()
doc = {"schema": "alpbahOS.package-files/v1",
       "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
       "package": {"name": NAME, "version": VER, "source": {"url": REPO_SRC, "sha256": src_sha}},
       "entries": entries}
man = os.path.join(LEDGER, "manifest.json")
json.dump(doc, open(man, "w"), indent=1, sort_keys=True)
print("entries", len(entries))
print("manifest", man)
