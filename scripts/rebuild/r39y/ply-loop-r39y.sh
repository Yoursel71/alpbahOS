#!/bin/bash
# PLY-CRASH-01 (round 39y): boot a reflink copy of the kept r39 BIOS install many times and catch the plymouthd
# SIGSEGV seen once in S1 (r39x). Test instrumentation, in the COPY only:
#   - r39y-plycore.service (very early, before plymouth-quit): prlimit --core=unlimited on the plymouthd that was
#     started in the initramfs (its RLIMIT_CORE is 0, so systemd-coredump said "Resource limits disable core dumping")
#   - /etc/sysctl.d/99-r39y-core.conf: kernel.core_pattern=/var/tmp/core.%e.%p.%t (a plain file: systemd-coredump
#     counted the initramfs process as PID 1, init.scope, and turned collection off)
#   - plymouth.debug on the kernel line of the copy's grub.cfg (/var/log/plymouth-debug.log)
#   - the r21m test shell (matrix-r21.sh mkcopy) for the per-boot check and the power-off
# Each cycle: fresh QEMU (KVM, -cpu qemu64, BIOS, virtio, 4G, intel-hda as in S1), wait for the test shell, read
# this boot's plymouthd lines and core files, power off. Stops after MAXCYC cycles or MAXMIN minutes.
# Usage: ply-loop-r39y.sh       env: MAXCYC (default 30), MAXMIN (default 80); needs the r39y env (env.sh)
set -u
. ./env.sh
RB=$MATRIX_WT/scripts/rebuild
MATRIX_LIB=1 . "$M"
CP=$D/PLY-disk.raw
MAXCYC=${MAXCYC:-30}; MAXMIN=${MAXMIN:-80}
fresh "$CP"
cmd_mkcopy bios PLY-disk
LO=$(sudo losetup -f -P --show "$CP"); MP=$(mktemp -d /tmp/r39y-ply.XXXX)
sudo mount "${LO}p1" "$MP"
sudo tee "$MP/usr/local/sbin/r39y-plycore" > /dev/null << 'EOS'
#!/bin/sh
for p in $(pgrep -x plymouthd); do
  prlimit --pid "$p" --core=unlimited:unlimited
  echo "R39Y plycore: plymouthd pid $p core limit $(prlimit --pid "$p" --core --noheadings --output SOFT,HARD | tr -s ' ') pattern $(cat /proc/sys/kernel/core_pattern) uptime $(cut -d' ' -f1 /proc/uptime)" > /dev/ttyS0
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
sudo umount "$MP"; sudo losetup -d "$LO"; rmdir "$MP"

T0=$(date +%s); c=0; crashes=0
while [ "$c" -lt "$MAXCYC" ] && [ $(( ($(date +%s) - T0) / 60 )) -lt "$MAXMIN" ]; do
  c=$((c + 1)); N=$(printf 'PLY-c%02d' "$c"); R=$D/$N
  gate 20 > /dev/null || { echo "cycle $c: gate timeout"; break; }
  EXTRA_ARGS="-device intel-hda -device hda-duplex" agent_start "$N" bios PLY-disk virtio 4G
  for i in $(seq 1 90); do grep -aq "R21M begin" "$R/serial.log" 2> /dev/null && break; sleep 2; done
  if ! grep -aq "R21M begin" "$R/serial.log"; then echo "cycle $c: no test shell after 180 s"; shot "$R" noshell; vmquit "$R"; continue; fi
  sleep 15
  OUT=$(python3 "$RB/r21/gsh.py" "$R" 30 'echo "boot $(cut -c1-8 /proc/sys/kernel/random/boot_id) segv=$(journalctl -b --no-pager | grep -c "plymouthd.*SEGV") ply_lines=$(journalctl -b --no-pager | grep -c -i plymouth) quit=$(systemctl show -p Result --value plymouth-quit.service) cores=$(ls /var/tmp/core.* 2>/dev/null | wc -l)"')
  echo "cycle $c ($N): $OUT | $(grep -a 'R39Y plycore' "$R/serial.log" | tr -d '\r' | head -1 | cut -c1-140)"
  case "$OUT" in *"segv=0"*) ;; *) crashes=$((crashes + 1)); echo "cycle $c: CRASH"; python3 "$RB/r21/gsh.py" "$R" 30 'journalctl -b --no-pager | grep -i -B3 -A6 "plymouthd.*SEGV"' > "$R/crash-journal.txt" 2>&1 ;; esac
  python3 "$RB/r21/gsh.py" "$R" 0 "systemctl poweroff"
  for i in $(seq 1 60); do alive "$R" || break; sleep 1; done
  alive "$R" && { echo "cycle $c: still running, QMP quit"; vmquit "$R"; }
done
echo "== $c cycles, $crashes with a plymouthd SIGSEGV in the journal, $(( ($(date +%s) - T0) / 60 )) min"
