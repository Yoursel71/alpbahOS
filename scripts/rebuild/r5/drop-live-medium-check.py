#!/usr/bin/env python3
"""REBUILD-R5 round 2: remove /usr/lib/alpbahos/live-medium-check from the session-r5fix record (alp).

The helper was used only by the pam_exec variant of sddm-autologin, which was replaced (autologin-r5fix).
Steps, all in the alp database under its lock: drop the path from the record's file list, delete the file from
the R4 root, and remove /usr/lib/alpbahos if it is then empty. Run as root.
Usage: drop-live-medium-check.py <R4_ROOT> <ALP_PY>
"""
import importlib.util
import os
import sys

R4, ALP = sys.argv[1], sys.argv[2]
REL = "usr/lib/alpbahos/live-medium-check"
PKG = "session-r5fix"

spec = importlib.util.spec_from_file_location("alp_repo", ALP)
mod = importlib.util.module_from_spec(spec)
sys.modules["alp_repo"] = mod
spec.loader.exec_module(mod)
paths = mod.Paths.resolve(R4)
with mod.DbLock(paths.lock_file):
    db = mod.load_db(paths)
    rec = db["packages"][PKG]
    removed = 0
    for key in ("files", "symlinks"):
        before = rec.get(key, [])
        rec[key] = [p for p in before if p != REL]
        removed += len(before) - len(rec[key])
    mod.save_db(paths, db)
print("removed from record:", removed)

p = os.path.join(R4, REL)
if os.path.lexists(p):
    os.remove(p)
    print("deleted", p)
d = os.path.dirname(p)
if os.path.isdir(d) and not os.listdir(d):
    os.rmdir(d)
    print("removed empty", d)
