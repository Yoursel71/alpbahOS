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
    """Name and version of a BLFS name-version. The name ends at the first '-' followed by a digit; the
    version is the part up to the next '-' (icu4c-78.3-sources -> icu4c, 78.3). If there is no such
    hyphen (openldap-LMDB_1.0.1), the version starts at the first run of letters followed by a digit."""
    m = re.match(r"^(.+?)-(\d[^-]*)(?:-.*)?$", nv)
    if not m:
        m = re.match(r"^(.+?)-([A-Za-z_]*\d[^-]*)(?:-.*)?$", nv)
    if not m:
        raise ValueError(f"cannot split {nv!r}")
    return m.group(1), m.group(2)


def read_row(plan, nn):
    with open(plan, encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            if row["NN"] == nn:
                # "-" stands for an empty field: bash's read with a tab IFS would merge empty fields.
                vals = [row["name_version"], row["tarball"], row["md5"], row["local_source"], row["test_image"],
                        row["url"], row.get("blfs12_name_version", ""), row.get("blfs12_tarball", "")]
                return [v if v else "-" for v in vals]
    raise KeyError(nn)


def insert_before(src, dst, regex, fragment):
    """Insert the lines of FRAGMENT before the first line of SRC matching REGEX (a per-package delta
    from the 13.1 page, e.g. a sed before ./configure). No match is an error: the delta is not applied."""
    lines = open(src, encoding="utf-8").read().split("\n")
    for i, line in enumerate(lines):
        if re.search(regex, line):
            lines[i:i] = fragment.rstrip("\n").split("\n")
            with open(dst, "w", encoding="utf-8") as f:
                f.write("\n".join(lines))
            return i
    raise SystemExit(f"insert: no line matches {regex!r} in {src}")


def subst(src, dst, pairs):
    """Copy a generated BLFS script with exact string replacements (old, new). Empty old is skipped.
    Used to point a 12.4 script at the 13.1 version: tarball name first, then the directory name."""
    text = open(src, encoding="utf-8").read()
    for old, new in pairs:
        if old and old != new:
            text = text.replace(old, new)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(text)
    return text.count("\n")


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
HOOK_FILES = {"usr/share/info/dir", "etc/ld.so.cache",
              # Catalogs the book appends to with xmlcatalog (docbook-xml 028 created them; 029 appends).
              "etc/xml/catalog"}


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


def transfer(root, alp_py, manifest, name, log, version=""):
    """Last writer owns: a path that this package's manifest names and that another alp record lists is
    taken away from that record (in the database, under alp's own lock). Nothing on disk changes.
    The moves are written to LOG. Returns the number of paths moved."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("alp_repo", alp_py)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["alp_repo"] = mod
    spec.loader.exec_module(mod)
    paths = mod.Paths.resolve(root)
    with open(manifest, encoding="utf-8") as f:
        mine = {e["path"].lstrip("/") for e in json.load(f)["entries"]}
    moved = []
    with mod.DbLock(paths.lock_file):
        db = mod.load_db(paths)
        for pkg, rec in db["packages"].items():
            if pkg == name:
                continue
            # alp keeps symlinks in their own list ("symlinks"); both lists are checked.
            for key in ("files", "symlinks"):
                common = mine & set(rec.get(key, []))
                if common:
                    rec[key] = sorted(set(rec[key]) - common)
                    moved += [(pkg, p) for p in sorted(common)]
        # An older record with the same name (a base record from R3, e.g. shadow 4.18.0): this package
        # replaces it. The files it still owns that this package did not write stay owned, under
        # "<name>-<oldversion>-leftover" (so nothing is unowned); the old record itself is dropped.
        old = db["packages"].get(name)
        if old is not None:
            left_files = sorted(set(old.get("files", [])) - mine)
            left_links = sorted(set(old.get("symlinks", [])) - mine)
            del db["packages"][name]
            if left_files or left_links:
                lname = f"{name}-{old.get('version', 'unknown')}-leftover"
                rec = dict(old)
                rec.update({"name": lname, "files": left_files, "symlinks": left_links,
                            "status": f"leftover of {old.get('version')} after the upgrade to {name} {version}",
                            "protected": True})
                db["packages"][lname] = rec
            moved.append((name, f"REPLACED {old.get('version')}: {len(left_files) + len(left_links)} left"))
        if moved:
            mod.save_db(paths, db)
    with open(log, "a", encoding="utf-8") as f:
        for pkg, p in moved:
            f.write(f"{name}\t{pkg}\t{p}\n")
    return len(moved)


def claim_symlinks(root, alp_py, name, paths_file):
    """Add symlinks that exist on disk and are listed in no record to the record NAME (its symlinks list).
    Used once for libical 4.0.5: the first, failed try created the .so links before its last step failed,
    so the successful try saw them as unchanged and did not list them. Returns the number added."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("alp_repo", alp_py)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["alp_repo"] = mod
    spec.loader.exec_module(mod)
    paths = mod.Paths.resolve(root)
    want = [l.strip() for l in open(paths_file, encoding="utf-8") if l.strip()]
    added = 0
    with mod.DbLock(paths.lock_file):
        db = mod.load_db(paths)
        rec = db["packages"][name]
        known = set(rec.get("files", [])) | set(rec.get("symlinks", []))
        for p in want:
            if p in known or not os.path.islink(os.path.join(root, p)):
                continue
            rec.setdefault("symlinks", []).append(p)
            added += 1
        rec["symlinks"] = sorted(set(rec.get("symlinks", [])))
        mod.save_db(paths, db)
    return added


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
    cl = sub.add_parser("claim")
    cl.add_argument("--root", required=True)
    cl.add_argument("--alp", required=True)
    cl.add_argument("--name", required=True)
    cl.add_argument("--paths", required=True)
    tr = sub.add_parser("transfer")
    tr.add_argument("--root", required=True)
    tr.add_argument("--alp", required=True)
    tr.add_argument("--manifest", required=True)
    tr.add_argument("--name", required=True)
    tr.add_argument("--log", required=True)
    tr.add_argument("--version", default="")
    ins = sub.add_parser("insert")
    ins.add_argument("--in", dest="src", required=True)
    ins.add_argument("--out", dest="dst", required=True)
    ins.add_argument("--before", required=True, help="regex of the first line to insert before")
    ins.add_argument("--file", required=True, help="fragment to insert")
    sb = sub.add_parser("subst")
    sb.add_argument("--in", dest="src", required=True)
    sb.add_argument("--out", dest="dst", required=True)
    sb.add_argument("--pair", nargs=2, action="append", default=[], metavar=("OLD", "NEW"))
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
    elif a.cmd == "subst":
        subst(a.src, a.dst, a.pair)
    elif a.cmd == "claim":
        print(claim_symlinks(a.root, a.alp, a.name, a.paths))
    elif a.cmd == "transfer":
        n = transfer(a.root, a.alp, a.manifest, a.name, a.log, a.version)
        print(n)
    elif a.cmd == "insert":
        insert_before(a.src, a.dst, a.before, open(a.file, encoding="utf-8").read())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
