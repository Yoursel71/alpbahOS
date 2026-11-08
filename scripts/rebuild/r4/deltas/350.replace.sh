export LANG=C LC_ALL=C
#!/bin/bash
set -eo pipefail
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export KF6_PREFIX=/usr
as_root() { "$@"; }; export -f as_root
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/mesa-26.1.7.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"

# --- blok 1 ---
# Install Mesa by running the following commands:
mkdir build &&
cd    build &&
meson setup ..                 \
      --prefix=$XORG_PREFIX    \
      --buildtype=release      \
      -D platforms=x11,wayland \
      -D gallium-drivers=nouveau,virgl,llvmpipe \
      -D llvm=enabled          \
      -D gallium-rusticl=false \
      -D vulkan-drivers=amd,intel,swrast     \
      -D valgrind=disabled     \
      -D video-codecs=all      \
      -D libunwind=disabled    &&
ninja
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2 ---
# To test the results, issue:
meson configure -D build-tests=true &&
sed '/float rsqrtf/,/^}/d' \
    -i ../src/gallium/drivers/llvmpipe/lp_test_arit.c &&
ninja test
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
# --- blok 3 ---
# Now, as the root user:
ninja install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 3 rc=$_rc"; exit 1; }
