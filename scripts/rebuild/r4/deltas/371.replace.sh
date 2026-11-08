#!/bin/bash
# REBUILD-R4 371 lvm2-2.03.42 (13.1 postlfs/lvm2.html): provides dmsetup and libdevmapper. Row added after 369; needs libaio (row 370).
# Needed by dracut's dm module (dmsquash-live depends on it) for the live ISO initramfs (2026-11-08).
# The book's kernel options are not set here (kernel is r4-root's). Book configure options kept.
export LANG=C LC_ALL=C
set -eo pipefail
as_root() { "$@"; }; export -f as_root
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/LVM2.2.03.42.tgz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
# --- blok 1 ---
export PATH+=:/usr/sbin
./configure --prefix=/usr \
            --enable-cmdlib \
            --enable-pkgconfig \
            --enable-udev_sync &&
make
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root make install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
cd /sources/blfs-build && rm -rf "$PKG"
