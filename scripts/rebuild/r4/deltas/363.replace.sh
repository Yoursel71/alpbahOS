#!/bin/bash
# REBUILD-R4 363 parted-3.7 (13.1 postlfs/parted.html; docs not built: the page builds them with texinfo, not in R4).
# DEVIATION: --disable-device-mapper. configure stops without libdevmapper (lvm2 is not in R4). Effect: parted has no
# device-mapper (LVM/dm-crypt) partitions. Plain GPT/MBR disks are unaffected. Recorded in docs/verification/iso-beta-2026-11-08.md.
# Row added after 361: Calamares partition backend (kpmcore) needs libparted.
export LANG=C LC_ALL=C
set -eo pipefail
as_root() { "$@"; }; export -f as_root
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/parted-3.7.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
# --- blok 1 ---
./configure --prefix=/usr --disable-static --disable-device-mapper &&
make
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root make install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
cd /sources/blfs-build && rm -rf "$PKG"
