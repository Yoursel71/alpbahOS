#!/usr/bin/env python3
"""REBUILD-R5 branding record (alp): /etc/os-release and /etc/lsb-release say AlpbahOS 0.9 Beta.

Writes the two files into an R4 root and records them as one alp package "branding-r5fix" (0.9-r5fix) with
alp adopt-base. Run as root. Usage: brand-r5fix.py <R4_ROOT> <ALP_PY> <LEDGER_DIR>
The earlier values (R2 labels, "13.1-systemd R2") are kept in the ledger as *.before.
"""
import datetime
import hashlib
import json
import os
import shutil
import stat
import sys

R4, ALP, LEDGER = sys.argv[1], sys.argv[2], sys.argv[3]
NAME = "branding-r5fix"
VER = "0.9-r5fix"
# Config record (no upstream archive): the source is this file in the repository (https URL, as adopt-base requires);
# the sha256 is the sha256 of this file.
REPO_SRC = "https://github.com/alperenyardim30-hash/alpbahOS/blob/ai/t2-kisayol-2026-11-05/scripts/rebuild/r5/brand-r5fix.py"

files = {
    "etc/os-release": (
        'NAME="AlpbahOS"\n'
        'VERSION="0.9 Beta"\n'
        "ID=alpbahos\n"
        "ID_LIKE=lfs\n"
        'VERSION_ID="0.9"\n'
        'PRETTY_NAME="AlpbahOS 0.9 Beta"\n', 0o644),
    "etc/lsb-release": (
        'DISTRIB_ID="AlpbahOS"\n'
        'DISTRIB_RELEASE="0.9-beta"\n'
        'DISTRIB_CODENAME="beta"\n'
        'DISTRIB_DESCRIPTION="AlpbahOS 0.9 Beta (LFS 13.1 base)"\n', 0o644),
}

os.makedirs(LEDGER, exist_ok=True)
entries = []
for rel, (content, mode) in sorted(files.items()):
    p = os.path.join(R4, rel)
    bak = os.path.join(LEDGER, rel.replace("/", "_") + ".before")
    if os.path.exists(p) and not os.path.exists(bak):
        shutil.copy2(p, bak)
    with open(p, "w") as f:
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
