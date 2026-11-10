#!/bin/bash
# Round 20/21 rows (NET-FW-01, INSTALL-UID-01, INSTALL-CLEANUP-01; round 21 via ROUND=r21: the same lanes plus
# the live zram/firewall lines and a 12-minute idle check of the live session, LIVE-LOCK-01). Runs as the build user; sudo only for the
# read-only loop mounts of the disk checks. KVM with -cpu qemu64 (vm-start.sh), screenshots by QMP.
#   lane1: I1 (BIOS MSDOS install) -> disk check -> B1 (installed BIOS: id, live user, network, failed units)
#   lane2: L1 (live UEFI: network, failed units, applet) -> I2 (UEFI GPT install) -> disk check -> U1 (installed UEFI)
#   lane3 (after 1 and 2): F1 forced failure: BIOS live boot by QEMU direct kernel boot with the ISO's kernel and
#          initramfs plus alpbahos.testfail=live-cleanup; the install must stop with an error.
# The test password is generated at run time into scratch-lfs-bench/test-secrets/r20.pw (outside the repo).
# Keys in the Turkish-Q session: '-' = equal, 'i' = apostrophe, '.' = slash, '/' = shift 7, '*' = minus.
# Usage: r20-lanes.sh <iso> [lane1|lane2|lane3|all]
set -u
ISO=$1; WHICH=${2:-all}
B=/home/yrslf/alpbahOS/scratch-lfs-bench
W=/home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/image
RD=${ROUND:-r20}
D=$B/lfs13-logs/iso-beta-0.9/$RD
IMGB=$B/images/inst-bios-msdos-$RD.raw
IMGU=$B/images/inst-uefi-gpt-$RD.raw
IMGF=$B/images/inst-bios-f1-$RD.raw
mkdir -p "$D" "$B/test-secrets"
PWF=$B/test-secrets/$RD.pw
[ -s "$PWF" ] || { umask 077; printf 'T%s9\n' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$PWF"; }
PW=$(cat "$PWF")

tq() { local RUN="$1"; shift; local s="$*" i c
  for ((i=0; i<${#s}; i++)); do c=${s:i:1}
    case $c in
      -) python3 $W/qmpctl.py "$RUN" key equal ;;
      i) python3 $W/qmpctl.py "$RUN" key apostrophe ;;
      '*') python3 $W/qmpctl.py "$RUN" key minus ;;
      .) python3 $W/qmpctl.py "$RUN" key slash ;;
      /) python3 $W/qmpctl.py "$RUN" combo shift 7 ;;
      ' ') python3 $W/qmpctl.py "$RUN" key spc ;;
      *) python3 $W/qmpctl.py "$RUN" text "$c" ;;
    esac; sleep 0.15; done; }
clr() { local Q="$1"; $Q combo ctrl a; $Q key $(for i in $(seq 1 25); do echo -n "backspace "; done); }
waitq() { for i in $(seq 1 30); do pgrep -f "qemu-system.*$1/" > /dev/null || break; sleep 1; done; }
run() { local R=$1 cmd=$2 wait=$3 shot=$4; local Q="python3 $W/qmpctl.py $R"
  tq "$R" "clear"; $Q key ret; sleep 1; tq "$R" "$cmd"; $Q key ret; sleep "$wait"; $Q shot "$shot"; }

install_run() { # fw image name kur_x kur_y  (KERNEL, INITRD, APPEND from the caller: direct kernel boot)
  local FW=$1 IMG=$2 NAME=$3 KX=$4 KY=$5 R=$D/$3
  rm -rf "$R"; [ ! -e "$IMG" ] || { echo "$IMG exists"; return 1; }
  truncate -s 30G "$IMG"
  ACCEL=kvm bash $W/vm-start.sh "$FW" "$ISO" "$R" "$IMG" virtio 6G > /dev/null
  sleep 100
  local Q="python3 $W/qmpctl.py $R"
  $Q click 58 40; sleep 1; $Q key ret; sleep 40; $Q shot i-00
  for n in 1 2 3 4; do $Q click 1007 637; sleep 2; done; $Q shot i-04-users
  $Q click 404 180; sleep 1; clr "$Q"; tq "$R" "Test User"
  $Q click 404 236; sleep 1; clr "$Q"; tq "$R" "testuser"
  $Q click 404 292; sleep 1; clr "$Q"; tq "$R" "alpbahos-test"
  $Q click 404 348; sleep 1; clr "$Q"; tq "$R" "$PW"
  $Q click 610 348; sleep 1; clr "$Q"; tq "$R" "$PW"
  sleep 2; $Q shot i-05-users-filled
  $Q click 1007 637; sleep 3; $Q shot i-06-summary
  $Q click $KX $KY; sleep 4; $Q shot i-07-confirm
  $Q click 749 435; sleep 5; $Q shot i-08-running
  if [ "${FAILRUN:-0}" = 1 ]; then
    # Forced-failure run: no "unmounting" line comes. Keep the live session from locking (it cannot be unlocked:
    # the live user has no password) with a Shift press every 30 s, and take a screenshot every minute.
    for i in $(seq 1 10); do sleep 30; $Q key shift; sleep 30; $Q key shift; $Q shot "i-fail-$i"; done
  else
    for i in $(seq 1 60); do grep -q "unmounting filesystem" $R/serial.log 2>/dev/null && break; sleep 20; done
  fi
  sleep 20; $Q shot i-09-done; $Q quit; waitq "$R"
  echo "[$(date +%T)] install $NAME done"
}

disk_check() { # image name: read-only disk check (separate script; the first in-line version used lsblk FSTYPE,
  # which is empty for a new loop device, and failed to mount)
  OUTD=$D bash "$(dirname "$W")/r20/disk-check-r20.sh" "$1" "$2"
}

net_checks() { # run-dir prefix ; Konsole is open
  local R=$1 P=$2
  run "$R" "systemctl is-active NetworkManager systemd-networkd systemd-resolved" 3 "$P-active"
  run "$R" "nmcli device" 3 "$P-nmcli"
  run "$R" "resolvectl dns" 3 "$P-resolvectl"
  run "$R" "curl -sSI -m 20 -o h.txt ftp.gnu.org" 25 "$P-curl0"
  run "$R" "head -3 h.txt" 3 "$P-curl"
  run "$R" "systemctl --failed" 4 "$P-failed"
}

installed_checks() { # fw image name
  local FW=$1 IMG=$2 N=$3 R=$D/$3; rm -rf "$R"; local Q="python3 $W/qmpctl.py $R"
  EXTRA_ARGS="-snapshot" ACCEL=kvm bash $W/vm-start.sh "$FW" "" "$R" "$IMG" virtio 6G > /dev/null
  sleep 95; $Q shot "$N-greeter"; $Q click 766 489; sleep 1; tq "$R" "$PW"; $Q key ret; sleep 55; $Q shot "$N-desktop"
  $Q combo alt spc; sleep 2; tq "$R" konsole; $Q key ret; sleep 8
  run "$R" "id" 3 "$N-id"
  run "$R" "getent passwd live testuser" 3 "$N-live"
  run "$R" "ls -ldn /" 3 "$N-rootowner"
  net_checks "$R" "$N"
  $Q quit; waitq "$R"; echo "[$(date +%T)] $N done"
}

lane1() {
  install_run bios "$IMGB" I1 1000 652
  disk_check "$IMGB" I1
  [ "$RD" != r20 ] || installed_checks bios "$IMGB" B1
}

lane2() {
  local R=$D/L1; rm -rf "$R"; local Q="python3 $W/qmpctl.py $R"
  ACCEL=kvm bash $W/vm-start.sh uefi "$ISO" "$R" "" virtio 6G > /dev/null; sleep 130
  $Q shot l1-desktop-130
  $Q combo alt spc; sleep 2; tq "$R" konsole; $Q key ret; sleep 8
  run "$R" "id" 3 "l1-id"
  run "$R" "ls -ldn /" 3 "l1-rootowner"
  net_checks "$R" l1
  if [ "$RD" != r20 ]; then
    run "$R" "swapon --show" 3 "l1-swapon"
    run "$R" "systemctl is-active alpbahos-firewall alpbahos-zram" 3 "l1-fw-zram"
    # LIVE-LOCK-01: no input for 12 minutes; the session must still be on the desktop (not locked, not suspended).
    sleep 720; $Q shot "l1-idle-12min"; $Q key shift; sleep 3; $Q shot "l1-idle-12min-after-key"
  fi
  $Q quit; waitq "$R"; echo "[$(date +%T)] L1 done"
  install_run uefi "$IMGU" I2 1005 666
  disk_check "$IMGU" I2
  [ "$RD" != r20 ] || installed_checks uefi "$IMGU" U1
}

lane3() {
  local K=$D/F1-boot; mkdir -p "$K"
  bsdtar -xf "$ISO" -C "$K" boot/vmlinuz boot/initramfs-live.img
  local ARGS="root=live:CDLABEL=ALPBAHOS_BETA rd.live.image rd.live.dir=LiveOS rd.live.squashimg=squashfs.img rd.live.overlay.overlayfs=1 console=tty0 console=ttyS0,115200 alpbahos.testfail=live-cleanup"
  FAILRUN=1 KERNEL=$K/boot/vmlinuz INITRD=$K/boot/initramfs-live.img APPEND="$ARGS" install_run bios "$IMGF" "${F1NAME:-F1}" 1000 652
}

case "$WHICH" in
  lane1) lane1 ;; lane2) lane2 ;; lane3) lane3 ;;
  all) lane1 > "$D/lane1.log" 2>&1 & sleep 5; lane2 > "$D/lane2.log" 2>&1 & wait; lane3 > "$D/lane3.log" 2>&1 ;;
  installs) lane1 > "$D/lane1.log" 2>&1 & sleep 5; lane2 > "$D/lane2.log" 2>&1 & wait ;;
esac
echo ALL_DONE
