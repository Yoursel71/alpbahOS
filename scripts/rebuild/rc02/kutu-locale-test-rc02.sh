#!/bin/bash
# KUTU hypothesis test (BETA-RC-02): same KUTU steps on a test copy of the rc02 UEFI install whose /etc/locale.conf
# says LANG=tr_TR.UTF-8 instead of the installed tr_TR.utf8 (distrobox-init's Debian path uncomments the host
# locale in locale.gen with a case-sensitive sed, so tr_TR.utf8 never matches "# tr_TR.UTF-8 UTF-8"). Test copy only.
cd /home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/rc02/matrix || exit 1
. /home/yrslf/alpbahOS/wt-rc02/scripts/rebuild/rc02/env-rc02.sh; RBD=$MATRIX_WT/scripts/rebuild; MM=$M; MATRIX_LIB=1 . "$MM"
gs() { python3 "$RBD/r21/gsh.py" "$D/KUTU2" "$@"; }
gate 20 || exit 1
bash "$MM" mkcopy uefi KUTU2-disk
LO=$(sudo losetup -f -P --show "$D/KUTU2-disk.raw"); P=$(rootpart "$LO"); MT=$(mktemp -d /tmp/rc02-k2.XXXX)
sudo mount "$P" "$MT" && { echo "installed locale.conf: $(sudo cat "$MT/etc/locale.conf" | tr '\n' ' ')"; sudo sed -i 's/\.utf8/.UTF-8/g' "$MT/etc/locale.conf"; echo "test copy locale.conf: $(sudo cat "$MT/etc/locale.conf" | tr '\n' ' ')"; sudo install -m 600 "$DIAG_PWF" "$MT/root/.kutu-pw"; sudo umount "$MT"; }
sudo losetup -d "$LO"; rmdir "$MT"
agent_start KUTU2 uefi KUTU2-disk virtio 6G; greeter_login "$D/KUTU2" kutu2
gs 30 "echo $(base64 -w0 < "$RBD/rc02/kutu-guest-rc02.sh") | base64 -d > /root/kutu.sh && echo staged; cat /etc/locale.conf"
for p in pre create sudo plain end; do gs 1500 "bash /root/kutu.sh $p" > "KUTU2-$p.txt" 2>&1; done
cat KUTU2-*.txt; shot "$D/KUTU2" kutu2-end; vmquit "$D/KUTU2" && rm -f "$D/KUTU2-disk.raw"
echo KUTU2-DONE
