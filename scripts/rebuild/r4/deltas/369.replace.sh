#!/bin/bash
# REBUILD-R4 369 calamares-3.3.14 (NOT a book package: github.com/calamares/calamares release tag v3.3.14, TOFU sha256;
# the newest 3.3.x stable release). Options: Qt6 (WITH_QT6), bundled pybind11 instead of Boost.Python (the default
# WITH_PYBIND11=ON; so boost-python is not needed), Python modules and QML on, schema tests off (they need the
# python yaml-schema package, which R4 does not have), no default config (INSTALL_CONFIG=OFF: the live image ships
# its own /etc/calamares). Jobs: the driver's R4_JOBS (8 for this C++ row).
export LANG=C LC_ALL=C
set -eo pipefail
as_root() { "$@"; }; export -f as_root
export QT6DIR=/opt/qt6
export PATH=/opt/qt6/bin:$PATH
export PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:${PKG_CONFIG_PATH:-}
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/calamares-3.3.14.tar.gz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
# --- blok 1 ---
cmake -S . -B build -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_INSTALL_SYSCONFDIR=/etc \
      -D CMAKE_BUILD_TYPE=Release \
      -D "CMAKE_PREFIX_PATH=/opt/qt6;/usr" \
      -D WITH_QT6=ON \
      -D WITH_PYBIND11=ON \
      -D WITH_PYTHON=ON \
      -D WITH_QML=ON \
      -D BUILD_SCHEMA_TESTING=OFF \
      -D BUILD_TESTING=OFF \
      -D INSTALL_POLKIT=ON \
      -D INSTALL_CONFIG=OFF \
      -D INSTALL_COMPLETION=OFF \
      -W no-dev &&
cmake --build build
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root cmake --install build
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
cd /sources/blfs-build && rm -rf "$PKG"
