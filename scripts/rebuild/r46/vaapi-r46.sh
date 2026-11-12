#!/bin/bash
# VAAPI-01 (round 46): hardware video decode/encode on Intel GPUs (Broadwell and newer) through VA-API: the image had
# libva but no Intel driver, so video players decoded on the CPU. BLFS 13.1-systemd pages (book MD5 checked by
# fetch-apps01.py): gmmlib 22.10.0 (row 463, built for the x86-64 baseline, chroot/gmmlib.sh) and intel-media-driver
# 26.2.4 (row 464, all GPU generations). Usage: vaapi-r46.sh [gmmlib|imd ...]. Run as root. Env NICE (15), JOBS (12).
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
A=$WT/scripts/rebuild/r46/chroot
SRC=$SB/apps01-src
export NICE=${NICE:-15} JOBS=${JOBS:-12} DROP_SRC=1
link() { local d=$SB/r10/dl/$(basename "$1"); [ -e "$d" ] || ln "$1" "$d"; cmp -s "$1" "$d" || { echo "$d differs"; exit 1; }; }
md5() { [ "$(md5sum < "$1" | cut -c1-32)" = "$2" ] || { echo "MD5 mismatch: $1"; exit 1; }; }
ARGS=("$@")
w() { [ ${#ARGS[@]} -eq 0 ] && return 0; local x; for x in "${ARGS[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
step() {  # NAME VER URL TARBALL NN NOTE SCRIPT
    local n=$1 v=$2 u=$3 t=$4 nn=$5 note=$6 s=$7
    link "$t"; echo "== $n-$v ($(date +%T))"
    EXTRA_FILES="$s" CUSTOM_CMD="sh ../$(basename "$s")" \
      bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" "$n" "$v" "$u" "$(basename "$t")" custom - "$nn" "$note"
    grep -E 'unallowed' "$SB/r10/$n/audit-isa.txt" | tail -1
}
if w gmmlib; then
  T=$SRC/gmmlib-22.10.0.tar.gz; md5 "$T" f94f6903e7df944c7a064f85b1b4a99b
  step gmmlib 22.10.0 https://github.com/lfs-book/gmmlib/archive/v22.10.0/gmmlib-22.10.0.tar.gz "$T" 463 \
    "VAAPI-01: BLFS 13.1-systemd general/gmmlib.html 22.10.0, book MD5 f94f6903e7df944c7a064f85b1b4a99b matches; x86-64 baseline (corei7/SSE4.2 flags removed)" "$A/gmmlib.sh"
fi
if w imd; then
  T=$SRC/intel-media-driver-26.2.4.tar.gz; md5 "$T" 507c81a204cbb38da19ac915ec16a618
  step intel-media-driver 26.2.4 https://github.com/lfs-book/intel-media-driver/archive/v26.2.4/intel-media-driver-26.2.4.tar.gz "$T" 464 \
    "VAAPI-01: BLFS 13.1-systemd multimedia/intel-media-driver.html 26.2.4, book MD5 507c81a204cbb38da19ac915ec16a618 matches; all GPU generations" "$A/intel-media-driver.sh"
fi
echo "vaapi done $(date +%T)"
