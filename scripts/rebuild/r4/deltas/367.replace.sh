#!/bin/bash
# REBUILD-R4 367 yaml-cpp-0.9.0 (NOT a book package: github.com/jbeder/yaml-cpp release tag; TOFU sha256, see docs/verification/iso-beta-2026-11-08.md). Calamares needs it.
export LANG=C LC_ALL=C
set -eo pipefail
as_root() { "$@"; }; export -f as_root
export QT6DIR=/opt/qt6
export PATH=/opt/qt6/bin:$PATH
export PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:${PKG_CONFIG_PATH:-}
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/yaml-cpp-0.9.0.tar.gz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
# --- blok 1 ---
cmake -S . -B build -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release \
      -D BUILD_SHARED_LIBS=ON \
      -D YAML_BUILD_SHARED_LIBS=ON \
      -D YAML_CPP_BUILD_TESTS=OFF \
      -D YAML_CPP_BUILD_TOOLS=OFF \
      -D YAML_CPP_BUILD_CONTRIB=OFF \
      -W no-dev &&
cmake --build build
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
as_root cmake --install build
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
cd /sources/blfs-build && rm -rf "$PKG"
