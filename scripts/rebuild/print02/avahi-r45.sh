#!/bin/bash
# PRINT-01 (round 45): Avahi 0.9-rc5 again WITHOUT the BLFS ipv6_race_condition_fix-1 patch (see chroot/avahi.sh), as
# record avahi-r45 taking the files of record avahi over (KEEP_SHARED=0 REPLACE=1, like cups-dnssd). Same book MD5
# check and options. Run as root on the host. Env NICE (default 15), JOBS (10).
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
SRC=$SB/apps01-src
T=$SRC/avahi-0.9-rc5.tar.gz
export NICE=${NICE:-15} JOBS=${JOBS:-10} DROP_SRC=1
[ "$(md5sum < "$T" | cut -c1-32)" = d2b4bd13a4dba40a7b56c3da8bf50fd2 ] || { echo "MD5 mismatch: $T"; exit 1; }
cmp -s "$T" "$SB/r10/dl/avahi-0.9-rc5.tar.gz" || { echo "r10/dl copy differs"; exit 1; }
export KEEP_SHARED=0 REPLACE=1
EXTRA_FILES="$WT/scripts/rebuild/print02/chroot/avahi.sh" CUSTOM_CMD="sh ../avahi.sh" \
  bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" avahi-r45 0.9-rc5 https://github.com/lathiat/avahi/archive/v0.9-rc5/avahi-0.9-rc5.tar.gz \
    avahi-0.9-rc5.tar.gz custom - 462 \
    "PRINT-01 round 45: BLFS 13.1-systemd basicnet/avahi.html 0.9-rc5, book MD5 d2b4bd13a4dba40a7b56c3da8bf50fd2 matches; without the book's ipv6_race_condition_fix-1 patch (hides own services)"
grep -q 'patch' "$SB/r10/avahi-r45/build.log" && grep -n 'ipv6_race' "$SB/r10/avahi-r45/build.log" && { echo "patch was applied"; exit 1; }
echo "avahi-r45 done $(date +%T)"
