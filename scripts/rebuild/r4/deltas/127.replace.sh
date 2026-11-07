#!/bin/bash
# REBUILD-R4 127: libclc per the BLFS 13.1-systemd page libclc.html (libclc lives in the llvm-project tree:
# the build directory is libclc/build, not build/). Replaces the generator's 12.4-derived script.
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/llvm-project-22.1.8.src.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"

# --- blok 1 --- configure and build libclc (book commands)
mkdir libclc/build &&
cd    libclc/build &&
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -G Ninja ..                  &&
ninja
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 --- install (root)
ninja install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
echo "BLFS-127 libclc installed"
