#!/bin/bash
# Round 23: record alpbahos-name 0.9-r23 (NAME-CASE-01) and alpbahos-grub-config 0.9-r23 (GRUB-TITLES-01, D157) in
# r4-root. Both take their files over from the records that own them (REPLACE=1, alp transfer). Run as root on the
# host; the staging (product-r23.py) runs as the build user. A test grub-mkconfig in the chroot is not possible
# here (no /boot device); the titles are checked on the installed disks.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ST=$SB/r23/stage-product
rm -rf "$ST"; mkdir -p "$(dirname "$ST")"; chown yrslf: "$(dirname "$ST")"
sudo -u yrslf python3 "$WT/scripts/rebuild/r23/product-r23.py" "$R4" "$ST"
chown -R root:root "$ST"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-name 0.9-r23 \
    "$ST/alpbahos-name" alpbahos-name 0.9-r23
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-grub-config 0.9-r23 \
    "$ST/alpbahos-grub-config" alpbahos-grub-config 0.9-r23
grep -H 'NAME=' "$R4/etc/os-release"
grep -n 'alpbahos_first_title\|OS="${GRUB_DISTRIBUTOR}"' "$R4/etc/grub.d/10_linux"
grep -n '^LABEL=' "$R4/etc/grub.d/30_uefi-firmware"
bash -n "$R4/etc/grub.d/10_linux" && bash -n "$R4/etc/grub.d/30_uefi-firmware" && echo "syntax ok"
