#!/bin/bash
# REBUILD-R4 202 kapidox-6.29.0: one framework per package (option b). The 13.1 frameworks6 page builds each
# --no-deps on the install: doxypypy, doxyqml and requests are the page's recommended kapidox dependencies, not in the R4 list (API docs only).
# framework with the same cmake block, in the order of frameworks-6.29.0.md5; kapidox is a pip module.
export LANG=C LC_ALL=C
set -eo pipefail
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export KF6_PREFIX=/usr
export QT6DIR=/opt/qt6
export QT6PREFIX=/opt/qt6
export PATH=/opt/qt6/bin:$PATH
export PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:${PKG_CONFIG_PATH:-}
as_root() { "$@"; }; export -f as_root
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/kapidox-6.29.0.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
# --- blok 1 --- (kapidox is a python module)
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD &&
as_root pip3 install --no-index --no-deps --find-links dist --no-user kapidox
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
