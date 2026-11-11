#!/bin/bash
# Round 40: apply the PIXBUF-01 records (gdk-pixbuf-loaders, gdk-pixbuf-builtin; stages from pixbuf-loaders-r40.sh) to
# the user's real alpbahOS install, with the same alp records as r4-root (user's choice 2026-11-11: "Kurulu sistemi
# güncelle"). Usage: update-install-r40.sh <root partition>   e.g. /dev/sda2. Refuses anything that is not an
# installed alpbahOS root (os-release ID=alpbahos, an alp database, not mounted elsewhere). Writes only the records'
# files and the alp database of that root. Run as root on the host.
set -euo pipefail
export LC_ALL=C
DEV=$1
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
M=/mnt/alpbahos-install-r40
[ -b "$DEV" ] || { echo "not a block device: $DEV"; exit 2; }
findmnt -rn -S "$DEV" > /dev/null && { echo "$DEV is mounted already"; exit 2; }
[ "$(lsblk -no FSTYPE "$DEV")" = ext4 ] || { echo "$DEV is not ext4"; exit 2; }
mkdir -p "$M"
mount "$DEV" "$M"
trap 'umount "$M" 2>/dev/null; rmdir "$M" 2>/dev/null' EXIT
grep -qx 'ID=alpbahos' "$M/etc/os-release" || { echo "not an alpbahOS root"; exit 2; }
[ -f "$M/var/lib/alp/db.json" ] || { echo "no alp database"; exit 2; }
L=$SB/r40/install-ledger-$(basename "$DEV")
cd "$WT"
for rec in "gdk-pixbuf-loaders:$SB/r40/stage-pixbuf" "gdk-pixbuf-builtin:$SB/r40/stage-pixbuf-lib"; do
    name=${rec%%:*}; st=${rec#*:}
    TARGET_ROOT=$M LEDGER_DIR=$L REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py \
        "$name" 2.44.7-alpbahos1 "$st" "$name" 2.44.7-alpbahos1
done
echo "png/jpeg in the installed library: $(strings "$M/usr/lib/libgdk_pixbuf-2.0.so.0.4400.7" | grep -cxE 'image/(png|jpeg)')"
echo "loaders in the installed cache: $(grep -c '^"/usr/lib/gdk-pixbuf' "$M/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache")"
sync
echo "update-install-r40 done $(date +%T)"
