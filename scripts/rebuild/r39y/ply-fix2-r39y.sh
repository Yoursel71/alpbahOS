#!/bin/bash
# PLY-FIX-02 (round 39y): build plymouth 26.134.222 with docs/handoffs/ai/patches/037-plymouth-keyboard-removed.patch
# inside a booted reflink copy of the kept r39 BIOS install (it has gcc, meson, ninja and the -dev files), put ONLY
# the patched libply-splash-core.so.5.0.0 on the copy, rebuild the initramfs with target-initramfs.sh, keep
# UseSimpledrm=1 (the original setting), then boot CYCLES times with the PLY core setup and count core files.
# The build uses the options of the original record (r10/plymouth/build.log, build-pkg-r10.sh meson branch) and the
# same build directory /tmp/plymouth-26.134.222, with a cleared environment. An unpatched build is made first and
# compared with the installed library (control for the build environment).
# Usage: ply-fix2-r39y.sh     env: CYCLES (default 30); needs the r39y env (env.sh); evidence in r39y/PLYFIX2/
set -u
. ./env.sh
RB=$MATRIX_WT/scripts/rebuild
PATCH=$MATRIX_WT/docs/handoffs/ai/patches/037-plymouth-keyboard-removed.patch
TARBALL=/home/yrslf/alpbahOS/scratch-lfs-bench/r10/dl/plymouth-26.134.222.tar.xz
export MATRIX_DIR=$MATRIX_DIR/PLYFIX2
MATRIX_LIB=1 . "$M"          # D is now r39y/PLYFIX2
CYCLES=${CYCLES:-30}
CP=$D/PLYFIX2-disk.raw
fresh "$CP"
[ -s "$PATCH" ] && [ -s "$TARBALL" ] || { echo "patch or tarball missing"; exit 1; }
echo "tarball sha256 $(sha256sum "$TARBALL" | cut -d' ' -f1); patch sha256 $(sha256sum "$PATCH" | cut -d' ' -f1)"
cmd_mkcopy bios PLYFIX2-disk
LO=$(sudo losetup -f -P --show "$CP"); MP=$(mktemp -d /tmp/r39y-fix2.XXXX)
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
sudo install -m 644 "$TARBALL" "$MP/root/plymouth-26.134.222.tar.xz"
sudo install -m 644 "$PATCH" "$MP/root/037.patch"
sudo install -m 755 "$RB/iso/live/target-initramfs.sh" "$MP/root/target-initramfs.sh"
sudo tee "$MP/root/plybuild.sh" > /dev/null << 'EOS'
#!/bin/bash
# runs as root in the test copy: unpatched build (control), patched build, install of the patched library only
set -e
E="env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin HOME=/root LC_ALL=C"
OPTS="--prefix=/usr --buildtype=release -Db_lto=false -Dbackground-color=0x0b1014 -Dbackground-end-color-stop=0x0b1014 -Dbackground-start-color-stop=0x0b1014 -Ddocs=false -Dgtk=disabled -Drelease-file=/etc/os-release -Dsystemd-integration=true -Dtracing=false -Dudev=enabled -Dupstart-monitoring=false"
cd /tmp; rm -rf plymouth-26.134.222; tar -xJf /root/plymouth-26.134.222.tar.xz; cd plymouth-26.134.222
$E meson setup build $OPTS > /root/meson.log 2>&1
$E ninja -C build -j4 > /root/ninja-1.log 2>&1
L=$(find build -name 'libply-splash-core.so.5.0.0' -type f | head -n 1)
echo "built: $L"
echo "unpatched build:   $(sha256sum "$L" | cut -c1-16)  $(stat -c %s "$L") bytes"
echo "installed library: $(sha256sum /usr/lib/libply-splash-core.so.5.0.0 | cut -c1-16)  $(stat -c %s /usr/lib/libply-splash-core.so.5.0.0) bytes"
patch -Np1 -i /root/037.patch
grep -n -A1 "keyboard_removed_handler (manager->event_handler_data, keyboard)" src/libply-splash-core/ply-device-manager.c
$E ninja -C build -j4 > /root/ninja-2.log 2>&1
echo "patched build:     $(sha256sum "$L" | cut -c1-16)  $(stat -c %s "$L") bytes"
cp -a /usr/lib/libply-splash-core.so.5.0.0 /root/libply-splash-core.so.5.0.0.orig
install -m 755 "$L" /usr/lib/libply-splash-core.so.5.0.0
echo "now installed:     $(sha256sum /usr/lib/libply-splash-core.so.5.0.0 | cut -c1-16)"
echo "plymouthd unchanged: $(sha256sum /usr/sbin/plymouthd | cut -c1-16); UseSimpledrm: $(grep ^UseSimpledrm /etc/plymouth/plymouthd.conf)"
sh /root/target-initramfs.sh > /root/ti.log 2>&1 && echo "target-initramfs rc=0" || { echo "target-initramfs FAILED"; tail -n 5 /root/ti.log; exit 1; }
I=$(ls /boot/initramfs-*.img)
echo "initramfs: $(stat -c %s "$I") bytes; its libply-splash-core: $(lsinitrd -f usr/lib/libply-splash-core.so.5.0.0 "$I" | sha256sum | cut -c1-16); conf: $(lsinitrd -f etc/plymouth/plymouthd.conf "$I" | grep ^UseSimpledrm)"
sync
EOS
sudo chmod 755 "$MP/root/plybuild.sh"
echo "grub: $(grep -m1 'linux.*vmlinuz' "$MP/boot/grub/grub.cfg")"
sudo umount "$MP"; sudo losetup -d "$LO"; rmdir "$MP"

shots() { local R=$1 P=$2 S=$3 T0 t; T0=$(cat "$R/t-start")
  while :; do t=$(( $(date +%s) - T0 )); [ "$t" -le "$S" ] || break; shot "$R" "$P-$(printf %02d "$t")s"; done; }
boot() { agent_start "$1" bios PLYFIX2-disk virtio 4G
  [ "${2:-}" = shots ] && shots "$D/$1" boot 25
  for i in $(seq 1 90); do grep -aq "R21M begin" "$D/$1/serial.log" 2> /dev/null && break; sleep 2; done
  grep -aq "R21M begin" "$D/$1/serial.log"; }
off() { python3 "$RB/r21/gsh.py" "$D/$1" 0 "systemctl poweroff"
  for i in $(seq 1 60); do alive "$D/$1" || break; sleep 1; done
  alive "$D/$1" && { echo "$1: power-off not done in 60 s, QMP quit"; vmquit "$D/$1"; }; return 0; }
export EXTRA_ARGS="-device intel-hda -device hda-duplex"

# ---- build boot: baseline screenshots (unpatched), build, install, initramfs ------------------------------
gate 20 > /dev/null || exit 1
boot FIX2-build shots || { echo "build boot: no test shell"; exit 1; }
sleep 10
python3 "$RB/r21/gsh.py" "$D/FIX2-build" 1500 'echo "build boot (unpatched): cores $(ls /var/tmp/core.* 2>/dev/null | wc -l)"; bash /root/plybuild.sh 2>&1; echo "plybuild rc=$?"'
off FIX2-build

# ---- cycles with the patched library ----------------------------------------------------------------------
c=0; prev=0
while [ "$c" -lt "$CYCLES" ]; do
  c=$((c + 1)); N=$(printf 'FIX2-c%02d' "$c")
  gate 20 > /dev/null || { echo "cycle $c: gate timeout"; break; }
  if [ "$c" -le 2 ]; then boot "$N" shots; else boot "$N"; fi || { echo "cycle $c: no test shell"; shot "$D/$N" noshell; vmquit "$D/$N"; continue; }
  sleep 15
  OUT=$(python3 "$RB/r21/gsh.py" "$D/$N" 30 'echo "boot $(cut -c1-8 /proc/sys/kernel/random/boot_id) cores=$(ls /var/tmp/core.* 2>/dev/null | wc -l) quit=$(systemctl show -p Result --value plymouth-quit.service) lib=$(sha256sum /usr/lib/libply-splash-core.so.5.0.0 | cut -c1-8) gpu=$(journalctl -b -k --no-pager -o short-monotonic | grep -m1 "Initialized virtio_gpu" | cut -c2-13) quitstart=$(journalctl -b --no-pager -o short-monotonic | grep -m1 "Starting Terminate Plymouth" | cut -c2-13) sddm=$(journalctl -b --no-pager -o short-monotonic | grep -m1 "Started Simple Desktop Display Manager" | cut -c2-13)"')
  now=$(printf '%s' "$OUT" | grep -o 'cores=[0-9]*' | cut -d= -f2)
  [ "${now:-0}" -gt "$prev" ] && echo "cycle $c: NEW CORE"
  prev=${now:-$prev}
  echo "cycle $c ($N): $OUT"
  off "$N"
done
echo "== $c cycles with the patched libply-splash-core, core files at the end: $prev"
