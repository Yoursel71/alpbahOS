#!/usr/bin/env python3
"""REBUILD-R3: deep checks on a sample of the content differences (r3-root vs /mnt/lfs13).
Read-only. Prints one block per path. Password hashes in etc/shadow are masked."""
import os
import subprocess
import sys

LFS = "/mnt/lfs13"
R3 = "/home/yrslf/alpbahOS/scratch-lfs-bench/r3-root"


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, errors="replace").stdout


def first_diff(a, b):
    with open(a, "rb") as fa, open(b, "rb") as fb:
        da, db = fa.read(), fb.read()
    n = min(len(da), len(db))
    diffs = [i for i in range(n) if da[i] != db[i]]
    if not diffs:
        return f"no common-prefix byte differences (lengths {len(da)} / {len(db)})"
    i = diffs[0]
    return f"{len(diffs)} differing byte(s); first at offset {i}; span {diffs[0]}..{diffs[-1]}"


def strings_diff(a, b):
    sa = run(["strings", "-n", "6", a]).splitlines()
    sb = run(["strings", "-n", "6", b]).splitlines()
    import difflib
    d = [l for l in difflib.unified_diff(sa, sb, lineterm="", n=0) if l[:1] in "+-" and l[:3] not in ("+++", "---")]
    return len(d), d[:4]


def show(rel):
    a, b = os.path.join(LFS, rel), os.path.join(R3, rel)
    print(f"== {rel}")
    if rel.endswith(("/etc/shadow", "etc/shadow", "etc/shadow-")):
        # names and field counts only; hashes never printed
        la = [x.split(":")[0] for x in open(a, encoding="utf-8", errors="replace").read().splitlines()]
        lb = [x.split(":")[0] for x in open(b, encoding="utf-8", errors="replace").read().splitlines()]
        print(f"   accounts in /mnt/lfs13: {len(la)}, in r3-root: {len(lb)}; same account names in same order: {la == lb}")
        only_a = sorted(set(la) - set(lb))
        only_b = sorted(set(lb) - set(la))
        print(f"   only in /mnt/lfs13: {only_a[:10]}; only in r3-root: {only_b[:10]}")
        ha = [x.split(":")[1] if ":" in x else "" for x in open(a, encoding="utf-8", errors="replace").read().splitlines()]
        hb = [x.split(":")[1] if ":" in x else "" for x in open(b, encoding="utf-8", errors="replace").read().splitlines()]
        print(f"   hash field differs for {sum(1 for x, y in zip(ha, hb) if x != y)} account(s) (values masked)")
        return
    if rel.endswith(".pdf"):
        print("   " + first_diff(a, b))
        return
    if rel.startswith("usr/lib/python") and rel.endswith(".so") or rel.endswith((".so", ".so.4", ".so.6", ".ko", "/less", "/zstd", ".so.1.0")) or rel.endswith(("/vim", "/cc1", "/cc1plus")):
        print("   " + first_diff(a, b))
        n, sample = strings_diff(a, b)
        print(f"   strings differing lines: {n}")
        for s in sample:
            print("     " + s[:150])
        bidA, bidB = run(["readelf", "-n", a]), run(["readelf", "-n", b])
        print(f"   build-id lines: lfs13={[l.strip() for l in bidA.splitlines() if 'Build ID' in l]} r3={[l.strip() for l in bidB.splitlines() if 'Build ID' in l]}")
        return
    if rel.endswith(".a"):
        print("   " + first_diff(a, b))
        return
    if rel.startswith("boot/"):
        print("   " + first_diff(a, b))
        return
    # text
    out = run(["diff", a, b]).splitlines()
    print(f"   diff lines: {len(out)}")
    for l in out[:8]:
        print("     " + l[:160])


if __name__ == "__main__":
    for rel in sys.argv[1:]:
        show(rel)
