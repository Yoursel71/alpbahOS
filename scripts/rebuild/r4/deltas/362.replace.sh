#!/bin/bash
# REBUILD-R4 362 libatasmart-0.19 (13.1 general/libatasmart.html). Row added after 361: kpmcore needs it for SMART data.
export LANG=C LC_ALL=C
set -eo pipefail
as_root() { "$@"; }; export -f as_root
export QT6DIR=/opt/qt6
export PATH=/opt/qt6/bin:$PATH
export PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:${PKG_CONFIG_PATH:-}
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/libatasmart-0.19.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
# --- blok 1 ---
./configure --prefix=/usr --disable-static &&
make
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root make install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
cd /sources/blfs-build && rm -rf "$PKG"
