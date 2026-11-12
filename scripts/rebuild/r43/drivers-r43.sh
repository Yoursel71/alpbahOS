#!/bin/bash
# D166 (round 43): the installed-system side of the installer's "Sürücüler" page (record alpbahos-drivers-r43):
# drivers-mark (run by Calamares contextualprocess in the new system: writes the choice, enables the service),
# install-drivers + alpbahos-install-drivers.service (first boots: alp install nvidia once the network is up and only
# with an NVIDIA display controller), drivers-notify + its autostart entry (desktop notifications). Run as root.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ST=$SB/r43/stage-drivers
P=$WT/profiles/drivers
rm -rf "$ST"
install -D -m 755 "$P/drivers-mark" "$ST/usr/libexec/alpbahos/drivers-mark"
install -D -m 755 "$P/install-drivers" "$ST/usr/libexec/alpbahos/install-drivers"
install -D -m 755 "$P/drivers-notify" "$ST/usr/libexec/alpbahos/drivers-notify"
install -D -m 644 "$P/alpbahos-install-drivers.service" "$ST/usr/lib/systemd/system/alpbahos-install-drivers.service"
install -D -m 644 "$P/alpbahos-drivers-notify.desktop" "$ST/etc/xdg/autostart/alpbahos-drivers-notify.desktop"
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-drivers-r43 0.9-r43 "$ST" \
    alpbahos-drivers-r43 0.9-r43
