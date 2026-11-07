#!/usr/bin/env python3
"""REBUILD-R3 ledger tool.

diff       PRE CUR        TSV rows (A added, C changed, D deleted) for the regular files and
                          symlinks that differ between two trees. A change is any difference in
                          ctime, size, mode, owner or symlink target, so writes, installs and
                          renames are seen even when mtimes are preserved.
owners     STEPDIR OWNERS CONFLICTS
                          the last step that wrote a path owns it; a later D removes it.
                          CONFLICTS lists paths written by more than one step.
manifests  --owners F --root R --rb RB --sources S --md5sums M --wget W --alp PY --out DIR
                          one alp adopt-base manifest per package (index.tsv, owned.txt).
                          Hashes are taken from the final state of R, after all steps.
"""
import argparse
import datetime
import glob
import hashlib
import json
import os
import re
import stat
import sys
from collections import defaultdict

# Paths that are never base files: runtime state, build scratch, test logs, the alp database.
EXCL_TOP = ("sources", "proc", "sys", "dev", "run", "tmp", "var/log", "var/cache",
            "var/tmp", "root", "home", "var/lib/alp", "lost+found")
SCHEMA = "alpbahOS.package-files/v1"
REPO_URL = "https://github.com/Yoursel71/alpbahOS"
TAR_RE = re.compile(r"^(?P<name>[A-Za-z0-9][A-Za-z0-9._+-]*?)-(?P<ver>\d[\w.+~-]*)\.tar\.\w+$")
PKG_RE = re.compile(r"^PKG=(\S+)\s*$", re.M)
# Steps whose tarball is not named by PKG= (the kernel is found by glob in sources).
TAR_OVERRIDE = {"ch10-02": "linux-*.tar.*"}
# Step ids whose script number differs from the id (the MPFR re-check after GCC).
STEP_SCRIPT = {"ch08-31b": "22"}
# Out-of-book sources (not in the book md5sums). Their sha256 is recorded in
# docs/verification/rebuild-r2-ch9-ch10-2026-11-07.md (first 20 hex digits, no signature check):
# the local tarball must start with the recorded prefix.
EXTRA_SOURCES = {
    "cpio-2.15.tar.bz2": ("https://ftp.gnu.org/gnu/cpio/cpio-2.15.tar.bz2", "937610b97c329a1ec926"),
    "dracut-ng-112.tar.gz": ("https://github.com/dracut-ng/dracut-ng/archive/refs/tags/112.tar.gz",
                             "839d21eb4bd27bb0ee40"),
}


def excluded(rel):
    return any(rel == e or rel.startswith(e + "/") for e in EXCL_TOP)


def walk(root):
    out = {}
    for dp, dns, fns in os.walk(root, followlinks=False):
        rel_dir = os.path.relpath(dp, root).replace(os.sep, "/")
        if rel_dir == ".":
            rel_dir = ""
        keep = []
        for d in dns:
            rel = f"{rel_dir}/{d}" if rel_dir else d
            if excluded(rel):
                continue
            if os.path.islink(os.path.join(dp, d)):
                fns.append(d)  # a symlink to a directory is recorded, not followed
            else:
                keep.append(d)
        dns[:] = keep
        for name in fns:
            rel = f"{rel_dir}/{name}" if rel_dir else name
            if excluded(rel):
                continue
            p = os.path.join(dp, name)
            st = os.lstat(p)
            if stat.S_ISLNK(st.st_mode):
                rec = ("symlink", st.st_ctime_ns, st.st_size, 0o777, st.st_uid, st.st_gid, os.readlink(p))
            elif stat.S_ISREG(st.st_mode):
                rec = ("file", st.st_ctime_ns, st.st_size, stat.S_IMODE(st.st_mode), st.st_uid, st.st_gid, "")
            else:
                continue
            out[rel] = rec
    return out


def cmd_diff(pre, cur):
    a, b = walk(pre), walk(cur)
    rows = []
    for p in sorted(set(a) | set(b)):
        if p not in a:
            op, rec = "A", b[p]
        elif p not in b:
            op, rec = "D", a[p]
        elif a[p] != b[p]:
            op, rec = "C", b[p]
        else:
            continue
        typ, _ct, size, mode, uid, gid, tgt = rec
        rows.append("\t".join([op, p, typ, f"{mode:o}", str(uid), str(gid), str(size), tgt]))
    sys.stdout.write("\n".join(rows) + ("\n" if rows else ""))


# Chapter 5-7 leftovers, split by origin (split-leftover). Step ids start with "ch05-07-".
LEFT_PREFIX = "ch05-07-"
LEFT_GROUPS = {
    "ch05-07-linux-api-headers": ("linux-api-headers", "7.1.8", "linux-7.1.8.tar.xz"),
    "ch05-07-temptools-stale": ("alpbahos-temptools-stale", "r3", None),
    "ch05-07-ch05": ("alpbahos-ch05-leftover", "r3", None),
    "ch05-07-ch06": ("alpbahos-ch06-leftover", "r3", None),
    "ch05-07-ch07": ("alpbahos-ch07-leftover", "r3", None),
}


def owner_map(stepdir):
    owner = {}
    steps = sorted(f[:-4] for f in os.listdir(stepdir)
                   if f.endswith(".tsv") and not f.startswith(LEFT_PREFIX))
    for step in steps:
        for row in read_tsv(os.path.join(stepdir, step + ".tsv")):
            if row[0] == "D":
                owner.pop(row[1], None)
            else:
                owner[row[1]] = step
    return owner


def cmd_split_leftover(root, stepdir, snapdir, stale_out):
    """Files in the final root that no chapter 8+ step wrote, split by the chapter that
    created them (the first of after-ch5, after-ch6, after-ch7 that holds the path).

    Groups (one step TSV each, see LEFT_GROUPS):
      linux-api-headers   usr/include/**                          (the linux-7.1.8 tarball)
      temptools-stale     usr/lib/perl5/<ver>/** whose relative path is not in ch8 perl's set
                          (ch8 perl is step ch08-45); recorded, not deleted
      ch05 / ch06 / ch07  everything else, by origin chapter
    """
    snaps = {c: set(walk(os.path.join(snapdir, f"after-{c}-2026-11-06")))
             for c in ("ch5", "ch6", "ch7")}
    owned = owner_map(stepdir)
    unowned = sorted(set(walk(root)) - set(owned))
    perl_rel = set()
    for p, s in owned.items():
        if s == "ch08-45" and p.startswith("usr/lib/perl5/"):
            perl_rel.add(re.sub(r"^usr/lib/perl5/[^/]+/", "", p))
    groups = defaultdict(list)
    counts = defaultdict(lambda: defaultdict(int))
    for p in unowned:
        if p in snaps["ch5"]:
            origin = "ch05"
        elif p in snaps["ch6"]:
            origin = "ch06"
        else:
            origin = "ch07"
        if p.startswith("usr/include/"):
            key = "linux-api-headers"
        elif p.startswith("usr/lib/perl5/"):
            key = "temptools-stale" if re.sub(r"^usr/lib/perl5/[^/]+/", "", p) not in perl_rel else origin
        else:
            key = origin
        groups["ch05-07-" + key].append(p)
        counts[key][origin] += 1
    for step in glob.glob(os.path.join(stepdir, LEFT_PREFIX + "*.tsv")):
        os.remove(step)
    for step, paths in sorted(groups.items()):
        with open(os.path.join(stepdir, step + ".tsv"), "w", encoding="utf-8") as f:
            for p in paths:
                f.write(f"A\t{p}\tfile\t\t\t\t\t\n")
    with open(stale_out, "w", encoding="utf-8") as f:
        for p in groups.get("ch05-07-temptools-stale", []):
            f.write(p + "\n")
    print(f"chapter 5-7 leftovers: {len(unowned)}")
    for key in sorted(counts):
        by = ", ".join(f"{o} {n}" for o, n in sorted(counts[key].items()))
        print(f"  {key}: {sum(counts[key].values())} ({by})")
    print(f"  perl5 paths with the same relative path in ch8 perl's set: "
          f"{sum(1 for p in unowned if p.startswith('usr/lib/perl5/') and re.sub(r'^usr/lib/perl5/[^/]+/', '', p) in perl_rel)}")


def cmd_dbowned(root, out):
    """Owned paths as alp's database records them (files and symlinks of every package)."""
    with open(os.path.join(root, "var", "lib", "alp", "db.json"), encoding="utf-8") as f:
        db = json.load(f)
    paths = []
    for name, rec in sorted(db["packages"].items()):
        paths.extend(rec.get("files", []))
        paths.extend(rec.get("symlinks", []))
    with open(out, "w", encoding="utf-8") as f:
        for p in sorted(paths):
            f.write(p + "\n")
    print(f"alp database: {len(db['packages'])} packages, {len(paths)} owned paths")


def read_tsv(path):
    with open(path, encoding="utf-8", errors="surrogateescape") as f:
        for line in f:
            line = line.rstrip("\n")
            if line:
                yield line.split("\t")


def cmd_owners(stepdir, owners_out, conflicts_out):
    owner = {}
    writers = defaultdict(list)
    steps = sorted(f[:-4] for f in os.listdir(stepdir) if f.endswith(".tsv"))
    for step in steps:
        for row in read_tsv(os.path.join(stepdir, step + ".tsv")):
            op, p = row[0], row[1]
            if op == "D":
                owner.pop(p, None)
                continue
            owner[p] = step
            if not writers[p] or writers[p][-1] != step:
                writers[p].append(step)
    n_conf = 0
    with open(conflicts_out, "w", encoding="utf-8") as f:
        f.write("path\tfinal_owner\twriters\n")
        for p in sorted(writers):
            if p in owner and len(writers[p]) > 1:
                n_conf += 1
                f.write(f"{p}\t{owner[p]}\t{','.join(writers[p])}\n")
    with open(owners_out, "w", encoding="utf-8") as f:
        for p in sorted(owner):
            f.write(f"{p}\t{owner[p]}\n")
    print(f"steps: {len(steps)}; owned paths: {len(owner)}; paths written by more than one step: {n_conf}")


def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def md5_file(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_md5sums(path):
    out = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            parts = line.split(None, 1)
            if len(parts) == 2:
                out[parts[1].strip().lstrip("*")] = parts[0]
    return out


def load_wget(path):
    out = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("https://"):
                out[os.path.basename(line)] = line
    return out


def package_for(args, step):
    """Return the package record for a step (its tarball, or the script for config-only steps)."""
    if step == "zz-alp":
        return {"name": "alp", "version": "r3-prototype", "url": REPO_URL,
                "sha256": sha256_file(args.alp), "tar": None}
    if step.startswith(LEFT_PREFIX):
        # Not a build step. A group of chapter 5-7 leftovers (LEFT_GROUPS): with a tarball
        # (linux-api-headers) it is checked like any other package; otherwise its source
        # identity is the sha256 of the exact path list (the group's step TSV).
        name, version, tar = LEFT_GROUPS[step]
        if tar:
            return {"name": name, "version": version, "url": None, "sha256": None, "tar": tar}
        return {"name": name, "version": version, "url": REPO_URL,
                "sha256": sha256_file(os.path.join(args.steps, step + ".tsv")), "tar": None}
    ch, nn = step.split("-")
    n = int(ch[2:])
    # ch08-31b is the MPFR re-check after GCC: it runs the script of ch08-22 (22-mpfr.sh).
    script_no = STEP_SCRIPT.get(step, nn)
    hits = glob.glob(os.path.join(args.rb, f"ch{n}", f"{script_no}-*.sh"))
    if len(hits) != 1:
        raise SystemExit(f"step {step}: expected one script, found {hits}")
    script = hits[0]
    base = os.path.basename(script)[3:-3]
    with open(script, encoding="utf-8") as f:
        m = PKG_RE.search(f.read())
    tar = m.group(1) if m else None
    if step in TAR_OVERRIDE:
        g = sorted(os.path.basename(x) for x in glob.glob(os.path.join(args.sources, TAR_OVERRIDE[step])))
        tar = g[0] if len(g) == 1 else None
    if tar is None:
        return {"name": f"alpbahos-{ch}-{base}", "version": "r3", "url": REPO_URL,
                "sha256": sha256_file(script), "tar": None}
    mm = TAR_RE.match(tar)
    if mm:
        name, ver = mm.group("name"), mm.group("ver")
    else:
        name, ver = base, re.sub(r"\.tar\.\w+$", "", tar)
    return {"name": name, "version": ver, "url": None, "sha256": None, "tar": tar}


def cmd_manifests(args):
    owners = {}
    for row in read_tsv(args.owners):
        owners[row[0]] = row[1]
    md5s = load_md5sums(args.md5sums)
    wget = load_wget(args.wget)
    # Group by package name, not by step: a package rebuilt in a later step (mpfr: ch08-22 and
    # ch08-31b) is one package with one owner per path (the last writer).
    by_pkg = defaultdict(list)
    pkg_of_step = {}
    for p, step in owners.items():
        by_pkg[step].append(p)
    pkgs_by_name = {}
    for step in sorted(by_pkg):
        pkg = package_for(args, step)
        pkg_of_step[step] = pkg["name"]
        if pkg["name"] in pkgs_by_name:
            prev = pkgs_by_name[pkg["name"]]
            if (prev["tar"], prev["version"]) != (pkg["tar"], pkg["version"]):
                raise SystemExit(f"package {pkg['name']}: steps disagree on tarball or version")
        else:
            pkgs_by_name[pkg["name"]] = pkg
    by_step = defaultdict(list)
    for p, step in owners.items():
        by_step[pkg_of_step[step]].append(p)
    os.makedirs(args.out, exist_ok=True)
    index, owned, skipped = [], [], []
    for pname in sorted(by_step):
        pkg = pkgs_by_name[pname]
        step = pname
        if pkg["tar"] and pkg["tar"] in EXTRA_SOURCES:
            url, prefix = EXTRA_SOURCES[pkg["tar"]]
            tarpath = os.path.join(args.sources, pkg["tar"])
            got = sha256_file(tarpath)
            if not got.startswith(prefix):
                raise SystemExit(f"{pkg['tar']}: sha256 {got} does not start with the recorded {prefix}")
            pkg["url"] = url
            pkg["sha256"] = got
        elif pkg["tar"]:
            tarpath = os.path.join(args.sources, pkg["tar"])
            if pkg["tar"] not in md5s or pkg["tar"] not in wget:
                raise SystemExit(f"{pkg['tar']}: not in md5sums or in the book source list")
            got = md5_file(tarpath)
            if got != md5s[pkg["tar"]]:
                raise SystemExit(f"{pkg['tar']}: md5 {got} does not match the book md5sums")
            pkg["url"] = wget[pkg["tar"]]
            pkg["sha256"] = sha256_file(tarpath)
        if not pkg["url"].startswith("https://"):
            raise SystemExit(f"{pkg['name']}: source URL is not https")
        ents = []
        for p in sorted(by_step[step]):
            full = os.path.join(args.root, p)
            st = os.lstat(full)
            if stat.S_ISLNK(st.st_mode):
                ents.append({"path": "/" + p, "type": "symlink", "target": os.readlink(full),
                             "mode": 0o777, "uid": st.st_uid, "gid": st.st_gid})
            elif stat.S_ISREG(st.st_mode):
                ents.append({"path": "/" + p, "type": "file", "sha256": sha256_file(full),
                             "size": st.st_size, "mode": stat.S_IMODE(st.st_mode),
                             "uid": st.st_uid, "gid": st.st_gid})
            else:
                raise SystemExit(f"{p}: owned path is neither file nor symlink")
            owned.append(p)
        if not ents:
            skipped.append(step)
            continue
        manifest = {
            "schema": SCHEMA,
            "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
            "package": {"name": pkg["name"], "version": pkg["version"],
                        "source": {"url": pkg["url"], "sha256": pkg["sha256"]}},
            "entries": ents,
        }
        mpath = os.path.join(args.out, pkg["name"] + ".manifest.json")
        with open(mpath, "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=1, sort_keys=True)
        index.append((pkg["name"], pkg["version"], pkg["sha256"], mpath, len(ents), sha256_file(mpath), step))
    with open(os.path.join(args.out, "index.tsv"), "w", encoding="utf-8") as f:
        f.write("name\tversion\tsource_sha256\tmanifest\tentries\tmanifest_sha256\tstep\n")
        for row in index:
            f.write("\t".join(str(x) for x in row) + "\n")
    with open(os.path.join(args.out, "owned.txt"), "w", encoding="utf-8") as f:
        for p in sorted(owned):
            f.write(p + "\n")
    print(f"packages with manifests: {len(index)}; entries: {len(owned)}; "
          f"steps without entries: {' '.join(skipped) or 'none'}")


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("diff")
    d.add_argument("pre")
    d.add_argument("cur")
    o = sub.add_parser("owners")
    o.add_argument("stepdir")
    o.add_argument("owners_out")
    o.add_argument("conflicts_out")
    dbo = sub.add_parser("dbowned")
    dbo.add_argument("root")
    dbo.add_argument("out")
    lo = sub.add_parser("split-leftover")
    lo.add_argument("root")
    lo.add_argument("stepdir")
    lo.add_argument("snapdir")
    lo.add_argument("stale_out")
    m = sub.add_parser("manifests")
    for opt in ("--owners", "--root", "--rb", "--sources", "--md5sums", "--wget", "--alp", "--out",
                "--steps"):
        m.add_argument(opt, required=True)
    a = ap.parse_args(argv)
    if a.cmd == "diff":
        cmd_diff(a.pre, a.cur)
    elif a.cmd == "owners":
        cmd_owners(a.stepdir, a.owners_out, a.conflicts_out)
    elif a.cmd == "split-leftover":
        cmd_split_leftover(a.root, a.stepdir, a.snapdir, a.stale_out)
    elif a.cmd == "dbowned":
        cmd_dbowned(a.root, a.out)
    else:
        cmd_manifests(a)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
