#!/bin/bash
# Round 21: zram swap in the LIVE session (ZRAM-01). swapon is in /usr/sbin, which is not in the live user's PATH, so
# the check reads /proc/swaps and free. Live UEFI boot under KVM -cpu qemu64, Konsole by Alt+Space, screenshots.
# Keys in the Turkish-Q session: '-' = equal, '.' = slash, '/' = shift 7, 'i' = apostrophe.
# Usage: live-swap-r21.sh <iso>
set -u
ISO=$1
W=/home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/image
R=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r21/L1b
Q="python3 $W/qmpctl.py $R"
tq() { local s="$1" i c; for ((i=0; i<${#s}; i++)); do c=${s:i:1}
  case $c in -) $Q key equal ;; i) $Q key apostrophe ;; .) $Q key slash ;; /) $Q combo shift 7 ;; ' ') $Q key spc ;; *) $Q text "$c" ;; esac
  sleep 0.15; done; }
rm -rf "$R"; ACCEL=kvm bash $W/vm-start.sh uefi "$ISO" "$R" "" virtio 4G > /dev/null; sleep 130
$Q combo alt spc; sleep 2; tq konsole; $Q key ret; sleep 8
tq "cat /proc/swaps"; $Q key ret; sleep 2; tq "free -m"; $Q key ret; sleep 2
tq "systemctl is-active alpbahos-zram alpbahos-firewall"; $Q key ret; sleep 3; $Q shot l1b-swaps
$Q quit; for i in $(seq 1 30); do pgrep -f "qemu-system.*$R/" > /dev/null || break; sleep 1; done
