#!/bin/bash
# Round 50 package chain (one alp record per step through pkg-url-r11.sh). Run as root, single writer on r4-root, snapshot
# r4-snapshots/r4-before-r50b taken first (`r50-chain.sh snapshot`). Usage: r50-chain.sh [snapshot|NAME ...]
# Steps (MirazParted first: it is the biggest visible gap of the real-PC day):
#   mirazparted   partitionmanager 26.08.3 (KDE Gear, matches the installed kpmcore 26.08.3), shown as MirazParted
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
A=$WT/scripts/rebuild/r50/chroot
export NICE=${NICE:-15} JOBS=${JOBS:-10}
mkdir -p "$SB/r10/dl"
ARGS=("$@")
w() { [ ${#ARGS[@]} -eq 0 ] && return 0; local x; for x in "${ARGS[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
if [ "${1:-}" = snapshot ]; then
  [ ! -e "$SB/r4-snapshots/r4-before-r50b" ] || { echo "snapshot exists"; exit 1; }
  btrfs subvolume snapshot -r "$SB/r4-root" "$SB/r4-snapshots/r4-before-r50b" > /dev/null; echo "snapshot r4-before-r50b"; exit 0
fi
step() {  # NAME VER URL TARBALL ROWNN MD5 SCRIPT [EXTRA FILES...]
    local n=$1 v=$2 u=$3 t=$4 nn=$5 m=$6 s=$7; shift 7
    [ -s "$SB/r10/dl/$t" ] || curl -sL --tlsv1.2 --max-time 600 -o "$SB/r10/dl/$t" "$u"
    [ "$(md5sum < "$SB/r10/dl/$t" | cut -c1-32)" = "$m" ] || { echo "MD5 mismatch: $t"; exit 1; }
    echo "== $n-$v ($(date +%T))"
    EXTRA_FILES="$s $*" CUSTOM_CMD="sh ../$(basename "$s")" \
      bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" "$n" "$v" "$u" "$t" custom - "$nn" "R50: $v, md5 $m (TOFU, first fetch 2026-11-13)"
}
K=https://download.kde.org/stable/release-service/26.08.3/src
w mirazparted && step mirazparted 26.08.3 $K/partitionmanager-26.08.3.tar.xz partitionmanager-26.08.3.tar.xz 466 4d011ca37c2bc8d42c4a23b795a90250 "$A/mirazparted.sh" "$WT/branding/icons/mirazparted.svg"
echo "r50 chain done $(date +%T)"
