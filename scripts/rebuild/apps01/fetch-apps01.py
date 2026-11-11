#!/usr/bin/env python3
"""APPS-01 sources: read the BLFS 13.1-systemd pages, download each package and its patches, check the book MD5.

Runs on the host as the build user. Output directory: scratch-lfs-bench/apps01-src (one file per tarball/patch) and
apps01-src/SOURCES.tsv (page, file, url, book md5, md5 ok, sha256). An existing file is re-checked, not downloaded
again. Exit 1 when any MD5 does not match or a download fails.
Usage: fetch-apps01.py [PAGE ...]   (default: every page in PAGES)
"""
import hashlib
import html
import re
import subprocess
import sys
from pathlib import Path

BOOK = "https://www.linuxfromscratch.org/blfs/view/13.1-systemd/"
OUT = Path("/home/yrslf/alpbahOS/scratch-lfs-bench/apps01-src")
# page -> list of (section anchor text or None, extra download labels to take besides "Download (HTTP)")
PAGES = {
    "general/nasm.html": None,
    "general/nspr.html": None,
    "postlfs/nss.html": None,
    "general/cbindgen.html": None,
    "general/nodejs.html": None,
    "x/libnotify.html": None,
    "x/startup-notification.html": None,
    "xsoft/firefox.html": None,
    "general/lua.html": None,
    "multimedia/liba52.html": None,
    "multimedia/libmad.html": None,
    "general/desktop-file-utils.html": None,
    "multimedia/vlc.html": None,
    "general/zip.html": None,
    "general/perl-modules.html": 'id="perl-archive-zip"',
    "xsoft/libreoffice.html": None,
}


def text_of(raw: str) -> str:
    t = re.sub(r"<[^>]+>", " ", raw)
    t = html.unescape(t)
    return re.sub(r"[ \t\r\f\v]+", " ", t)


def entries(page: str, section: str | None, raw: str):
    """Yield (url, md5) for the main download(s) and the patches of a page (or of one section of it)."""
    if section:
        i = raw.find(section)
        if i < 0:
            raise SystemExit(f"{page}: section {section} not found")
        j = raw.find('class="sect2"', i + 1)
        raw = raw[i:j if j > 0 else None]
    t = text_of(raw)
    # "Download (HTTP): URL ... Download MD5 sum: X"; LibreOffice: "Core Download: URL ... Core Download MD5 sum: X"
    # and the Translations (Turkish UI) and Dictionaries (Turkish spelling) tarballs; the Help tarball is not used.
    for m in re.finditer(r"(Download \(HTTP\)|Core Download|Translations|Dictionaries):\s*(https?://\S+)\s+"
                         r"(?:Core Download |Translations |Dictionaries |Download )?MD5 sum:\s*([0-9a-f]{32})", t):
        yield m.group(2), m.group(3)
    for m in re.finditer(r'href=\s*"(https://www\.linuxfromscratch\.org/patches/blfs/13\.1/[^"]+\.patch)"', raw):
        yield m.group(1), None


def md5sha(p: Path):
    h1, h2 = hashlib.md5(), hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h1.update(b)
            h2.update(b)
    return h1.hexdigest(), h2.hexdigest()


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    pages = sys.argv[1:] or list(PAGES)
    rows, bad = [], 0
    for page in pages:
        raw = subprocess.run(["curl", "-fsSL", "--max-time", "60", BOOK + page],
                             check=True, capture_output=True, text=True).stdout
        seen = set()
        for url, md5 in entries(page, PAGES.get(page), raw):
            if url in seen:
                continue
            seen.add(url)
            dest = OUT / url.rsplit("/", 1)[1]
            if not dest.exists():
                r = subprocess.run(["curl", "-fL", "--retry", "3", "--max-time", "3600", "-o", str(dest) + ".part", url])
                if r.returncode != 0:
                    print(f"FAIL download {url}")
                    bad += 1
                    continue
                Path(str(dest) + ".part").rename(dest)
            got_md5, sha = md5sha(dest)
            ok = "-" if md5 is None else ("yes" if got_md5 == md5 else "NO")
            if ok == "NO":
                bad += 1
            rows.append((page, dest.name, url, md5 or "-", ok, sha))
            print(f"{ok:4} {dest.name}")
    with (OUT / "SOURCES.tsv").open("a") as f:
        for r in rows:
            f.write("\t".join(r) + "\n")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
