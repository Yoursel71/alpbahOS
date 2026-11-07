#!/usr/bin/env python3
"""Write one build script per Xorg package (REBUILD-R4 groups 079-110, 130-162, 164-172).

The BLFS 13.1 Xorg pages build each group with one loop over the group's md5 list (the generator's
079, 130 and 164 scripts). The driver records one package per build, so each member gets its own
delta, scripts/rebuild/r4/deltas/NNN.replace.sh, with the loop body for that package only. The configure
options are the ones of the 13.1 x7lib page (lib loop: docdir, disable-devel-docs for libXfont2,
appdefaultdir for libXt, disable-open-zfile for libXpm, meson for libpciaccess) and of the x7app and
x7font loops. The font group's post step (the X11-OTF and X11-TTF links, book block 4) goes into the
last font package, the one that ends the group.

Usage: python3 make_xorg_members.py --plan packages.tsv --deltas DIR
"""
import argparse
import os

GROUPS = [
    # (leader, first, last, kind)
    ("079", 79, 110, "lib"),
    ("130", 130, 162, "app"),
    ("164", 164, 172, "font"),
]

LAST_FONT = 172

HEADER = """#!/bin/bash
# REBUILD-R4 {nn}: {tb} per the BLFS 13.1-systemd {kind} loop ({leader} is the group leader in the generator).
set -eo pipefail
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export KF6_PREFIX=/usr
as_root() {{ "$@"; }}; export -f as_root
mkdir -p /sources/blfs-build/xorg && cd /sources/blfs-build/xorg
TB=/sources/blfs-src/{tb}; [ -f "$TB" ] || {{ echo "KAYNAK_YOK $TB"; exit 2; }}
packagedir={stem}
rm -rf "$packagedir"; tar -xf "$TB" || {{ echo "BLOK-FAIL 1 tar"; exit 1; }}
pushd "$packagedir" > /dev/null
"""

FOOTER = """popd > /dev/null
rm -rf "$packagedir"
as_root /sbin/ldconfig
"""

LIB_EXTRA = {
    "libXfont2-": "--disable-devel-docs",
    "libXt-": "--with-appdefaultdir=/etc/X11/app-defaults",
    "libXpm-": "--disable-open-zfile",
}

FONT_POST = """
# --- font group post step (book block 4): TrueType font links for Fontconfig, as root ---
install -v -d -m755 /usr/share/fonts &&
ln -svfn $XORG_PREFIX/share/fonts/X11/OTF /usr/share/fonts/X11-OTF &&
ln -svfn $XORG_PREFIX/share/fonts/X11/TTF /usr/share/fonts/X11-TTF
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 4 rc=$_rc"; exit 1; }
"""


def body(stem, kind):
    if kind == "lib" and (stem.startswith("libpciaccess-") or stem.startswith("libxkbfile-")):
        # 13.1 loop: "libpciaccess* | libxkbfile*" use meson (no docdir, no configure)
        return ("mkdir build && cd build &&\n"
                "meson setup --prefix=$XORG_PREFIX --buildtype=release .. &&\n"
                "ninja &&\n"
                "as_root ninja install\n"
                "cd ..\n")
    if kind == "lib":
        extra = ""
        for prefix, opt in LIB_EXTRA.items():
            if stem.startswith(prefix):
                extra = " " + opt
        return ('docdir="--docdir=$XORG_PREFIX/share/doc/$packagedir"\n'
                "./configure $XORG_CONFIG $docdir" + extra + "\n"
                "make\n"
                "as_root make install\n")
    return ("./configure $XORG_CONFIG\n"
            "make\n"
            "as_root make install\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", required=True)
    ap.add_argument("--deltas", required=True)
    args = ap.parse_args()

    with open(args.plan, encoding="utf-8") as fh:
        rows = {}
        for line in fh.read().split("\n")[1:]:
            cols = line.split("\t")
            if len(cols) == 13:
                rows[int(cols[0])] = cols

    written = []
    for leader, first, last, kind in GROUPS:
        for nn in range(first, last + 1):
            cols = rows.get(nn)
            if cols is None or cols[3] == "" or cols[7] != "yes":
                raise SystemExit("row %03d has no local source (fill_xorg_md5.py first)" % nn)
            tb = cols[3]
            stem = tb
            for ext in (".tar.xz", ".tar.gz", ".tar.bz2"):
                if stem.endswith(ext):
                    stem = stem[: -len(ext)]
            script = HEADER.format(nn="%03d" % nn, tb=tb, kind=kind, leader=leader, stem=stem)
            script += body(stem, kind)
            script += FOOTER
            if kind == "font" and nn == LAST_FONT:
                script += FONT_POST
            path = os.path.join(args.deltas, "%03d.replace.sh" % nn)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(script)
            os.chmod(path, 0o644)
            written.append("%03d" % nn)
    print("wrote %d member script(s): %s" % (len(written), " ".join(written)))


if __name__ == "__main__":
    main()
