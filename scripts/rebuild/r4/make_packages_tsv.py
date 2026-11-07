#!/usr/bin/env python3
"""REBUILD-R4: write scripts/rebuild/r4/packages.tsv, the ordered BLFS package list for the R4 rebuild.

Inputs (all in the repo unless noted):
  scripts/lfs-blfs/order.txt          row number, name-version, class (REQ, REC-INC, ...), BLFS page URL
  scripts/lfs-blfs/src-meta/packages.tsv   tarball name, primary URL, BLFS md5, page URL per row
  scripts/lfs-blfs/DEVIATIONS.md or the blfs-plan copy   options the test image turned off (notes)
  --blfs-src DIR                      directory of already fetched tarballs (host, optional)
  --blfs-ok FILE                      blfs.ok from the test-image run (optional)

Output columns: NN, name_version, class, tarball, url, md5, page_url, local_source, test_image, disabled_notes.
The md5 column is the BLFS page checksum (the reference the book publishes). It is not a sha256.
Usage: make_packages_tsv.py --repo DIR --deviations FILE --blfs-src DIR --blfs-ok FILE --out FILE
"""
import argparse
import csv
import os
import re
import sys


def read_order(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split(" ")
            if len(parts) < 2 or not parts[0].isdigit():
                continue
            nn = parts[0]
            name = parts[1]
            cls = parts[2] if len(parts) > 2 else ""
            url = parts[3] if len(parts) > 3 else ""
            rows.append((nn, name, cls, url))
    return rows


def read_meta(path):
    meta = {}
    with open(path, encoding="utf-8") as f:
        for row in csv.reader(f, delimiter="\t"):
            if not row or row[0] == "NN":
                continue
            meta[row[0]] = {"tarball": row[2], "url": row[3], "md5": row[4], "page": row[6] if len(row) > 6 else ""}
    return meta


def read_deviations(path):
    notes = {}
    if not path or not os.path.exists(path):
        return notes
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^- (?:\d{4}-\d{2}-\d{2} )?(\d{3})[a-z]? ", line)
            if m:
                notes.setdefault(m.group(1), []).append(line.strip("- \n")[:200])
    return notes


def read_ok(path):
    if not path or not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as f:
        return {line.strip() for line in f if line.strip()}


def build(repo, deviations, blfs_src, blfs_ok):
    order = read_order(os.path.join(repo, "scripts/lfs-blfs/order.txt"))
    meta = read_meta(os.path.join(repo, "scripts/lfs-blfs/src-meta/packages.tsv"))
    notes = read_deviations(deviations)
    ok = read_ok(blfs_ok)
    out = []
    for nn, name, cls, url in order:
        m = meta.get(nn, {})
        local = "no"
        if m.get("tarball") and blfs_src and os.path.exists(os.path.join(blfs_src, m["tarball"])):
            local = "yes"
        out.append([
            nn, name, cls, m.get("tarball", ""), m.get("url", ""), m.get("md5", ""),
            m.get("page", url), local, "ok" if nn in ok else "not-built",
            " | ".join(notes.get(nn, [])),
        ])
    return out


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--deviations", default="")
    ap.add_argument("--blfs-src", default="")
    ap.add_argument("--blfs-ok", default="")
    ap.add_argument("--out", required=True)
    a = ap.parse_args(argv)
    rows = build(a.repo, a.deviations, a.blfs_src, a.blfs_ok)
    with open(a.out, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(["NN", "name_version", "class", "tarball", "url", "md5", "page_url",
                    "local_source", "test_image", "disabled_notes"])
        w.writerows(rows)
    print(f"rows={len(rows)} local_source={sum(1 for r in rows if r[7] == 'yes')} "
          f"test_image_ok={sum(1 for r in rows if r[8] == 'ok')} "
          f"with_disabled_notes={sum(1 for r in rows if r[9])}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
