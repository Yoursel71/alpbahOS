#!/usr/bin/env python3
"""REBUILD-R3: classify the content differences between r3-root and /mnt/lfs13.

Input: the rsync itemize file (lines '>fc...  path' = content differs in both trees).
For every differing regular file the script looks at the file kind (ELF, static archive,
.pyc, gzip, text, other) and runs the check that fits the kind:
  ELF    build-id (readelf -n) on both; if none, the byte difference count and whether the size
         differs; a 'strings' diff size is taken for a sample.
  AR     member list (name, size) of both archives from 'ar tv'; a member-level comparison
         reports date-only, mode/owner-only, or content differences (member bytes via 'ar x').
  PYC    bytes after the 16-byte header (magic, flags, mtime/hash, size): equal means the
         difference is in the header only.
  TEXT   'diff' line count.
  OTHER  byte difference count.
Writes a per-file TSV and a summary; prints a 50-file sample with the deep check output.
"""
import collections
import os
import random
import subprocess
import sys
import tempfile

LFS = "/mnt/lfs13"
R3 = "/home/yrslf/alpbahOS/scratch-lfs-bench/r3-root"


def kind(path):
    try:
        with open(path, "rb") as f:
            head = f.read(4096)
    except OSError:
        return "missing"
    if head.startswith(b"\x7fELF"):
        return "elf"
    if head.startswith(b"!<arch>\n"):
        return "ar"
    if path.endswith(".pyc"):
        return "pyc"
    if head.startswith(b"\x1f\x8b"):
        return "gzip"
    if b"\x00" not in head:
        return "text"
    return "other"


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, errors="replace").stdout


def buildid(p):
    out = run(["readelf", "-n", p])
    for line in out.splitlines():
        if "Build ID:" in line:
            return line.split("Build ID:")[1].strip()
    return ""


def byte_diffs(a, b):
    with open(a, "rb") as fa, open(b, "rb") as fb:
        da, db = fa.read(), fb.read()
    n = min(len(da), len(db))
    return sum(1 for i in range(n) if da[i] != db[i]) + abs(len(da) - len(db))


def ar_members(p):
    out = []
    for line in run(["ar", "tv", p]).splitlines():
        parts = line.split()
        if len(parts) >= 9:
            out.append((parts[-1], parts[2]))  # name, size (fields: mode uid/gid size date name)
    return out


def ar_check(a, b):
    ma, mb = ar_members(a), ar_members(b)
    if [n for n, _ in ma] != [n for n, _ in mb]:
        return "ar: member names or order differ"
    if [s for _, s in ma] != [s for _, s in mb]:
        return "ar: member sizes differ"
    with tempfile.TemporaryDirectory() as da, tempfile.TemporaryDirectory() as db:
        subprocess.run(["ar", "x", os.path.abspath(a)], cwd=da, capture_output=True)
        subprocess.run(["ar", "x", os.path.abspath(b)], cwd=db, capture_output=True)
        differ = []
        for name, _ in ma:
            pa, pb = os.path.join(da, name), os.path.join(db, name)
            if not (os.path.exists(pa) and os.path.exists(pb)):
                differ.append(name)
                continue
            with open(pa, "rb") as fa, open(pb, "rb") as fb:
                if fa.read() != fb.read():
                    differ.append(name)
    if not differ:
        return "ar: same members and bytes (archive header dates/owners only)"
    return f"ar: {len(differ)} member(s) with different bytes (e.g. {differ[0]})"


def classify(rel):
    a, b = os.path.join(LFS, rel), os.path.join(R3, rel)
    k = kind(a)
    if k == "missing" or kind(b) == "missing":
        return k, "missing in one tree", ""
    if k == "elf":
        ida, idb = buildid(a), buildid(b)
        if ida and idb:
            return k, ("elf: build-id differs" if ida != idb else "elf: build-id same, bytes differ"), ""
        size_same = os.path.getsize(a) == os.path.getsize(b)
        return k, f"elf: no build-id; size {'same' if size_same else 'differs'}", ""
    if k == "ar":
        return k, ar_check(a, b), ""
    if k == "pyc":
        with open(a, "rb") as fa, open(b, "rb") as fb:
            da, db = fa.read(), fb.read()
        if da[16:] == db[16:]:
            return k, "pyc: header only (mtime or hash field)", ""
        return k, "pyc: code bytes differ", ""
    if k == "text":
        out = run(["diff", a, b])
        return k, "text differs", f"{sum(1 for l in out.splitlines() if l.startswith(('<', '>')))} changed lines"
    return k, f"{k}: {byte_diffs(a, b)} byte(s) differ, size {'same' if os.path.getsize(a) == os.path.getsize(b) else 'differs'}", ""


def main(itemize, out_tsv):
    rels = []
    with open(itemize, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith(">fc"):
                rels.append(line.rstrip("\n").split(" ", 1)[1])
    print(f"content differences to classify: {len(rels)}")
    rows = []
    for rel in rels:
        k, cat, detail = classify(rel)
        rows.append((rel, k, cat, detail))
    with open(out_tsv, "w", encoding="utf-8") as f:
        for r in rows:
            f.write("\t".join(r) + "\n")
    summary = collections.Counter(r[2] for r in rows)
    print("category counts:")
    for cat, n in summary.most_common():
        print(f"  {n:5d}  {cat}")
    random.seed(7)
    sample = random.sample(rows, min(50, len(rows)))
    print("sample (50):")
    for rel, k, cat, detail in sorted(sample):
        print(f"  {k:6s} {cat} | {rel} {detail}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
