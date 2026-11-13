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
# --- filesystem tools and the udisks/upower stack (BLFS 13.1-systemd unless stated; md5 from the page) ---
P=https://www.linuxfromscratch.org/blfs/view/13.1-systemd
bstep() {  # NAME VER URL TARBALL KIND ROWNN MD5 PAGE [opts...]   (build-pkg-r10.sh kinds: configure|meson|cmake)
    local n=$1 v=$2 u=$3 t=$4 k=$5 nn=$6 m=$7 pg=$8; shift 8
    [ -s "$SB/r10/dl/$t" ] || curl -sL --tlsv1.2 --max-time 600 -o "$SB/r10/dl/$t" "$u"
    [ "$(md5sum < "$SB/r10/dl/$t" | cut -c1-32)" = "$m" ] || { echo "MD5 mismatch: $t"; exit 1; }
    echo "== $n-$v ($(date +%T))"
    bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" "$n" "$v" "$u" "$t" "$k" - "$nn" "R50: BLFS 13.1-systemd $pg: $v, book MD5 $m matches" "$@"
}
w lzo && bstep lzo 2.10 https://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz lzo-2.10.tar.gz configure 467 39d3f3f9c55c87b1e5d6888e1420f4b5 general/lzo.html --enable-shared --disable-static --docdir=/usr/share/doc/lzo-2.10
w cryptsetup && bstep cryptsetup 2.8.7 https://www.kernel.org/pub/linux/utils/cryptsetup/v2.8/cryptsetup-2.8.7.tar.xz cryptsetup-2.8.7.tar.xz configure 468 a9a19068e4db32f77c0ab95c378ab290 postlfs/cryptsetup.html --disable-ssh-token --disable-asciidoc
w btrfs-progs && bstep btrfs-progs v7.1 https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v7.1.tar.xz btrfs-progs-v7.1.tar.xz configure 469 5dbaaf17567022405d6fc9d0d185e812 postlfs/btrfs-progs.html --disable-static --disable-documentation
w ntfs-3g && step ntfs-3g 2026.7.7 https://github.com/tuxera/ntfs-3g/archive/2026.7.7/ntfs-3g-2026.7.7.tar.gz ntfs-3g-2026.7.7.tar.gz 470 254f0eae638ae2f1f0e24f0b76dd1dfc "$A/ntfs-3g.sh"
echo "r50 chain done $(date +%T)"
