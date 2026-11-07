#!/usr/bin/env python3
"""Fill the Xorg rows of scripts/rebuild/r4/packages.tsv from the BLFS 13.1-systemd Xorg pages (REBUILD-R4).

The Xorg pages (x/x7lib.html, x/x7app.html, x/x7font.html) carry one "MD5 FILENAME" list each and a
"Download (HTTP): BASE" line. A row with local_source "no" and an empty tarball column is filled when its package name (the name_version
without the version) is the name of exactly one page filename. The row then takes the 13.1 name_version
and tarball, url (BASE + filename), md5 (from the page), local_source "yes". The 12.4 name stays in
blfs12_name_version, so the driver's subst maps the 12.4 names to the 13.1 ones. status becomes "ok"
when the 13.1 name equals the 12.4 name, else "changed".

Usage: python3 fill_xorg_md5.py --plan packages.tsv page1.html [page2.html ...]
Rows the pages do not list are printed and left unchanged.
"""
import argparse
import html
import re
import sys


def parse_page(path):
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    flat = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", text)))
    base = re.search(r"Download \(HTTP\): (\S+)", flat)
    if not base:
        sys.exit("no 'Download (HTTP):' base in %s" % path)
    base = base.group(1).rstrip("/")
    files = {}
    for md5, fn in re.findall(r"\b([0-9a-f]{32}) (\S+\.tar\.\w+)", flat):
        files[fn] = (md5, base + "/" + fn)
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", required=True)
    ap.add_argument("pages", nargs="+")
    args = ap.parse_args()

    listed = {}
    for page in args.pages:
        listed.update(parse_page(page))

    with open(args.plan, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    filled, unmatched = [], []
    for i, line in enumerate(lines[1:], start=1):
        cols = line.split("\t")
        if len(cols) != 13 or cols[7] != "no" or cols[3] != "":
            continue
        # The row holds the 12.4 version; the page holds the 13.1 version of the same package.
        base = cols[1].rsplit("-", 1)[0]
        hits = [fn for fn in listed if fn.rsplit(".tar", 1)[0].rsplit("-", 1)[0] == base]
        if len(hits) != 1:
            unmatched.append(cols[0] + " " + cols[1])
            continue
        fn = hits[0]
        md5, url = listed[fn]
        name_version = fn.rsplit(".tar", 1)[0]
        cols[1], cols[3], cols[4], cols[5], cols[7] = name_version, fn, url, md5, "yes"
        cols[9] = "ok" if cols[10] == name_version else "changed"
        lines[i] = "\t".join(cols)
        filled.append(cols[0])

    with open(args.plan, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print("filled %d row(s): %s" % (len(filled), " ".join(filled)))
    print("not on the pages (%d): %s" % (len(unmatched), "; ".join(unmatched)))


if __name__ == "__main__":
    main()
