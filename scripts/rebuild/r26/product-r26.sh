#!/bin/bash
# Round 26: record alpbahos-grub-config-r26 and alpbahos-desktop-profile-r26 (product-r26.py) in r4-root, refresh the
# fontconfig cache, and check that grub-mkconfig still runs is left to the installs. Run as root on the host.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ST=$SB/r26/stage
rm -rf "$ST"; mkdir -p "$SB/r26"; chown yrslf: "$SB/r26"
sudo -u yrslf python3 "$WT/scripts/rebuild/r26/product-r26.py" "$R4" "$ST"
chown -R root:root "$ST"
bash -n "$ST/grub/etc/grub.d/10_linux"; sh -n "$ST/grub/etc/grub.d/06_alpbahos"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-grub-config-r26 0.9-r26 \
    "$ST/grub" alpbahos-grub-config-r26 0.9-r26
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-desktop-profile-r26 0.9-r26 \
    "$ST/profile" alpbahos-desktop-profile-r26 0.9-r26
chroot "$R4" /usr/bin/fc-cache -s > /dev/null
chroot "$R4" /usr/bin/fc-match sans-serif; chroot "$R4" /usr/bin/fc-match monospace
grep -c "echo	'" "$R4/etc/grub.d/10_linux" || true
