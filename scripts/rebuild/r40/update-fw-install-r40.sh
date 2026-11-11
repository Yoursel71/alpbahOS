#!/bin/bash
# Round 40: add the FW-DIRLINK-01 firmware directory links (record linux-firmware-dirlinks, firmware-links-r40.sh) to the
# user's real alpbahOS install, so nouveau finds the RTX 5060 (GB206) GSP firmware (user's approval 2026-11-11).
# Usage: update-fw-install-r40.sh <root partition>   e.g. /dev/sda2. Same refusals as update-install-r40.sh (not an
# installed alpbahOS root, no alp database, mounted elsewhere). Writes only the 16 links and the alp database of that
# root. Run as root on the host.
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
cd "$WT"
TARGET_ROOT=$M LEDGER_DIR=$SB/r40/install-ledger-$(basename "$DEV") bash scripts/rebuild/r40/firmware-links-r40.sh
python3 -c 'import json,sys; p=json.load(open(sys.argv[1]))["packages"]["linux-firmware-dirlinks"]; print("alp db:", p["version"], len(p.get("symlinks", [])), "symlinks")' "$M/var/lib/alp/db.json"
sync
echo "update-fw-install-r40 done $(date +%T)"
