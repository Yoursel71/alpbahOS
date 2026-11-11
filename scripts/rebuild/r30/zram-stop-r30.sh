#!/bin/bash
# ZRAM-01 follow-up (round 30): in the round 21 S1 shutdown cycles alpbahos-zram.service failed at every shutdown
# ("swapoff: /dev/zram0: Invalid argument", status=4): systemd's own dev-zram0.swap unit had already turned the swap
# off. The stop branch now treats "no longer an active swap" as done. Record alpbahos-zram-stop-r30 takes
# /usr/libexec/alpbahos/zram-swap over from alpbahos-firewall-zram (REPLACE=1). Source: scripts/rebuild/r21/product-r21.py.
# Run as root on the host.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ST=$SB/r30/stage-zram
rm -rf "$ST" "$SB/r30/product-r21-tree"; mkdir -p "$ST/usr/libexec/alpbahos"
python3 "$WT/scripts/rebuild/r21/product-r21.py" "$SB/r30/product-r21-tree" > /dev/null
install -m 755 "$SB/r30/product-r21-tree/usr/libexec/alpbahos/zram-swap" "$ST/usr/libexec/alpbahos/zram-swap"
sh -n "$ST/usr/libexec/alpbahos/zram-swap"
grep -q 'grep -q "^$DEV " /proc/swaps' "$ST/usr/libexec/alpbahos/zram-swap"
rm -rf "$SB/r30/product-r21-tree"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-zram-stop-r30 0.9-r30 "$ST" \
    alpbahos-zram-stop-r30 0.9-r30
