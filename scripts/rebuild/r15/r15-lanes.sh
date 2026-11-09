#!/bin/bash
# Round 15 matrix on ISO r15 (TAG=r15). Lane 1: I1 -> REC1 -> B1. Lane 2: L1 -> I2 -> U1 -> FP.
# Keys in the Turkish-Q session: '-' = equal, 'i' = apostrophe, '.' = slash, '/' = shift 7, '*' = minus.
B=/home/yrslf/alpbahOS/scratch-lfs-bench
W=/home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/image
D=$B/lfs13-logs/iso-beta-0.9/r15
ISO=$B/images/alpbahos-beta-0.9-2026-11-09-r15.iso
IMGB=$B/images/inst-bios-msdos-r15.raw
IMGU=$B/images/inst-uefi-gpt-r15.raw
PW=TestPass-0.9
mkdir -p $D

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

install_run() { # fw image name kur_x kur_y
  local FW=$1 IMG=$2 NAME=$3 KX=$4 KY=$5 R=$D/$3
  rm -rf "$R"
  ACCEL=kvm DISKFMT=raw bash $W/vm-start.sh "$FW" "$ISO" "$R" "$IMG" virtio 6G > /dev/null
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
  for i in $(seq 1 60); do grep -q "unmounting filesystem" $R/serial.log 2>/dev/null && break; sleep 20; done
  sleep 20; $Q shot i-09-done; $Q quit
  for i in $(seq 1 20); do pgrep -c qemu-system >/dev/null || break; sleep 1; done
  echo "[$(date +%T)] install $NAME done"
}

live_l1() { local N=$1; local R=$D/$N; rm -rf "$R"
  ACCEL=kvm bash $W/vm-start.sh uefi "$ISO" "$R" "" virtio 6G > /dev/null; sleep 130
  python3 $W/qmpctl.py "$R" shot shot-130; python3 $W/qmpctl.py "$R" quit
  for i in $(seq 1 20); do pgrep -c qemu-system >/dev/null || break; sleep 1; done
  echo "[$(date +%T)] L1 $N done"; }

lane1() {
  install_run bios "$IMGB" I1 1000 652
  local RC=$D/REC1; local CP=$B/lfs13-logs/iso-beta-0.9/r15/rec-r15-bios-broken.raw
  rm -f "$CP"; cp --reflink=always "$IMGB" "$CP"
  local LO; LO=$(sudo losetup -f -P --show "$CP"); mkdir -p "$D/recmnt"; sudo mount "${LO}p1" "$D/recmnt"
  sudo rm -f "$D/recmnt/boot/initramfs-"*.img; sudo truncate -s 0 "$D/recmnt/boot/grub/grub.cfg"; sudo umount "$D/recmnt"; sudo losetup -d "$LO"; rmdir "$D/recmnt"
  rm -rf "$RC"; local Q="python3 $W/qmpctl.py $RC"
  EXTRA_ARGS="-boot order=dc" ACCEL=kvm DISKFMT=raw bash $W/vm-start.sh bios "$ISO" "$RC" "$CP" virtio 6G > /dev/null
  sleep 110; $Q combo alt spc; sleep 2; tq "$RC" konsole; $Q key ret; sleep 8
  tq "$RC" "pkexec /usr/local/s*/alpbahos-recover"; $Q key ret; sleep 6; $Q shot rec-step0
  tq "$RC" "pkexec /usr/local/s*/alpbahos-recover /dev/vda1"; $Q key ret; sleep 240; $Q shot rec-step1
  sleep 100; $Q shot rec-step2; $Q quit
  for i in $(seq 1 20); do pgrep -c qemu-system >/dev/null || break; sleep 1; done
  local R2=$D/REC1-boot; rm -rf "$R2"
  ACCEL=kvm DISKFMT=raw bash $W/vm-start.sh bios "" "$R2" "$CP" virtio 6G > /dev/null
  sleep 110; python3 $W/qmpctl.py "$R2" shot rec-disk-greeter; python3 $W/qmpctl.py "$R2" quit
  for i in $(seq 1 20); do pgrep -c qemu-system >/dev/null || break; sleep 1; done
  echo "[$(date +%T)] REC1 done"
  local RB=$D/B1; rm -rf "$RB"; local QB="python3 $W/qmpctl.py $RB"
  EXTRA_ARGS="-snapshot -device intel-hda -device hda-duplex" ACCEL=kvm DISKFMT=raw bash $W/vm-start.sh bios "" "$RB" "$IMGB" virtio 6G > /dev/null
  sleep 95; $QB shot b1-greeter; $QB click 766 489; sleep 1; tq "$RB" "$PW"; $QB key ret; sleep 55; $QB shot b1-desktop
  $QB combo alt spc; sleep 2; tq "$RB" konsole; $QB key ret; sleep 8
  tq "$RB" "localectl status"; $QB key ret; sleep 3; $QB shot b1-localectl
  tq "$RB" "curl -sS -m 10 -I -o h1.txt http://10.0.2.2/"; $QB key ret; sleep 15
  tq "$RB" "curl -sS -m 15 -I -o h2.txt http://ftp.gnu.org/"; $QB key ret; sleep 25
  tq "$RB" "cat h1.txt h2.txt"; $QB key ret; sleep 3; $QB shot b1-curl
  tq "$RB" "fastfetch"; $QB key ret; sleep 5; $QB shot b1-fastfetch
  tq "$RB" "alp list"; $QB key ret; sleep 3; $QB shot b1-alp-list
  tq "$RB" "systemctl --failed"; $QB key ret; sleep 3; $QB shot b1-failed
  $QB quit
  for i in $(seq 1 20); do pgrep -c qemu-system >/dev/null || break; sleep 1; done
  echo "[$(date +%T)] B1 done"
}

lane2() {
  live_l1 L1-1
  install_run uefi "$IMGU" I2 1005 666
  local RU=$D/U1; rm -rf "$RU"; local QU="python3 $W/qmpctl.py $RU"
  EXTRA_ARGS="-snapshot -device intel-hda -device hda-duplex" ACCEL=kvm DISKFMT=raw bash $W/vm-start.sh uefi "" "$RU" "$IMGU" virtio 6G > /dev/null
  sleep 95; $QU shot u1-greeter; $QU click 766 489; sleep 1; tq "$RU" "$PW"; $QU key ret; sleep 55; $QU shot u1-desktop
  $QU combo alt spc; sleep 2; tq "$RU" konsole; $QU key ret; sleep 8
  tq "$RU" "hostnamectl"; $QU key ret; sleep 3; $QU shot u1-hostnamectl
  tq "$RU" "systemctl --failed"; $QU key ret; sleep 4; $QU shot u1-failed
  tq "$RU" "flatpak remotes"; $QU key ret; sleep 3; $QU shot u1-fp-remotes
  tq "$RU" "pkexec flatpak install -y flathub org.gnome.Calculator"; $QU key ret; sleep 8; tq "$RU" "$PW"; $QU key ret
  for i in $(seq 1 20); do sleep 60; $QU key shift; done
  $QU shot u1-fp-install
  tq "$RU" "flatpak list"; $QU key ret; sleep 4; $QU shot u1-fp-list
  tq "$RU" "flatpak run org.gnome.Calculator"; $QU key ret; sleep 25; $QU shot u1-calc
  $QU quit
  for i in $(seq 1 20); do pgrep -c qemu-system >/dev/null || break; sleep 1; done
  echo "[$(date +%T)] U1 done"
}

lane1 > $D/lane1.log 2>&1 &
sleep 5
lane2 > $D/lane2.log 2>&1 &
wait
echo ALL_DONE
