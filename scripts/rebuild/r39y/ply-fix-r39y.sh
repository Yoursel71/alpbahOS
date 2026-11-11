#!/bin/bash
# PLY-FIX-01 (round 39y): does UseSimpledrm=0 remove the plymouthd SIGSEGV of PLY-CRASH-01?
# A fresh reflink copy of the kept r39 BIOS install gets the same core instrumentation as ply-loop-r39y.sh
# (prlimit on the initramfs plymouthd, core_pattern to a file, plymouth.debug, r21m test shell). Then:
#   setup boot (unchanged settings, UseSimpledrm=1): screenshots during boot (baseline), then in the guest:
#     /etc/plymouth/plymouthd.conf UseSimpledrm=1 -> 0 (plymouthd.defaults unchanged: dracut reads only that file
#     for the module list, so the initramfs keeps its size), initramfs rebuilt with the installer's own
#     target-initramfs.sh, the initramfs copy of plymouthd.conf checked, power-off
#   CYCLES boots with the change (screenshots during boot in the first two), crashes counted from core files.
# Usage: ply-fix-r39y.sh      env: CYCLES (default 20); needs the r39y env (env.sh); evidence in r39y/PLYFIX/
set -u
. ./env.sh
RB=$MATRIX_WT/scripts/rebuild
export MATRIX_DIR=$MATRIX_DIR/PLYFIX
MATRIX_LIB=1 . "$M"          # D is now r39y/PLYFIX
CYCLES=${CYCLES:-20}
CP=$D/PLYFIX-disk.raw
fresh "$CP"
cmd_mkcopy bios PLYFIX-disk
LO=$(sudo losetup -f -P --show "$CP"); MP=$(mktemp -d /tmp/r39y-fix.XXXX)
sudo mount "${LO}p1" "$MP"
sudo tee "$MP/usr/local/sbin/r39y-plycore" > /dev/null << 'EOS'
#!/bin/sh
for p in $(pgrep -x plymouthd); do
  prlimit --pid "$p" --core=unlimited:unlimited
  echo "R39Y plycore: plymouthd pid $p core limit $(prlimit --pid "$p" --core --noheadings --output SOFT,HARD | tr -s ' ') uptime $(cut -d' ' -f1 /proc/uptime)" > /dev/ttyS0
done
[ -n "$(pgrep -x plymouthd)" ] || echo "R39Y plycore: no plymouthd running, uptime $(cut -d' ' -f1 /proc/uptime)" > /dev/ttyS0
EOS
sudo chmod 755 "$MP/usr/local/sbin/r39y-plycore"
sudo tee "$MP/etc/systemd/system/r39y-plycore.service" > /dev/null << 'EOS'
[Unit]
Description=Round 39y: unlimited core size for the initramfs plymouthd (test copy only)
DefaultDependencies=no
After=systemd-sysctl.service
Before=sysinit.target plymouth-quit.service plymouth-quit-wait.service plymouth-read-write.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/r39y-plycore
[Install]
WantedBy=sysinit.target
EOS
sudo mkdir -p "$MP/etc/systemd/system/sysinit.target.wants"
sudo ln -sf /etc/systemd/system/r39y-plycore.service "$MP/etc/systemd/system/sysinit.target.wants/r39y-plycore.service"
echo "kernel.core_pattern=/var/tmp/core.%e.%p.%t" | sudo tee "$MP/etc/sysctl.d/99-r39y-core.conf" > /dev/null
sudo sed -i 's#^\(\s*linux\s.*vmlinuz-[^ ]* .*\)quiet splash#\1quiet splash plymouth.debug#' "$MP/boot/grub/grub.cfg"
echo "grub: $(grep -m1 'linux.*vmlinuz' "$MP/boot/grub/grub.cfg")"
echo "before: plymouthd.conf: $(grep -v '^#' "$MP/etc/plymouth/plymouthd.conf" | tr '\n' ' '); defaults: $(grep -v '^#' "$MP/usr/share/plymouth/plymouthd.defaults" | tr '\n' ' ')"
sudo umount "$MP"; sudo losetup -d "$LO"; rmdir "$MP"

shots() { # run-dir prefix seconds: screenshots from QEMU start, named by the second they were taken
  local R=$1 P=$2 S=$3 T0 t; T0=$(cat "$R/t-start")
  while :; do t=$(( $(date +%s) - T0 )); [ "$t" -le "$S" ] || break; shot "$R" "$P-$(printf %02d "$t")s"; done; }
boot() { # name: start a guest on the copy, wait for the test shell
  agent_start "$1" bios PLYFIX-disk virtio 4G
  [ "${2:-}" = shots ] && shots "$D/$1" boot 25
  for i in $(seq 1 90); do grep -aq "R21M begin" "$D/$1/serial.log" 2> /dev/null && break; sleep 2; done
  grep -aq "R21M begin" "$D/$1/serial.log"; }
off() { python3 "$RB/r21/gsh.py" "$D/$1" 0 "systemctl poweroff"
  for i in $(seq 1 60); do alive "$D/$1" || break; sleep 1; done
  alive "$D/$1" && { echo "$1: power-off not done in 60 s, QMP quit"; vmquit "$D/$1"; }; return 0; }
export EXTRA_ARGS="-device intel-hda -device hda-duplex"

# ---- setup boot: baseline screenshots, then the change ---------------------------------------------------
gate 20 > /dev/null || exit 1
boot FIX-setup shots || { echo "setup: no test shell"; exit 1; }
sleep 10
TI=$(base64 -w0 < "$RB/iso/live/target-initramfs.sh")
python3 "$RB/r21/gsh.py" "$D/FIX-setup" 900 "echo setup boot: \$(journalctl -b --no-pager | grep -c 'plymouthd.*SEGV') segv lines, cores \$(ls /var/tmp/core.* 2>/dev/null | wc -l); ls -l /boot/initramfs-*.img; sed -i 's/^UseSimpledrm=1\$/UseSimpledrm=0/' /etc/plymouth/plymouthd.conf; echo conf: \$(grep -v '^#' /etc/plymouth/plymouthd.conf | tr '\n' ' '); echo $TI | base64 -d > /tmp/ti.sh; sh /tmp/ti.sh > /tmp/ti.log 2>&1; echo target-initramfs rc=\$?; tail -n 3 /tmp/ti.log; ls -l /boot/initramfs-*.img; echo initramfs conf: \$(lsinitrd -f etc/plymouth/plymouthd.conf /boot/initramfs-*.img | grep -v '^#' | tr '\n' ' '); echo initramfs defaults: \$(lsinitrd -f usr/share/plymouth/plymouthd.defaults /boot/initramfs-*.img | grep Simpledrm); echo drm modules in initramfs: \$(lsinitrd /boot/initramfs-*.img | grep -c -E 'drivers/gpu/drm/.*\\.ko'); sync"
off FIX-setup

# ---- cycles with UseSimpledrm=0 ---------------------------------------------------------------------------
c=0; prev=0
while [ "$c" -lt "$CYCLES" ]; do
  c=$((c + 1)); N=$(printf 'FIX-c%02d' "$c")
  gate 20 > /dev/null || { echo "cycle $c: gate timeout"; break; }
  if [ "$c" -le 2 ]; then boot "$N" shots; else boot "$N"; fi || { echo "cycle $c: no test shell"; shot "$D/$N" noshell; vmquit "$D/$N"; continue; }
  sleep 15
  OUT=$(python3 "$RB/r21/gsh.py" "$D/$N" 30 'echo "boot $(cut -c1-8 /proc/sys/kernel/random/boot_id) cores=$(ls /var/tmp/core.* 2>/dev/null | wc -l) quit=$(systemctl show -p Result --value plymouth-quit.service) usesimpledrm=$(grep ^UseSimpledrm /etc/plymouth/plymouthd.conf) showsplash=$(journalctl -b --no-pager -o short-monotonic | grep -m1 "Started Show Plymouth Boot Screen" | cut -c1-14) quitstart=$(journalctl -b --no-pager -o short-monotonic | grep -m1 "Starting Terminate Plymouth" | cut -c1-14) gpu=$(journalctl -b --no-pager -o short-monotonic -k | grep -m1 "Initialized virtio_gpu" | cut -c1-14)"')
  now=$(printf '%s' "$OUT" | grep -o 'cores=[0-9]*' | cut -d= -f2)
  [ "${now:-0}" -gt "$prev" ] && echo "cycle $c: NEW CORE"
  prev=${now:-$prev}
  echo "cycle $c ($N): $OUT | $(grep -a 'R39Y plycore' "$D/$N/serial.log" | tr -d '\r' | head -1 | cut -c1-90)"
  off "$N"
done
echo "== $c cycles with UseSimpledrm=0, core files at the end: $prev"
