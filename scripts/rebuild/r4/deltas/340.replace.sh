#!/bin/bash
# REBUILD-R4 340 squashfs-tools-4.7.5: NON-BOOK source: no 13.1 page; upstream tag 4.7.5 (github), md5 183807a29b969d8e3a1cd27f09fe8179, sha256 547b7b7f4d2e44bf91b6fc554664850c69563701deab9fd9cd7e21f694c88ea6 (TOFU).
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
TB="/sources/blfs-src/squashfs-tools-4.7.5.tar.gz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"

# --- blok 1 ---
# the Makefile hard-sets LZO_SUPPORT = 1 and LZ4_SUPPORT = 1 (plain assignments): set them to 0 in the file
# (no lzo headers; lz4 header absent here). xz and zstd stay on.
sed -i "s/^LZO_SUPPORT = 1/LZO_SUPPORT = 0/; s/^LZ4_SUPPORT = 1/LZ4_SUPPORT = 0/" squashfs-tools/Makefile
make -C squashfs-tools XZ_SUPPORT=1 ZSTD_SUPPORT=1
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root make -C squashfs-tools INSTALL_DIR=/usr/bin install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
cd /sources/blfs-build && rm -rf "$PKG"
