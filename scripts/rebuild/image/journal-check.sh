#!/bin/bash
# REBUILD-R2 image phase: offline journal check after a QEMU boot.
# Attaches the image READ-ONLY on a loop device (must be backed by $IMG), mounts the root read-only,
# reads the last boot's journal with journalctl -D, then unmounts and detaches. Runs as root.
#
# Usage: sudo journal-check.sh <run-tag>
set -uo pipefail

TAG=$1
IMG=${BOOT_IMG:-/home/yrslf/alpbahOS/scratch-lfs-bench/images/alpbahos-r2-ch11-2026-11-07.raw}
LOGDIR=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/boot
RUN=$LOGDIR/$TAG
M=/mnt/r2-journal-ro
LOOP=

die() { echo "journal-check: $*" >&2; exit 1; }
assert_loop() {
    [[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] || die "bad loop device '$LOOP'"
    [ "$(losetup -n -O BACK-FILE "$LOOP" 2>/dev/null)" = "$IMG" ] || die "$LOOP is not backed by $IMG"
}
cleanup() {
    set +e
    umount "$M" 2>/dev/null
    if [[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] && [ "$(losetup -n -O BACK-FILE "$LOOP" 2>/dev/null)" = "$IMG" ]; then
        losetup -d "$LOOP"
    fi
}
trap cleanup EXIT

[ "$(id -u)" -eq 0 ] || die "run as root"
[ -d "$RUN" ] || die "no run dir $RUN"
mkdir -p "$M"
LOOP=$(losetup --find --show --read-only --partscan "$IMG")
assert_loop
[ -b "${LOOP}p3" ] || die "no ${LOOP}p3"
[ "$(lsblk -no PKNAME "${LOOP}p3")" = "$(basename "$LOOP")" ] || die "p3 not on $LOOP"
mount -o ro "${LOOP}p3" "$M"

J="$M/var/log/journal"
{
    echo "== boots in journal"
    journalctl -D "$J" --list-boots --no-pager 2>&1 | tail -5
    echo "== journalctl -b -p err (last boot), tail"
    journalctl -D "$J" -b -p err --no-pager 2>&1 | tail -40
    echo "== failed units and job failures (last boot)"
    journalctl -D "$J" -b --no-pager 2>&1 | grep -E 'Failed with result|Failed to start|Job .* failed|FAILED' | tail -40
    echo "== startup finished (last boot)"
    journalctl -D "$J" -b --no-pager 2>&1 | grep -E 'Startup finished' | tail -3
    echo "== network (last boot)"
    journalctl -D "$J" -b --no-pager 2>&1 | grep -E 'DHCPv4|networkd|eth0|enp' | tail -20
} > "$RUN/journal-check.txt" 2>&1
echo "wrote $RUN/journal-check.txt"
tail -n 3 "$RUN/journal-check.txt"
