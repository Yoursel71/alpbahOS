#!/bin/bash
# REBUILD-R4 284 breeze-gtk-6.7.4: one Plasma package per script (option b). Block of the 13.1 plasma-all.html
# per-package loop (cmake with BUILD_QT5=OFF, BUILD_TESTING=OFF); the page builds all in one loop.
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

# --- pycairo-1.28.0 (13.1 book general/python-modules.html, PyCairo): REQUIRED "PythonCairo" of breeze-gtk.
# Not a row of the R4 list (order.txt 279b), built here first from the book commands. Tarball: .files line.
PC=pycairo-1.28.0.tar.gz
[ -f "/sources/blfs-build/$PC" ] || { echo "KAYNAK_YOK $PC"; exit 2; }
cd /sources/blfs-build && PCD=$(tar -tf "$PC" | sed -n 1p | cut -d/ -f1) && rm -rf "$PCD" && tar -xf "$PC" && cd "$PCD"
# --- pycairo blok 1 ---
mkdir build &&
cd    build &&
meson setup --prefix=/usr --buildtype=release .. &&
ninja
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL PC1 rc=$_rc"; exit 1; }
# --- pycairo blok 2 ---
as_root ninja install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL PC2 rc=$_rc"; exit 1; }
cd /sources/blfs-build && rm -rf "$PCD"

# --- breeze-gtk-6.7.4 ---
TB="/sources/blfs-src/breeze-gtk-6.7.4.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
# --- blok 1 ---
mkdir build &&
cd    build &&
cmake -D CMAKE_INSTALL_PREFIX=$KF6_PREFIX \
      -D CMAKE_INSTALL_LIBEXECDIR=libexec \
      -D CMAKE_BUILD_TYPE=Release         \
      -D BUILD_QT5=OFF                    \
      -D BUILD_TESTING=OFF                \
      -W no-author .. &&
make
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root make install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
