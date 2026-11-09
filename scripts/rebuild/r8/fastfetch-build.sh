#!/bin/bash
# REBUILD-R8 S2: fastfetch (upstream release 2.71.0; not in BLFS 13.1) built in a chroot of r4-root, generic x86-64.
# Steps: fetch the GitHub tarball (sha256 printed and recorded), copy it into r4-root, cmake + build (generic flags,
# -j16 for C), DESTDIR install into a staging dir, ISA audit of the staged ELF files. Nothing is recorded here:
# the staging dir is recorded by fastfetch-r8rec.py (alp adopt-base). Run as root.
set -euo pipefail
export LC_ALL=C
TAG=${1:-2.71.0}
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
W=$SB/r8/fastfetch
mkdir -p "$W"
TAR=$W/fastfetch-$TAG.tar.gz
[ -s "$TAR" ] || curl -sL --max-time 300 -o "$TAR" "https://api.github.com/repos/fastfetch-cli/fastfetch/tarball/$TAG"
echo "tarball $TAR"
echo "sha256 $(sha256sum "$TAR" | cut -d' ' -f1)"
echo "size $(stat -c %s "$TAR")"
rm -rf "$W/src" && mkdir -p "$W/src" && tar xzf "$TAR" -C "$W/src" --strip-components=1
rm -rf "$R4/tmp/fastfetch-src" "$R4/tmp/fastfetch-stage" && mkdir -p "$R4/tmp/fastfetch-src"
cp -a "$W/src/." "$R4/tmp/fastfetch-src/"
mount --bind /dev "$R4/dev"
mount -t proc proc "$R4/proc"
mount -t sysfs sys "$R4/sys"
mount -t tmpfs tmpfs "$R4/run"
cleanup() {
    umount "$R4/run" "$R4/sys" "$R4/proc" "$R4/dev" 2>/dev/null || true
}
trap cleanup EXIT
chroot "$R4" /usr/bin/env PATH=/usr/bin:/usr/sbin:/bin:/sbin sh -c '
set -e
cd /tmp/fastfetch-src
cmake -S . -B build -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_C_FLAGS="-O2 -march=x86-64 -mtune=generic" -DBUILD_TESTS=OFF > /tmp/fastfetch-cmake.log 2>&1
cmake --build build --parallel 16 > /tmp/fastfetch-build.log 2>&1
DESTDIR=/tmp/fastfetch-stage cmake --install build > /tmp/fastfetch-install.log 2>&1
'
echo "chroot build rc=$?"
cp -a "$R4/tmp/fastfetch-stage" "$W/stage" && rm -rf "$W/stage/.." 2>/dev/null || true
cp "$R4/tmp/fastfetch-cmake.log" "$R4/tmp/fastfetch-build.log" "$R4/tmp/fastfetch-install.log" "$W/" 2>/dev/null || true
rm -rf "$R4/tmp/fastfetch-src" "$R4/tmp/fastfetch-stage"
echo "staged files: $(find "$W/stage" -type f | wc -l)"
find "$W/stage" -type f -print0 | xargs -0 file | grep -c ELF || true
"$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh" "$W/stage" > "$W/audit-isa.txt" 2>&1
echo "audit-isa rc=$?"
