#!/bin/bash
# INSTALL-DUALBOOT-01 / D161 (round 27): does the installed system's GRUB list Windows through os-prober?
# Test instrumentation on a reflink COPY of an installed UEFI image only (the copy is deleted at the end):
#   1. host: in the copy's ESP put EFI/Microsoft/Boot/bootmgfw.efi (a stand-in file, as on a PC where Windows shares the
#      ESP); in the copy's root a one-shot unit runs grub-mkconfig inside the guest and powers off. os-prober runs in
#      the guest, so it only sees the virtual disk (never the host's disks).
#   2. boot the copy (KVM) until it powers off; read /root/r27-grub-mkconfig.log and the menu entries (host, read-only).
#   3. remove the unit, boot the copy again and take screenshots of the GRUB menu (no key pressed).
# Runs as the build user; sudo for the loop mounts of the copy. Usage: dualboot-r27.sh <installed-uefi-raw> <run-name>
set -euo pipefail
SRC=$1; NAME=$2
B=/home/yrslf/alpbahOS/scratch-lfs-bench
W=/home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/image
D=$B/lfs13-logs/iso-beta-0.9/${ROUND:-r27}
R=$D/$NAME; CP=$D/$NAME-copy.raw; M=$D/mnt-$NAME
[ ! -e "$R" ] && [ ! -e "$CP" ] || { echo "$R or $CP exists" >&2; exit 2; }
mkdir -p "$R" "$M"
cp --reflink=always "$SRC" "$CP"
LO=""
cleanup() { sudo umount "$M" 2>/dev/null || true; [ -n "$LO" ] && sudo losetup -d "$LO" 2>/dev/null || true; }
trap cleanup EXIT
mount_part() { LO=$(sudo losetup -f -P --show "$CP"); sudo mount "${LO}p$1" "$M"; }
umount_part() { sudo umount "$M"; sudo losetup -d "$LO"; LO=""; }
mount_part 1
sudo mkdir -p "$M/EFI/Microsoft/Boot"
printf 'stand-in for the Windows boot manager (alpbahOS test, round 27)\n' | sudo tee "$M/EFI/Microsoft/Boot/bootmgfw.efi" > /dev/null
find "$M/EFI" -maxdepth 3 | sed "s|$M||" > "$R/esp-tree.txt"
umount_part
mount_part 2
sudo tee "$M/etc/systemd/system/r27-grub-mkconfig.service" > /dev/null <<'UNIT'
[Unit]
Description=Round 27 test: grub-mkconfig with os-prober, then power off
After=multi-user.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c '/usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg > /root/r27-grub-mkconfig.log 2>&1; echo rc=$? >> /root/r27-grub-mkconfig.log; echo == os-prober >> /root/r27-grub-mkconfig.log; os-prober >> /root/r27-grub-mkconfig.log 2>&1; echo == lsblk >> /root/r27-grub-mkconfig.log; lsblk -o NAME,FSTYPE,PARTTYPE,MOUNTPOINT >> /root/r27-grub-mkconfig.log 2>&1; echo == journal >> /root/r27-grub-mkconfig.log; journalctl -b --no-pager | grep -i -E "os-prober|probe|efi|microsoft|mounted" | tail -60 >> /root/r27-grub-mkconfig.log 2>&1; sync'
ExecStartPost=/usr/bin/systemctl poweroff
[Install]
WantedBy=multi-user.target
UNIT
sudo ln -sf /etc/systemd/system/r27-grub-mkconfig.service "$M/etc/systemd/system/multi-user.target.wants/r27-grub-mkconfig.service"
umount_part
ACCEL=kvm bash "$W/vm-start.sh" uefi "" "$R/mk" "$CP" virtio 4G > /dev/null
for _ in $(seq 1 60); do pgrep -f "qemu-system.*$R/mk/" > /dev/null || break; sleep 5; done
pgrep -f "qemu-system.*$R/mk/" > /dev/null && { python3 "$W/qmpctl.py" "$R/mk" quit > /dev/null; echo "mk run did not power off" >> "$R/result.txt"; }
mount_part 2
sudo cat "$M/root/r27-grub-mkconfig.log" > "$R/grub-mkconfig.log" || true
sudo grep -n "menuentry '" "$M/boot/grub/grub.cfg" > "$R/menuentries.txt" || true
sudo rm -f "$M/etc/systemd/system/r27-grub-mkconfig.service" "$M/etc/systemd/system/multi-user.target.wants/r27-grub-mkconfig.service"
umount_part
EXTRA_ARGS="-snapshot" ACCEL=kvm bash "$W/vm-start.sh" uefi "" "$R/menu" "$CP" virtio 4G > /dev/null
for s in 4 6 8 10; do sleep 2; python3 "$W/qmpctl.py" "$R/menu" shot "t$s" > /dev/null 2>&1 || true; done
python3 "$W/qmpctl.py" "$R/menu" quit > /dev/null 2>&1 || true
sleep 2; rm -f "$CP"; rmdir "$M" 2>/dev/null || true
cat "$R/menuentries.txt"
