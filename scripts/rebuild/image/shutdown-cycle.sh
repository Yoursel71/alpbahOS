#!/bin/bash
# One shutdown cycle on an installed disk: boot (KVM, virtio, -cpu qemu64), log in on the greeter, open Konsole,
# keep the Plasma session for 90 s, then power off from Konsole with systemctl poweroff while the session is active.
# Usage: shutdown-cycle.sh <disk.raw> <run-dir>      (the QEMU process ends by itself at power-off)
set -u
DISK=$1; R=$2
W=/home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/image
Q="python3 $W/qmpctl.py $R"
rm -rf "$R"
EXTRA_ARGS="-device intel-hda -device hda-duplex" ACCEL=kvm bash $W/vm-start.sh bios "" "$R" "$DISK" virtio 6G > /dev/null
sleep 100
$Q click 766 489; sleep 1
$Q text TestPass; $Q key equal; $Q text 0; $Q key slash; $Q text 9; $Q key ret
sleep 50
$Q combo alt spc; sleep 2
$Q trtext konsole; $Q key ret; sleep 10
sleep 90
$Q trtext "systemctl poweroff"; $Q key ret
for i in $(seq 1 30); do pgrep -f "qemu-system-x86_64 .*$(basename "$R")" > /dev/null || break; sleep 10; done
echo "cycle done: $R"
