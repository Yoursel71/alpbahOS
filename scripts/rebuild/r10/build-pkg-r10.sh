#!/bin/bash
# REBUILD-R10 generic builder for the Flatpak chain (one package per call), in a chroot of r4-root, generic x86-64.
# Usage: build-pkg-r10.sh <NAME> <VERSION> <TARBALL> <KIND: meson|cmake|configure> <SRC_DIR_IN_TARBALL_OR_-> [OPTIONS...]
# Steps: unpack TARBALL (its sha256 is printed), copy into r4-root/tmp, build (-j16 for C, meson/ninja or cmake or
# configure/make), DESTDIR install into a staging dir, copy the staging dir to SB/r10/<NAME>/stage, ISA audit of the
# staged ELF files (audit-isa.sh), and the build logs. Nothing is recorded here: record with stage-record-r8.py
# (apply-r7.sh). Run as root.
set -euo pipefail
export LC_ALL=C
NAME=$1; VER=$2; TAR=$3; KIND=$4; SRCDIR=$5; shift 5
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
W=$SB/r10/$NAME
rm -rf "$W" && mkdir -p "$W/src"
echo "tarball $TAR sha256 $(sha256sum "$TAR" | cut -d' ' -f1) size $(stat -c %s "$TAR")"
tar xf "$TAR" -C "$W/src"
if [ "$SRCDIR" = "-" ]; then SRC=$(find "$W/src" -mindepth 1 -maxdepth 1 -type d | head -1); else SRC="$W/src/$SRCDIR"; fi
[ -d "$SRC" ] || { echo "no source dir $SRC"; exit 1; }
BLD=/tmp/build-$NAME
rm -rf "$R4$BLD" "$R4/tmp/stage-$NAME" && mkdir -p "$R4$BLD"
cp -a "$SRC/." "$R4$BLD/"
OPTS="$*"
mount --bind /dev "$R4/dev"; mount -t proc proc "$R4/proc"; mount -t sysfs sys "$R4/sys"; mount -t tmpfs tmpfs "$R4/run"
cleanup() { umount "$R4/run" "$R4/sys" "$R4/proc" "$R4/dev" 2>/dev/null || true; }
trap cleanup EXIT
case "$KIND" in
meson)
  CMD="cd $BLD && meson setup build --prefix=/usr --buildtype=release -Db_lto=false $OPTS && ninja -C build -j16 && DESTDIR=/tmp/stage-$NAME ninja -C build install" ;;
cmake)
  CMD="cd $BLD && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_C_FLAGS='-O2 -march=x86-64 -mtune=generic' $OPTS && cmake --build build --parallel 16 && DESTDIR=/tmp/stage-$NAME cmake --install build" ;;
configure)
  CMD="cd $BLD && ./configure --prefix=/usr CFLAGS='-O2 -march=x86-64 -mtune=generic' $OPTS && make -j16 && make DESTDIR=/tmp/stage-$NAME install" ;;
*) echo "bad kind"; exit 2 ;;
esac
set +e
chroot "$R4" /usr/bin/env PATH=/usr/bin:/usr/sbin:/bin:/sbin sh -c "set -e; $CMD" > "$W/build.log" 2>&1
RC=$?
set -e
echo "chroot build rc=$RC (log $W/build.log)"
[ "$RC" = 0 ] || exit 1
rm -rf "$W/stage" && cp -a "$R4/tmp/stage-$NAME" "$W/stage"
rm -rf "$R4$BLD" "$R4/tmp/stage-$NAME"
echo "staged files: $(find "$W/stage" -type f -o -type l | wc -l)"
ELF=$(find "$W/stage" -type f -print0 | xargs -0 file | grep -c ELF || true)
echo "elf files: $ELF"
set +e
"$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh" "$W/stage" > "$W/audit-isa.txt" 2>&1
echo "audit-isa rc=$?"
