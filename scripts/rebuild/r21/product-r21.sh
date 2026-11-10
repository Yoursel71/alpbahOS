#!/bin/bash
# REBUILD-R21: record the alpbahOS firewall and zram files (product-r21.py) in r4-root and enable both units.
# Run as root on the host. Enablement symlinks are state (no alp record); systemctl runs offline in a chroot.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ST=$SB/r21/stage-product
[ -x "$R4/usr/sbin/iptables-restore" ] || { echo "iptables missing in r4-root"; exit 1; }
[ -x "$R4/usr/sbin/zramctl" ] || { echo "zramctl missing in r4-root"; exit 1; }
rm -rf "$ST"; python3 "$WT/scripts/rebuild/r21/product-r21.py" "$ST"
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-firewall-zram 0.9-r21 "$ST" alpbahos-firewall-zram 0.9-r21
chroot "$R4" /usr/bin/systemctl enable alpbahos-firewall.service alpbahos-zram.service 2>&1 | grep -v 'not mounted\|Proceeding anyway\|mileage'
chroot "$R4" /usr/bin/systemd-analyze verify /usr/lib/systemd/system/alpbahos-firewall.service /usr/lib/systemd/system/alpbahos-zram.service 2>&1 | grep -v 'not mounted\|Proceeding anyway\|mileage' || true
find "$R4/etc/systemd/system" -name 'alpbahos-*' | sed "s|$R4||"
