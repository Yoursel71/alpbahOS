#!/bin/bash
# REBUILD-R20 (NET-FW-01): linux-firmware as an alp record in r4-root. Run as root on the host.
# Source: https://cdn.kernel.org/pub/linux/kernel/firmware/linux-firmware-20261019.tar.xz
#   sha256 pinned below; it is the value in kernel.org sha256sums.asc, whose signature was checked on the host
#   (Kernel.org checksum autosigner, key B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1, fetched by WKD).
# Install: the package's own copy-firmware.sh with --zstd (kernel has FW_LOADER_COMPRESS_ZSTD=y), run in a chroot of
#   r4-root (its zstd), serial (-j1: GNU parallel is not in r4-root). No dedup step (dedup-firmware.sh needs rdfind,
#   which is not in r4-root); copy-firmware.sh already writes the WHENCE links as symlinks.
# Record: stage -> stage-record-r8.py via apply-r7.sh (name linux-firmware, version 20261019).
# Usage: firmware-r20.sh <tarball>
set -euo pipefail
export LC_ALL=C
TAR=$1
PIN=a10d1ab5baf2c74ba92e8c7cf313e691696c26bddfa6df00db795e48d70cd4ca
VER=20261019
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
W=$SB/r10/linux-firmware
[ -d "$R4/usr/lib" ] || { echo "r4-root missing"; exit 1; }
echo "$PIN  $TAR" | sha256sum -c - || { echo "sha256 mismatch"; exit 1; }
[ ! -e "$R4/usr/lib/firmware/WHENCE" ] || { echo "linux-firmware already in r4-root"; exit 1; }

BLD=/tmp/build-linux-firmware
STG=/tmp/stage-linux-firmware
rm -rf "$W" "$R4$BLD" "$R4$STG"
mkdir -p "$W" "$R4$BLD"
tar xf "$TAR" -C "$R4$BLD" --strip-components=1
mount --bind /dev "$R4/dev"; mount -t proc proc "$R4/proc"
cleanup() { umount "$R4/proc" "$R4/dev" 2>/dev/null || true; rm -rf "$R4$BLD" "$R4$STG"; }
trap cleanup EXIT
set +e
chroot "$R4" /usr/bin/env PATH=/usr/bin:/usr/sbin sh -c \
    "set -e; cd $BLD && ./copy-firmware.sh -j1 --zstd $STG/usr/lib/firmware && install -m 644 WHENCE $STG/usr/lib/firmware/WHENCE" \
    > "$W/build.log" 2>&1
RC=$?
set -e
echo "copy-firmware rc=$RC (log $W/build.log)"
[ "$RC" = 0 ] || exit 1
# License files go next to the firmware (LICENCE.*, LICENSE.*), as most distributions do.
for f in "$R4$BLD"/LICENCE.* "$R4$BLD"/LICENSE.*; do [ -f "$f" ] && install -m 644 "$f" "$R4$STG/usr/share/licenses/linux-firmware/$(basename "$f")" -D; done
rm -rf "$W/stage" && cp -a "$R4$STG" "$W/stage"
echo "staged: files $(find "$W/stage" -type f | wc -l) symlinks $(find "$W/stage" -type l | wc -l) size $(du -sb "$W/stage" | cut -f1)"
# ISA audit: only x86-64 ELF objects are relevant (firmware blobs for other CPUs are not run by the host CPU).
X86=$(find "$W/stage" -type f -exec file {} + 2>/dev/null | grep -c 'ELF 64-bit LSB.*x86-64' || true)
echo "x86-64 ELF files in the stage: $X86"
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh "$WT/scripts/rebuild/r8/stage-record-r8.py" linux-firmware "$VER" "$W/stage" linux-firmware "$VER"
du -sh "$R4/usr/lib/firmware"
