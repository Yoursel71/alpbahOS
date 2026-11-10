#!/bin/bash
# Round 20 read-only disk check of an installed raw image (INSTALL-UID-01, INSTALL-CLEANUP-01, NET-FW-01).
# Read-only loop device and mount; the root partition is found with blkid (lsblk has no FSTYPE for a new loop
# device without udev probing, which broke the first lane version). Usage: disk-check-r20.sh <raw> <name>
set -u
IMG=$1; NAME=$2
D=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r20
M=$D/mnt-$NAME
mkdir -p "$M"; LO=$(sudo losetup -r -f -P --show "$IMG")
P=""; for p in "$LO"p*; do [ "$(sudo blkid -o value -s TYPE "$p")" = ext4 ] && P=$p; done
[ -n "$P" ] || { echo "no ext4 partition in $IMG"; sudo losetup -d "$LO"; exit 1; }
sudo mount -o ro "$P" "$M"
{
  echo "== disk check $NAME ($IMG, root $P, partitions: $(ls "$LO"p* | wc -l))"
  echo "owner of /: $(stat -c %u:%g "$M")"
  echo "passwd uid 1000-59999: $(awk -F: '$3>=1000 && $3<60000 {print $1":"$3":"$4}' "$M/etc/passwd" | tr '\n' ' ')"
  echo "group gid 1000: $(awk -F: '$3==1000 {print $1}' "$M/etc/group")"
  echo "live in passwd/group: $(grep -c '^live:' "$M/etc/passwd")/$(grep -c '^live:' "$M/etc/group"); /home: $(ls "$M/home" | tr '\n' ' ')"
  echo "uid/gid 1000 owned outside /home/testuser: [$(sudo find "$M" -xdev \( -uid 1000 -o -gid 1000 \) ! -path "$M/home/testuser*" | head -3 | tr '\n' ' ')]"
  echo "empty shadow passwords: [$(sudo awk -F: '$2=="" {print $1}' "$M/etc/shadow" | tr '\n' ' ')]"
  echo "polkit rules.d: $(sudo ls "$M/etc/polkit-1/rules.d" | tr '\n' ' ')"
  echo "live-only paths present: [$(ls -d "$M/usr/lib/alpbahos" "$M/etc/calamares" "$M/usr/bin/alpbahos-install" "$M/home/live" 2>/dev/null | tr '\n' ' ')]"
  echo "sddm [Autologin]: $(sed -n '/^\[Autologin\]/,/^\[/p' "$M/etc/sddm.conf" | grep -v '^\[' | tr '\n' ' ')"
  echo "sddm.conf.d User lines: [$(grep -h '^User=' "$M"/etc/sddm.conf.d/*.conf 2>/dev/null | tr '\n' ' ')]"
  echo "NM enabled: $(ls "$M/etc/systemd/system/multi-user.target.wants/" | grep -c '^NetworkManager.service$'); networkd units enabled: $(find "$M/etc/systemd/system" -name 'systemd-networkd*' | wc -l)"
  echo "NM conf: $(cat "$M"/etc/NetworkManager/conf.d/*.conf | grep -E '^(dhcp|dns)=' | tr '\n' ' ')"
  echo "firmware: WHENCE $(test -s "$M/usr/lib/firmware/WHENCE" && echo yes) files $(find "$M/usr/lib/firmware" -type f | wc -l); wpa_supplicant $(test -x "$M/usr/sbin/wpa_supplicant" && echo yes)"
  echo "installer logs: $(ls "$M/var/log" | grep -i -E 'calamares|installation' | tr '\n' ' ')"
} > "$D/disk-check-$NAME.txt" 2>&1
sudo umount "$M"; sudo losetup -d "$LO"; rmdir "$M"
cat "$D/disk-check-$NAME.txt"
