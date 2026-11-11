#!/bin/bash
# L4 hang (round 39y): boot the r39 live ISO under TCG (BIOS, pc machine) several times with nokaslr, by QEMU
# direct kernel boot of the ISO's own kernel and initramfs with the ISO's GRUB arguments plus nokaslr. A run that
# stops writing to the serial console for HANGSEC seconds counts as a hang: the RIP of every vCPU is sampled three
# times (HMP "info registers -a") and mapped to a symbol with System.map of the same kernel (the installed image's
# /boot/System.map-7.1.8-alpbahos; its vmlinuz has the same sha256 as the ISO's boot/vmlinuz).
# Usage: l4-nokaslr-r39y.sh <name-prefix> <runs> <smp>     needs the r39y env (env.sh)
set -u
. ./env.sh
P=$1; RUNS=$2; SMP=$3
W=$MATRIX_WT/scripts/rebuild/image
fresh() { local e; for e in "$@"; do [ ! -e "$e" ] || { echo "REFUSED: $e exists"; exit 2; }; done; }
K=$D/L4k
HANGSEC=${HANGSEC:-240}; MAXSEC=${MAXSEC:-600}
if [ ! -e "$K/boot/vmlinuz" ]; then
  mkdir -p "$K"; bsdtar -xf "$ISO_PATH" -C "$K" boot/vmlinuz boot/initramfs-live.img
  LO=$(sudo losetup -r -f -P --show "$IMGB_PATH"); MP=$(mktemp -d /tmp/r39y-map.XXXX)
  sudo mount -o ro,noload "${LO}p1" "$MP"; cp "$MP/boot/System.map-7.1.8-alpbahos" "$K/System.map"
  echo "kernel sha: iso $(sha256sum "$K/boot/vmlinuz" | cut -c1-16) installed $(sha256sum "$MP/boot/vmlinuz-7.1.8-alpbahos" | cut -c1-16)"
  sudo umount "$MP"; sudo losetup -d "$LO"; rmdir "$MP"
fi
ARGS="root=live:CDLABEL=ALPBAHOS_BETA rd.live.image rd.live.dir=LiveOS rd.live.squashimg=squashfs.img rd.live.overlay.overlayfs=1 console=tty0 console=ttyS0,115200 nokaslr"
sym() { awk -v A="$((16#$1))" '{ v=strtonum("0x"$1); if (v<=A && ($2=="T"||$2=="t")) {best=$3; bv=v} } END{printf "%s+0x%x", best, A-bv}' "$K/System.map"; }
hmp() { python3 - "$1/qmp.sock" "$2" << 'PY'
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile("rw")
f.readline(); f.write('{"execute":"qmp_capabilities"}\n'); f.flush(); f.readline()
f.write(json.dumps({"execute": "human-monitor-command", "arguments": {"command-line": sys.argv[2]}}) + "\n"); f.flush()
print(json.loads(f.readline()).get("return", ""))
PY
}
for n in $(seq 1 "$RUNS"); do
  N=$P-$n; R=$D/$N; fresh "$R"
  gate 20 > /dev/null || { echo "$N: gate timeout"; break; }
  T0=$(date +%s)
  KERNEL=$K/boot/vmlinuz INITRD=$K/boot/initramfs-live.img APPEND="$ARGS" EXTRA_ARGS="-smp $SMP" \
    ACCEL=tcg bash "$W/vm-start.sh" bios "$ISO_PATH" "$R" "" virtio 6G > /dev/null
  last=0; lastchange=$T0; result=timeout
  while :; do
    sleep 10; now=$(date +%s); sz=$(stat -c %s "$R/serial.log" 2>/dev/null || echo 0)
    [ "$sz" != "$last" ] && { last=$sz; lastchange=$now; }
    if grep -aq "login:" "$R/serial.log"; then result="login prompt after $((now - T0)) s"; break; fi
    if [ $((now - lastchange)) -ge "$HANGSEC" ]; then result="HANG: serial log unchanged for $((now - lastchange)) s at $sz bytes"; break; fi
    [ $((now - T0)) -ge "$MAXSEC" ] && { result="no login within $MAXSEC s (serial still growing)"; break; }
  done
  echo "$N (smp $SMP): $result; load $(cut -d' ' -f1-3 /proc/loadavg)"
  if [ "${result#HANG}" != "$result" ]; then
    tr -d '\r' < "$R/serial.log" | tail -n 4 | sed 's/^/   serial: /'
    for k in 1 2 3; do
      hmp "$R" "info registers -a" > "$R/regs-$k.txt"
      for rip in $(grep -o 'RIP=[0-9a-f]*' "$R/regs-$k.txt" | cut -d= -f2); do echo "   sample $k RIP=$rip $(sym "$rip")"; done
      sleep 3
    done
    python3 "$W/qmpctl.py" "$R" shot hang > /dev/null 2>&1; rm -f "$R/hang.ppm"
  else
    python3 "$W/qmpctl.py" "$R" shot end > /dev/null 2>&1; rm -f "$R/end.ppm"
  fi
  python3 "$W/qmpctl.py" "$R" quit 2> /dev/null
  for i in $(seq 1 30); do pgrep -f -- "-qmp unix:$R/qmp.sock" > /dev/null || break; sleep 1; done
done
