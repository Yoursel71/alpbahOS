#!/bin/bash
# Round 41 (MESA-01, D134; prerequisite of NVIDIA-PKG-01): the image's Mesa had only the nouveau, virgl and llvmpipe
# gallium drivers (scripts/rebuild/r4/deltas/350.replace.sh), so Intel and AMD GPUs got no 3D acceleration, and it was
# built without libglvnd, which NVIDIA's OpenGL libraries need. Two records, both taking files over (REPLACE=1,
# KEEP_SHARED=0):
#   libglvnd 1.7.0 (row 433; not in BLFS 13.1): upstream tag archive, sha256 2b6e15b0... equals Void's template and
#     its sha512 equals Arch's PKGBUILD (the release page tarball matched neither and is not used).
#   mesa-glvnd 26.1.7 (row 434): BLFS 13.1 mesa-26.1.7 (book MD5 1a3ea044... checked) with glvnd and the drivers for
#     Intel (iris, crocus; Vulkan anv, hasvk), AMD (radeonsi, r600, r300; Vulkan radv), NVIDIA open (nouveau), zink,
#     virgl, llvmpipe/softpipe; Vulkan lavapipe. No NVK (needs Rust) and no 32-bit Mesa yet (STEAM-01).
# A read-only snapshot of r4-root is taken first (r4-snapshots/r4-before-gpu-r41). Run as root.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
SRC=$SB/apps01-src/gpu
export NICE=${NICE:-10} JOBS=${JOBS:-14}
cd "$WT"
mkdir -p "$SB/r4-snapshots" "$SB/r10/dl"
[ -e "$SB/r4-snapshots/r4-before-gpu-r41" ] || btrfs subvolume snapshot -r "$SB/r4-root" "$SB/r4-snapshots/r4-before-gpu-r41"
T=libglvnd-v1.7.0.tar.gz
[ "$(sha256sum < "$SRC/$T" | cut -c1-64)" = 2b6e15b06aafb4c0b6e2348124808cbd9b291c647299eaaba2e3202f51ff2f3d ] || { echo "sha256 mismatch: $T"; exit 1; }
[ -e "$SB/r10/dl/$T" ] || ln "$SRC/$T" "$SB/r10/dl/$T"
KEEP_SHARED=0 REPLACE=1 bash scripts/rebuild/r11/pkg-url-r11.sh libglvnd 1.7.0 \
    https://gitlab.freedesktop.org/glvnd/libglvnd/-/archive/v1.7.0/libglvnd-v1.7.0.tar.gz "$T" meson - 433 \
    "MESA-01: upstream tag v1.7.0 archive (not in BLFS 13.1); sha256 2b6e15b0... = Void template, sha512 = Arch PKGBUILD" \
    -Dx11=enabled -Dglx=enabled -Degl=true -Dgles1=true -Dgles2=true
M=mesa-26.1.7.tar.xz
[ "$(md5sum < "$SB/blfs-src-13.1/$M" | cut -c1-32)" = 1a3ea044abc823e2db8c6041e5adcc4f ] || { echo "MD5 mismatch: $M"; exit 1; }
[ -e "$SB/r10/dl/$M" ] || ln "$SB/blfs-src-13.1/$M" "$SB/r10/dl/$M"
KEEP_SHARED=0 REPLACE=1 bash scripts/rebuild/r11/pkg-url-r11.sh mesa-glvnd 26.1.7 \
    https://mesa.freedesktop.org/archive/mesa-26.1.7.tar.xz "$M" meson - 434 \
    "MESA-01: BLFS 13.1-systemd x/mesa.html 26.1.7, book MD5 1a3ea044... matches; glvnd and the Intel/AMD/NVIDIA open drivers" \
    -D platforms=x11,wayland \
    -D gallium-drivers=radeonsi,r300,r600,iris,crocus,nouveau,virgl,llvmpipe,softpipe,zink \
    -D vulkan-drivers=amd,intel,intel_hasvk,swrast -D llvm=enabled -D gallium-rusticl=false -D valgrind=disabled \
    -D video-codecs=all -D libunwind=disabled -D glvnd=enabled
echo "gpu-r41 done $(date +%T)"
