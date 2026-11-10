#!/bin/bash
# Round 23 rows for PLYMOUTH-01 (D2) and the live GRUB menu (LIVE-GRUB-THEME-01). Runs as the build user on the host;
# KVM, -cpu qemu64 (vm-start.sh), screenshots by QMP. Evidence: scratch-lfs-bench/lfs13-logs/iso-beta-0.9/<ROUND>/<name>/.
#   splash <bios|uefi> <installed-raw> <name>
#       Boots the installed image unchanged (-snapshot), no key pressed: a screenshot every second for 25 s (GRUB,
#       splash), the screen at 90 s (greeter), then the ACPI power button (logind powers off) and a screenshot every
#       half second until QEMU ends (shutdown splash). The screenshot times are in shots.txt.
#   livemenu <bios|uefi> <iso> <name>
#       Boots the ISO without a disk: ten screenshots about one second apart (live GRUB menu), then quits.
set -euo pipefail
CMD=$1; FW=$2; IMG=$3; NAME=$4
B=/home/yrslf/alpbahOS/scratch-lfs-bench
W=/home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/image
D=$B/lfs13-logs/iso-beta-0.9/${ROUND:-r23}
R=$D/$NAME
[ ! -e "$R" ] || { echo "$R exists" >&2; exit 2; }
mkdir -p "$R"
Q="python3 $W/qmpctl.py $R"
T0=$(date +%s.%N)
shot() { $Q shot "$1" > /dev/null 2>&1 && LC_ALL=C printf "%s %.1f\n" "$1" "$(echo "$(date +%s.%N) - $T0" | bc)" >> "$R/shots.txt" || true; }
running() { pgrep -f "qemu-system.*$R/" > /dev/null; }
case "$CMD" in
splash)
    EXTRA_ARGS="-snapshot" ACCEL=kvm bash "$W/vm-start.sh" "$FW" "" "$R" "$IMG" virtio 6G > /dev/null
    T0=$(date +%s.%N)
    for s in $(seq 1 25); do sleep 1; shot "b$(printf %02d "$s")"; done
    sleep 65; shot greeter
    $Q powerdown > /dev/null
    for i in $(seq 1 120); do running || break; sleep 0.5; shot "s$(printf %03d "$i")"; done
    running && { $Q quit > /dev/null; echo "QEMU still running after 60 s, quit" >> "$R/shots.txt"; } ;;
livemenu)
    ACCEL=kvm bash "$W/vm-start.sh" "$FW" "$IMG" "$R" "" virtio 4G > /dev/null
    T0=$(date +%s.%N)
    for s in 2 3 4 5 6 7 8 9 10 11; do sleep 1; shot "m$s"; done
    $Q quit > /dev/null ;;
*) echo "usage: see the header" >&2; exit 2 ;;
esac
ls "$R" | grep -c png
