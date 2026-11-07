#!/bin/bash
# REBUILD-R4 123: LLVM 22.1.8 per the BLFS 13.1-systemd page llvm.html (monorepo layout: clang and
# compiler-rt are inside llvm-project, no extra tarballs). Replaces the generator's 12.4-derived script.
# Generic x86-64: no -march/-mtune; the chroot environment has no CFLAGS/CXXFLAGS.
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/llvm-project-22.1.8.src.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"

# --- blok 1 --- upstream fix patch (book: llvm-22.1.8-upstream_fix-1.patch, copied to /sources/blfs-build)
patch -Np1 -i ../llvm-22.1.8-upstream_fix-1.patch
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 --- python scripts use python3
grep -rl '#!.*python$' | xargs sed -i '1s/python$/python3/'
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
# --- blok 3 --- FileCheck is installed (test suites of other packages need it)
sed 's/utility/tool/' -i llvm/utils/FileCheck/CMakeLists.txt
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 3 rc=$_rc"; exit 1; }
# --- blok 4 --- root: SSP on by default for clang, clang++ (book, before the build: compiler-rt uses clang)
mkdir -pv /etc/clang &&
for i in clang clang++; do
  echo -fstack-protector-strong > /etc/clang/$i.cfg
done
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 4 rc=$_rc"; exit 1; }
# --- blok 5 --- configure and build (book options, -W no-author)
mkdir -v llvm/build &&
cd       llvm/build &&
CC=gcc CXX=g++                               \
cmake -D CMAKE_INSTALL_PREFIX=/usr           \
      -D CMAKE_SKIP_INSTALL_RPATH=ON         \
      -D LLVM_ENABLE_FFI=ON                  \
      -D CMAKE_BUILD_TYPE=Release            \
      -D LLVM_BUILD_LLVM_DYLIB=ON            \
      -D LLVM_LINK_LLVM_DYLIB=ON             \
      -D LLVM_ENABLE_RTTI=ON                 \
      -D LLVM_TARGETS_TO_BUILD="host;AMDGPU" \
      -D LLVM_ENABLE_PROJECTS=clang          \
      -D LLVM_ENABLE_RUNTIMES=compiler-rt    \
      -D LLVM_BINUTILS_INCDIR=/usr/include   \
      -D LLVM_INCLUDE_BENCHMARKS=OFF         \
      -D CLANG_DEFAULT_PIE_ON_LINUX=ON       \
      -D CLANG_CONFIG_FILE_SYSTEM_DIR=/etc/clang \
      -W no-author -G Ninja ..               &&
ninja
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 5 rc=$_rc"; exit 1; }
# --- blok 6 --- install (root)
ninja install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 6 rc=$_rc"; exit 1; }
echo "BLFS-123 llvm-22.1.8 installed"
