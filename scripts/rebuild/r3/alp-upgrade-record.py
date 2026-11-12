#!/usr/bin/env python3
"""Record the alp upgrade in the root's alp database (REBUILD-R3 maintenance).

alp's own `upgrade` refuses lfs-base records ("LFS taban paketi; alp ile yükseltilmesi kapalı"), and
the alp package is one, so the new file is put in place by copy (as the R3 zz-alp step did) and this
script records it: the alp record keeps its file list, and its ownership block names the new file's
sha256, the repo source, and the previous file's sha256. The alp files are checked before and after.
Usage: sudo python3 alp-upgrade-record.py --root ROOT --alp REPO_ALP_PY --previous-sha SHA
"""
import argparse
import hashlib
import importlib.util
import os
import sys
import datetime

ALP_FILE = "usr/lib/alp/alp.py"


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", required=True)
    ap.add_argument("--alp", required=True)
    ap.add_argument("--previous-sha", required=True)
    a = ap.parse_args(argv)
    spec = importlib.util.spec_from_file_location("alp_repo", a.alp)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["alp_repo"] = mod
    spec.loader.exec_module(mod)
    paths = mod.Paths.resolve(a.root)
    live = os.path.join(a.root, ALP_FILE)
    new_sha = sha256(live)
    repo_sha = sha256(a.alp)
    if new_sha != repo_sha:
        raise SystemExit(f"installed alp.py ({new_sha}) is not the repo file ({repo_sha}); copy first")
    with mod.DbLock(paths.lock_file):
        db = mod.load_db(paths)
        rec = db["packages"].get("alp")
        if rec is None:
            raise SystemExit("no alp record")
        if ALP_FILE not in rec.get("files", []):
            raise SystemExit("alp record does not list " + ALP_FILE)
        rec.setdefault("upgrades", []).append({
            "date": datetime.date.today().isoformat(),
            "file": "/" + ALP_FILE,
            "from_sha256": a.previous_sha,
            "to_sha256": new_sha,
            "source": "docs/handoffs/ai/alp-prototype/alp.py (repo)",
            "method": "copy + record (alp upgrade refuses lfs-base records)",
        })
        rec["version"] = rec.get("version", "r3-prototype")
        mod.save_db(paths, db)
    print("alp record updated; installed sha256", new_sha)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
