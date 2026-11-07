#!/usr/bin/env python3
"""REBUILD-R3-TEMP-01 (reclassify): move the stale perl files into the perl record.

The 1596 files of `alpbahos-temptools-stale` are perl 5.44.0 core modules. A fresh perl 5.44.0
install with the flags of scripts/rebuild/ch8/45-perl.sh writes the same bytes: installperl skips a
file whose content already matches (installperl line 708, `compare($from, $to)`, and ExtUtils::Install
lines 755 and 809-810, "install_unchanged"), so the chapter 8 install left the chapter 7 copies in place.

This script, run as root on a root whose alp database it edits through alp's own functions:
  1. checks that the stale record's file list equals the list file;
  2. compares each file byte for byte with the same path in a fresh DESTDIR install (--fresh);
  3. moves the files that match into the `perl` record, and any that do not match into a record named
     `alpbahos-temptools-unmatched` (kept, not removed);
  4. drops the stale record. Nothing on disk is removed or changed.
Usage: sudo python3 temp01-reclassify.py --root ROOT --alp ALP_PY --fresh INST_DIR --list LIST --report OUT.json
"""
import argparse
import hashlib
import importlib.util
import json
import os
import sys
import datetime

STALE = "alpbahos-temptools-stale"
PERL = "perl"
UNMATCHED = "alpbahos-temptools-unmatched"


def load_alp(path):
    spec = importlib.util.spec_from_file_location("alp_repo", path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["alp_repo"] = mod  # dataclasses in alp.py look the module up by name
    spec.loader.exec_module(mod)
    return mod


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", required=True)
    ap.add_argument("--alp", required=True)
    ap.add_argument("--fresh", required=True)
    ap.add_argument("--list", required=True)
    ap.add_argument("--report", required=True)
    a = ap.parse_args(argv)

    alp = load_alp(a.alp)
    paths = alp.Paths.resolve(a.root)
    listed = [l.strip() for l in open(a.list, encoding="utf-8") if l.strip()]
    if len(set(listed)) != len(listed):
        raise SystemExit("list has duplicates")

    matched, unmatched, missing_fresh = [], [], []
    with alp.DbLock(paths.lock_file):
        db = alp.load_db(paths)
        pkgs = db["packages"]
        stale = pkgs.get(STALE)
        if stale is None:
            raise SystemExit(f"no {STALE} record")
        if set(stale.get("files", [])) != set(listed):
            raise SystemExit("stale record files differ from the list; nothing changed")
        if PERL not in pkgs:
            raise SystemExit("no perl record")
        for rel in listed:
            fresh = os.path.join(a.fresh, "usr", rel[len("usr/"):]) if rel.startswith("usr/") else None
            if fresh is None or not os.path.isfile(fresh):
                missing_fresh.append(rel)
                continue
            live = os.path.join(a.root, rel)
            if os.path.isfile(live) and not os.path.islink(live) and sha256(live) == sha256(fresh):
                matched.append(rel)
            else:
                unmatched.append(rel)
        if missing_fresh:
            # Not matched: nothing to compare with; they stay in the unmatched record.
            pass
        perl = pkgs[PERL]
        perl["files"] = sorted(set(perl.get("files", [])) | set(matched))
        perl.setdefault("reclassified", []).append({
            "from": STALE, "files": len(matched), "method": "byte compare with fresh perl 5.44.0 DESTDIR install",
            "date": datetime.date.today().isoformat(),
        })
        rest = sorted(set(unmatched) | set(missing_fresh))
        if rest:
            pkgs[UNMATCHED] = {
                "name": UNMATCHED, "version": "r3", "method": "lfs-base", "protected": True,
                "installed_by": "alp/adopt-base", "reason": "explicit", "files": rest,
                "config_files": [], "config_hashes": {}, "conflicts": 0, "depends": 0,
                "installed_at": stale.get("installed_at"), "source": stale.get("source"),
                "status": "kept: no byte match with the fresh install, see temp01-reclassify report",
            }
        del pkgs[STALE]
        alp.save_db(paths, db)

    report = {"matched_moved_to_perl": len(matched), "unmatched_kept": len(unmatched),
              "missing_in_fresh": len(missing_fresh), "unmatched": unmatched, "missing": missing_fresh}
    with open(a.report, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=1)
        f.write("\n")
    print(json.dumps({k: v for k, v in report.items() if not isinstance(v, list)}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
