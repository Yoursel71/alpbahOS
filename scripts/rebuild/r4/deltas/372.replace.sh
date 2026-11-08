#!/bin/bash
# REBUILD-R4 372 parted-3.7 with device-mapper (second build of parted, row 363 without it). lvm2 (row 371) is in R4 now.
# Device-mapper enabled: libdevmapper from lvm2 (371). Name in 372.name: parted-3.7-dm (alp keeps one record per name).
# (no deviation in this row)
# Row added after 361: Calamares partition backend (kpmcore) needs libparted.
export LANG=C LC_ALL=C
set -eo pipefail
as_root() { "$@"; }; export -f as_root
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/parted-3.7.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
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
