#!/bin/bash
# GRUB-THEME-01 (D1): record font-inter 4.1, font-jetbrains-mono 2.304 and alpbahos-grub-theme 0.9-d1 in r4-root
# (alp adopt-base through apply-r7.sh), then refresh the fontconfig cache in a chroot (cache = state, no record).
# Run as root on the host. The staging (product-d1.py) runs as the build user.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ST=$SB/d1/stage-product
[ -d "$R4/usr/lib/grub/i386-pc" ] || { echo "GRUB missing in r4-root"; exit 1; }
[ ! -e "$R4/boot/grub/themes/alpbahos" ] || { echo "theme already in r4-root"; exit 1; }
rm -rf "$ST"; mkdir -p "$(dirname "$ST")"
chown yrslf: "$(dirname "$ST")"
sudo -u yrslf python3 "$WT/scripts/rebuild/d1/product-d1.py" "$R4" "$SB/d-fonts/src" "$ST"
chown -R root:root "$ST"
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py font-inter 4.1 "$ST/font-inter" font-inter 4.1
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py font-jetbrains-mono 2.304 \
    "$ST/font-jetbrains-mono" font-jetbrains-mono 2.304
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-grub-theme 0.9-d1 \
    "$ST/alpbahos-grub-theme" alpbahos-grub-theme 0.9-d1
chroot "$R4" /usr/bin/fc-cache -s > /dev/null
chroot "$R4" /usr/bin/fc-list : family | grep -E '^(Inter|JetBrains Mono)' | sort -u
ls -l "$R4/boot/grub/themes/alpbahos/theme.txt"
grep -n 'Beta' "$R4/boot/grub/themes/alpbahos/theme.txt"
