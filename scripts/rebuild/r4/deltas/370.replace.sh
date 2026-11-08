#!/bin/bash
# REBUILD-R4 370 libaio-0.3.113 (13.1 general/libaio.html). Row added after 369: lvm2 (371) needs libaio.h.
# DEVIATION (source URL): the book's releases.pagure.org URL returns 404; the file comes from the Debian mirror
# (deb.debian.org libaio_0.3.113.orig.tar.gz). Its md5 equals the book's md5 (7d5be185...), so the content is the same.
# Book step kept: the sed that comments out the static libaio.a install.
export LANG=C LC_ALL=C
set -eo pipefail
as_root() { "$@"; }; export -f as_root
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/libaio-0.3.113.tar.gz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
# --- blok 1 ---
sed -i '/install.*libaio.a/s/^/#/' src/Makefile &&
make
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root make install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
cd /sources/blfs-build && rm -rf "$PKG"
