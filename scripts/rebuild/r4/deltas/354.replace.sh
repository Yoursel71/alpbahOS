#!/bin/bash
# REBUILD-R4 354 corrosion: prerequisite-group row appended after 344 (dependency order is by execution:
# the driver runs 345-357 before the 289-344 retries). Commands from the 13.1 book page; see the note section 9.
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
export PATH=/opt/rustc/bin:$PATH   # rustc from row 361 (corrosion needs it)
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/corrosion-0.6.1.tar.gz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"

# --- blok 1 ---
mkdir build &&
cd    build &&
cmake -D CMAKE_INSTALL_PREFIX=/usr    \
      -D CMAKE_BUILD_TYPE=Release     \
      -D CMAKE_INSTALL_LIBEXECDIR=lib \
      -D CORROSION_BUILD_TESTS=OFF    \
      -W no-author ..                 &&
make
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root make install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
cd /sources/blfs-build && rm -rf "$PKG"
