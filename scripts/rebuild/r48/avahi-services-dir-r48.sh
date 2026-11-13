#!/bin/bash
# r48: /etc/avahi/services eksik - avahi-daemon her acilista "Failed to read /etc/avahi/services" uyarisi basiyordu
# (round 45'ten beri goruluyor, zararsiz ama gurultu). r4-root'a dogrudan uygulanir, root ister.
set -eu
R=${1:-/home/yrslf/alpbahOS/scratch-lfs-bench/r4-root}
install -d -m 0755 -o root -g root "$R/etc/avahi/services"
echo "ok: $R/etc/avahi/services created"
