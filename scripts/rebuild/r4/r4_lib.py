#!/usr/bin/env python3
"""REBUILD-R4 helpers used by run-r4.sh (plan lookup, md5 check, snapshot-diff manifests, ELF list).

Subcommands (all print to stdout; exit 0 on success):
  row      --plan FILE --nn NN            tab-separated: name_version, tarball, md5, local_source, test_image, url
  split    NAME-VERSION                   "name version" (version = last '-' followed by a digit)
  md5      FILE EXPECTED                  prints the md5 of FILE; exit 1 when it differs from EXPECTED
  manifest --root SNAP --diff TSV --name N --version V --url U --sha256 S --out FILE
                                          alpbahOS.package-files/v1 style manifest from the snapshot
                                          diff rows (op A or C; file or symlink). Prints the entry count.
  elfs     --root SNAP --diff TSV         absolute paths (under SNAP) of changed regular ELF files
"""
import argparse
import csv
import datetime
import hashlib
import json
import os
import re
import stat
import sys

# Schema alp adopt-base requires (alp.py BASE_MANIFEST_SCHEMA).
MANIFEST_SCHEMA = "alpbahOS.package-files/v1"

# Paths the build touches that are not part of the package (same family as ownership-check.sh).
EXCL = re.compile(r"^(proc|sys|dev|run|tmp|var/log|var/cache|var/tmp|sources|root|home|var/lib/alp|lost\+found)(/|$)")


def split_name_version(nv):
    m = re.match(r"^(.+?)-(\d[^-]*)$", nv)
    if not m:
        raise ValueError(f"cannot split {nv!r}")
    return m.group(1), m.group(2)


def read_row(plan, nn):
    with open(plan, encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            if row["NN"] == nn:
                return [row["name_version"], row["tarball"], row["md5"], row["local_source"], row["test_image"],
                        row["url"]]
    raise KeyError(nn)


def md5_of(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_diff(path):
    """Rows of `r3_ledger.py diff`: op, path, type, mode(octal), uid, gid, size, target."""
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 8:
                continue
            rows.append(parts)
    return rows


# Index and cache files that build hooks rewrite (install-info, ldconfig). They belong to the base
# records (cpio owns usr/share/info/dir in the R3 root), so a package manifest does not claim them.
# The rewrite is still in the snapshot; the note in rebuild-r4 lists each package that touched one.
HOOK_FILES = {"usr/share/info/dir", "etc/ld.so.cache"}


def changed_entries(diff_rows):
    """Added or changed regular files and symlinks, outside the excluded trees and hook files."""
    out = []
    for op, path, typ, *_ in diff_rows:
        if op not in ("A", "C") or typ not in ("file", "symlink"):
            continue
        if EXCL.match(path) or path in HOOK_FILES:
            continue
        out.append(path)
    return out


def cmd_manifest(a):
    diff_rows = read_diff(a.diff)
    rows = {r[1]: r for r in diff_rows}
    entries = []
    for path in changed_entries(diff_rows):
        _op, _p, typ, mode, uid, gid, _size, _tgt = rows[path]
        full = os.path.join(a.root, path)
        ent = {"path": "/" + path, "type": typ, "mode": int(mode, 8), "uid": int(uid), "gid": int(gid)}
        if typ == "symlink":
            ent["target"] = os.readlink(full)
        else:
            ent["size"] = os.lstat(full).st_size
            ent["sha256"] = sha256_of(full)
        entries.append(ent)
    doc = {
        "schema": MANIFEST_SCHEMA,
        "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "package": {
            "name": a.name,
            "version": a.version,
            "source": {"url": a.url, "sha256": a.sha256},
        },
        "entries": entries,
    }
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1, sort_keys=True)
        f.write("\n")
    print(len(entries))
    return 0


def cmd_elfs(a):
    for path in changed_entries(read_diff(a.diff)):
        full = os.path.join(a.root, path)
        st = os.lstat(full)
        if not stat.S_ISREG(st.st_mode):
            continue
        with open(full, "rb") as f:
            if f.read(4) == b"\x7fELF":
                print(full)
    return 0


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("row")
    r.add_argument("--plan", required=True)
    r.add_argument("--nn", required=True)
    s = sub.add_parser("split")
    s.add_argument("nv")
    m = sub.add_parser("md5")
    m.add_argument("file")
    m.add_argument("expected")
    mf = sub.add_parser("manifest")
    mf.add_argument("--root", required=True)
    mf.add_argument("--diff", required=True)
    mf.add_argument("--name", required=True)
    mf.add_argument("--version", required=True)
    mf.add_argument("--url", required=True, help="https source URL (alp requires https)")
    mf.add_argument("--sha256", required=True, help="sha256 of the source tarball (TOFU, see run-r4.sh)")
    mf.add_argument("--out", required=True)
    el = sub.add_parser("elfs")
    el.add_argument("--root", required=True)
    el.add_argument("--diff", required=True)
    a = ap.parse_args(argv)
    if a.cmd == "row":
        print("\t".join(read_row(a.plan, a.nn)))
    elif a.cmd == "split":
        print(" ".join(split_name_version(a.nv)))
    elif a.cmd == "md5":
        got = md5_of(a.file)
        print(got)
        return 0 if got == a.expected.lower() else 1
    elif a.cmd == "manifest":
        return cmd_manifest(a)
    elif a.cmd == "elfs":
        return cmd_elfs(a)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
