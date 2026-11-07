#!/bin/bash
# REBUILD-R3: run `alp list` and `alp check` inside the image's chroot. The image is attached
# read-only (losetup -r) and its root is mounted read-only; /run is a tmpfs that holds the catalog
# index (demo/index.json), so nothing on the image changes.
# Usage: sudo image-alp-check.sh IMG INDEX OUTDIR   (OUTDIR receives list.txt and check.txt)
set -uo pipefail
IMG=$1
INDEX=$2
OUTDIR=$3
M=/mnt/r3-alpcheck
LOOP=

die() { echo "image-alp-check: $*" >&2; exit 1; }
cleanup() {
    set +e
    umount "$M/run" 2>/dev/null
    umount "$M" 2>/dev/null
    if [[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]]; then
        losetup -d "$LOOP" 2>/dev/null
    fi
}
trap cleanup EXIT

[ "$(id -u)" -eq 0 ] || die "run as root"
[ -f "$IMG" ] || die "no image $IMG"
[ -f "$INDEX" ] || die "no index $INDEX"
mkdir -p "$M"
LOOP=$(losetup -fP --show -r "$IMG") || die "losetup failed"
mount -o ro "${LOOP}p3" "$M" || die "mount root failed"
mount -t tmpfs -o size=16m tmpfs "$M/run" || die "tmpfs on /run failed"
cp "$INDEX" "$M/run/alp-index.json"

echo "== alp list (in the image chroot)"
chroot "$M" /usr/bin/alp --index /run/alp-index.json list > "$M/run/list.txt" 2>&1
echo "list rc=$?"
echo "lfs-base records: $(grep -c 'lfs-base' "$M/run/list.txt")"
echo "alp list output (last lines):"
tail -n 3 "$M/run/list.txt"

echo "== alp check (in the image chroot)"
chroot "$M" /usr/bin/alp --index /run/alp-index.json check > "$M/run/check.txt" 2>&1
echo "check rc=$?"
head -n 20 "$M/run/check.txt"
mkdir -p "$OUTDIR"
cp "$M/run/list.txt" "$M/run/check.txt" "$OUTDIR/"
echo "IMAGE_ALP_CHECK_DONE"
