#!/bin/bash
# REBUILD-R20 (NET-FW-01, D147): NetworkManager manages the links, systemd-networkd is off, in r4-root (so the live
# image and the installed system, which is unpacked from the same squashfs, start the same way). Run as root on the
# host; systemctl runs offline in a chroot of r4-root. The Calamares services-systemd step repeats the same actions
# on the installed system (scripts/rebuild/iso/live/calamares/modules/services-systemd.conf).
# The networkd sockets are disabled too: an enabled socket would start networkd again by activation.
# Enablement symlinks are state, not package files: no alp record (as for the earlier unit choices).
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
R4=$SB/r4-root
[ -x "$R4/usr/sbin/NetworkManager" ] || { echo "NetworkManager missing in r4-root"; exit 1; }
[ -x "$R4/usr/sbin/wpa_supplicant" ] || { echo "wpa_supplicant missing in r4-root (run wpa-r20.sh first)"; exit 1; }
OFF="systemd-networkd.service systemd-networkd.socket systemd-networkd-varlink.socket \
systemd-networkd-varlink-metrics.socket systemd-networkd-resolve-hook.socket systemd-network-generator.service \
systemd-networkd-wait-online.service"
chroot "$R4" /usr/bin/systemctl disable $OFF
chroot "$R4" /usr/bin/systemctl enable NetworkManager.service
echo "--- enabled after the change (network units):"
find "$R4/etc/systemd/system" -name '*.wants' -prune -o -name 'dbus-org.freedesktop.*' -print | sed "s|$R4||"
find "$R4/etc/systemd/system" -path '*.wants/*' | grep -i -E 'network|resolve' | sed "s|$R4||"
for u in $OFF; do
    if find "$R4/etc/systemd/system" -name "$u" | grep -q .; then echo "still enabled: $u"; exit 1; fi
done
find "$R4/etc/systemd/system" -path '*.wants/NetworkManager.service' | grep -q . || { echo "NetworkManager not enabled"; exit 1; }
echo "units ok"
