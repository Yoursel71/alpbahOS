#!/usr/bin/env python3
"""REBUILD-R8 record (alp): records a staged tree (DESTDIR-style directory) into an R4 root.

Copies every regular file and symlink of STAGE into R4 (same relative path, same mode; symlinks as symlinks),
skipping the paths listed in EXCLUDE, and writes the manifest (alp adopt-base input). A path that already exists in
R4 is refused: a new record must not overwrite another record's file (use the transfer step for that), unless REPLACE=1 is set: the new record then takes the file over (alp transfer).
Run as root. Usage: stage-record-r8.py <R4_ROOT> <ALP_PY> <LEDGER_DIR> <STAGE_DIR> <NAME> <VER> [EXCLUDE ...]
"""
import datetime
import hashlib
import json
import os
import stat
import sys
R4, ALP, LEDGER, STAGE, NAME, VER = sys.argv[1:7]
EXCLUDE = set(sys.argv[7:])
REPO_SRC = "https://github.com/alperenyardim30-hash/alpbahOS/blob/ai/t2-kisayol-2026-11-05/scripts/rebuild/r8/stage-record-r8.py"
entries = []
for dirpath, dirs, names in os.walk(STAGE):
    # A symlink to a directory is listed by os.walk under dirs (and not descended into), so it is taken from there:
    # before round 40 these links were dropped silently (FW-DIRLINK-01: nvidia/gb206 -> gb202 and 15 more firmware links).
    links = [d for d in dirs if os.path.islink(os.path.join(dirpath, d))]
    for n in sorted(names + links):
        full = os.path.join(dirpath, n)
        rel = os.path.relpath(full, STAGE)
        if rel in EXCLUDE:
            continue
        dst = os.path.join(R4, rel)
        if os.path.lexists(dst) and os.environ.get("REPLACE") != "1":
            raise SystemExit(f"{dst} already exists")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        lst = os.lstat(full)
        if stat.S_ISLNK(lst.st_mode):
            target = os.readlink(full)
            if os.path.lexists(dst):
                os.remove(dst)  # only reached with REPLACE=1
            os.symlink(target, dst)
            entries.append({"path": "/" + rel, "type": "symlink", "target": target, "mode": 0o777,
                            "uid": 0, "gid": 0})
            continue
        try:
            with open(full, "rb") as f:
                data = f.read()
        except OSError as exc:
            raise SystemExit(f"cannot read {full}: {exc}")
        with open(dst, "wb") as f:
            f.write(data)
        mode = stat.S_IMODE(lst.st_mode) & 0o7777
        # chown before chmod: chown() clears the setuid/setgid bits of a file (Linux, also for root), so the other
        # order lost them (found 2026-11-10 with sudo, B6).
        os.chown(dst, 0, 0)
        os.chmod(dst, mode)
        entries.append({"path": "/" + rel, "type": "file", "mode": mode, "uid": 0, "gid": 0,
                        "size": len(data), "sha256": hashlib.sha256(data).hexdigest()})
os.makedirs(LEDGER, exist_ok=True)
src_sha = hashlib.sha256(open(os.path.abspath(__file__), "rb").read()).hexdigest()
doc = {"schema": "alpbahOS.package-files/v1",
       "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
       "package": {"name": NAME, "version": VER, "source": {"url": REPO_SRC, "sha256": src_sha}},
       "entries": entries}
json.dump(doc, open(os.path.join(LEDGER, "manifest.json"), "w"), indent=1, sort_keys=True)
print("entries", len(entries))
