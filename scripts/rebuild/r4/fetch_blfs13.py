#!/usr/bin/env python3
"""REBUILD-R4 (D145): re-derive the package list from the BLFS 13.1-systemd book.

Reads scripts/rebuild/r4/packages.tsv (the BLFS 12.4 derived list: NN, name_version, class, tarball, url,
md5, page_url, local_source, test_image, disabled_notes), fetches the 13.1-systemd page for each row and
writes scripts/rebuild/r4/packages-13.1.tsv with the 13.1 name-version, tarball, download URL and the
book's MD5 sum. Pages are cached under --cache so a rerun does not fetch again.

Columns: NN, name_version, class, tarball, url, md5, page_url, status, blfs12_name_version, disabled_notes
status: ok | changed (version differs from 12.4) | page-404 | no-download | no-md5 | page-error
Usage: fetch_blfs13.py --plan packages.tsv --out packages-13.1.tsv --cache DIR
"""
import argparse
import csv
import html
import os
import re
import sys
import time
import urllib.error
import urllib.request

OLD = "12.4-systemd"
NEW = "13.1-systemd"


def fetch(url, cache):
    key = re.sub(r"[^A-Za-z0-9._-]", "_", url)
    path = os.path.join(cache, key)
    if os.path.exists(path):
        with open(path, encoding="utf-8", errors="replace") as f:
            return 200, f.read()
    req = urllib.request.Request(url, headers={"User-Agent": "alpbahOS-R4/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = r.read().decode("utf-8", errors="replace")
            code = r.status
    except urllib.error.HTTPError as e:
        return e.code, ""
    except Exception:
        return 0, ""
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
    time.sleep(0.2)
    return code, body


URL_RE = r"(https?://[^\s\"'<>]+\.(?:tar\.[a-z0-9]+|tgz|tar|zip|tbz2?|txz|crate|whl|gem))"


def parse_page(body):
    """Return (download_urls, pairs). A page can hold several packages, so each 'Download MD5 sum: <hex>'
    is paired with the last tarball URL before it (the same table row in BLFS pages). pairs is a list of
    (url, md5) in page order."""
    text = html.unescape(re.sub(r"<[^>]+>", " ", body))
    urls = re.findall(URL_RE, text)
    pairs = []
    last_url = None
    for m in re.finditer(URL_RE + r"|Download MD5 sum:\s*([0-9a-fA-F]{32})", text):
        if m.group(1):
            last_url = m.group(1)
        elif m.group(2) and last_url:
            pairs.append((last_url, m.group(2)))
    return urls, pairs


def md5_for(pairs, url):
    for u, m in pairs:
        if u == url:
            return m
    return ""


def pick_tarball(urls, name):
    """(url, matched): the package's own tarball, the first URL whose basename starts with the package
    name. When none matches, the first URL is returned with matched False (a guess, checked by hand)."""
    base_name = re.split(r"-\d", name, 1)[0].lower()
    for u in urls:
        b = u.rsplit("/", 1)[-1].lower()
        if b.startswith(base_name + "-") or b.startswith(base_name.replace("-", "")):
            return u, True
    return (urls[0], False) if urls else ("", False)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--plan", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--cache", required=True)
    a = ap.parse_args(argv)
    os.makedirs(a.cache, exist_ok=True)
    rows = list(csv.DictReader(open(a.plan, encoding="utf-8"), delimiter="\t"))
    out = []
    for r in rows:
        page12 = r["page_url"]
        page13 = page12.replace(OLD, NEW)
        status = "ok"
        name13, tb, url, md5 = r["name_version"], "", "", ""
        code, body = fetch(page13, a.cache)
        if code == 404 or (code == 0 and not body):
            status = "page-404" if code == 404 else "page-error"
        else:
            urls, pairs = parse_page(body)
            url, matched = pick_tarball(urls, r["name_version"]) if urls else ("", False)
            # A page with one tarball whose old row was sourced (e.g. libyaml -> yaml-0.2.5) is not a guess.
            if not matched and url and len(set(urls)) == 1 and r["local_source"] == "yes":
                matched = True
            if not url:
                status = "no-download"
            else:
                tb = url.rsplit("/", 1)[-1]
                name13 = re.sub(r"\.(tar\.[a-z0-9]+|tgz|tar|zip|tbz2?|txz|crate|whl|gem)$", "", tb)
                if not matched:
                    status = "name-guess"
            md5 = md5_for(pairs, url) if url else ""
            if url and not md5:
                # The 13.1 page has no md5 line. Carry the 12.4 md5 only for the same version.
                if name13 == r["name_version"] and r["md5"]:
                    md5 = r["md5"]
                    status = "md5-carried-12.4" if status == "ok" else status
                else:
                    status = "no-md5" if status == "ok" else status
            if status == "ok" and name13 != r["name_version"]:
                status = "changed"
        usable = status in ("ok", "changed", "md5-carried-12.4") and bool(url and md5)
        out.append([r["NN"], name13, r["class"], tb, url, md5, page13,
                    "yes" if usable else "no", r["test_image"], status,
                    r["name_version"], r["tarball"], r["disabled_notes"]])
        print(r["NN"], status, name13, file=sys.stderr)
    with open(a.out, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(["NN", "name_version", "class", "tarball", "url", "md5", "page_url", "local_source",
                    "test_image", "status", "blfs12_name_version", "blfs12_tarball", "disabled_notes"])
        w.writerows(out)
    counts = {}
    for o in out:
        counts[o[7]] = counts.get(o[7], 0) + 1
    print("status counts:", counts)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
