#!/bin/bash
# GRUB-THEME-01 (D1) rows on an installed disk image from the round 22 ISO. Runs as the build user on the host; sudo
# only for the loop mount of a reflink copy. KVM, -cpu qemu64 (vm-start.sh), screenshots by QMP.
#   menu <bios|uefi> <installed-raw> <name>
#       Boots the installed image unchanged (-snapshot: nothing is written to it) with the default display: a
#       screenshot every second for 9 s (menu, countdown, progress bar at the gfxmode "auto" picks), then the screen
#       at 100 s (the countdown booted the default entry when the greeter is up). No key is pressed.
#   mode <bios|uefi> <installed-raw> <name> <WxH>
#       Reflink copy of the image; in the copy only the line "set gfxmode=auto" of /boot/grub/grub.cfg becomes
#       "set gfxmode=<WxH>" (QEMU firmware gives GRUB no EDID mode, so "auto" cannot show 1280x720 or 1920x1080).
#       Boots the copy, screenshots at 3 and 5 s, presses "e" and "c" for the edit and command-line screens,
#       then removes the copy.
# Evidence: scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r22/<name>/.
set -euo pipefail
CMD=$1; FW=$2; IMG=$3; NAME=$4; MODE=${5:-}
B=/home/yrslf/alpbahOS/scratch-lfs-bench
W=/home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/image
D=$B/lfs13-logs/iso-beta-0.9/r22
R=$D/$NAME
[ ! -e "$R" ] || { echo "$R exists" >&2; exit 2; }
mkdir -p "$R"
Q="python3 $W/qmpctl.py $R"
waitq() { for _ in $(seq 1 30); do pgrep -f "qemu-system.*$R/" > /dev/null || break; sleep 1; done; }

case "$CMD" in
menu)
    EXTRA_ARGS="-snapshot" ACCEL=kvm bash "$W/vm-start.sh" "$FW" "" "$R" "$IMG" virtio 6G > /dev/null
    for s in 1 2 3 4 5 6 7 8 9; do sleep 1; $Q shot "t$s" > /dev/null || true; done
    sleep 91; $Q shot t100 > /dev/null
    $Q quit > /dev/null; waitq ;;
mode)
    CP=$D/$NAME-copy.raw; M=$D/mnt-$NAME
    [ ! -e "$CP" ] || { echo "$CP exists" >&2; exit 2; }
    cp --reflink=always "$IMG" "$CP"
    LO=$(sudo losetup -f -P --show "$CP")
    cleanup() { sudo umount "$M" 2>/dev/null || true; sudo losetup -d "$LO" 2>/dev/null || true; rmdir "$M" 2>/dev/null || true; }
    trap cleanup EXIT ERR
    P=$(for p in "$LO"p*; do [ "$(sudo blkid -o value -s TYPE "$p")" = ext4 ] && echo "$p"; done | head -n 1)
    mkdir -p "$M"; sudo mount "$P" "$M"
    [ "$(grep -c '^  set gfxmode=auto$' "$M/boot/grub/grub.cfg")" = 1 ] || { echo "gfxmode line not found once" >&2; exit 1; }
    sudo sed -i "s/^  set gfxmode=auto\$/  set gfxmode=$MODE/" "$M/boot/grub/grub.cfg"
    grep -n 'gfxmode\|theme\|loadfont\|terminal_output' "$M/boot/grub/grub.cfg" > "$R/grub-cfg-lines.txt"
    cleanup; trap - EXIT ERR
    ACCEL=kvm bash "$W/vm-start.sh" "$FW" "" "$R" "$CP" virtio 6G > /dev/null
    sleep 3; $Q shot t3 > /dev/null; sleep 2; $Q shot t5 > /dev/null
    $Q key e > /dev/null; sleep 2; $Q shot edit > /dev/null; $Q key esc > /dev/null; sleep 2
    $Q key c > /dev/null; sleep 2; $Q shot cmdline > /dev/null
    $Q quit > /dev/null; waitq; rm -f "$CP" ;;
*) echo "usage: see the header" >&2; exit 2 ;;
esac
ls "$R"
