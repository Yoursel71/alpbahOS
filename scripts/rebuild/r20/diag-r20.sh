#!/bin/bash
# Round 20 text checks of an installed system (INSTALL-UID-01, NET-FW-01), without typing in the GUI.
# Makes a CoW copy of the installed raw image, adds a one-shot diagnostic unit to the COPY only (test instrumentation,
# not a fix: the product image is not changed), boots the copy under KVM -cpu qemu64, and reads the result from the
# serial log. The unit runs 90 s after graphical.target as root and writes to /dev/ttyS0 lines prefixed "R20DIAG".
# Also logs in at the greeter (password from test-secrets) and takes screenshots of the desktop and the network applet.
# Usage: diag-r20.sh <bios|uefi> <installed-raw> <run-name>     (sudo for the loop mount of the copy)
set -u
FW=$1; SRC=$2; NAME=$3
B=/home/yrslf/alpbahOS/scratch-lfs-bench
W=/home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/image
D=$B/lfs13-logs/iso-beta-0.9/r20
R=$D/$NAME; CP=$D/$NAME-copy.raw; M=$D/mnt-$NAME
PW=$(cat "$B/test-secrets/r20.pw")
rm -rf "$R"; [ ! -e "$CP" ] || { echo "$CP exists"; exit 2; }
cp --reflink=always "$SRC" "$CP"
LO=$(sudo losetup -f -P --show "$CP")
P=""; for p in "$LO"p*; do [ "$(sudo blkid -o value -s TYPE "$p")" = ext4 ] && P=$p; done
[ -n "$P" ] || { echo "no ext4 root in $CP"; sudo losetup -d "$LO"; exit 1; }
mkdir -p "$M"; sudo mount "$P" "$M"
sudo tee "$M/usr/local/sbin/r20-diag" > /dev/null << 'EOF'
#!/bin/sh
{
echo "R20DIAG begin $(date -Is)"
echo "R20DIAG id testuser: $(id testuser)"
echo "R20DIAG id -u testuser: $(id -u testuser)"
echo "R20DIAG getent passwd live: [$(getent passwd live)] group live: [$(getent group live)]"
echo "R20DIAG owner of /: $(stat -c %u:%g /)"
echo "R20DIAG is-active NetworkManager: $(systemctl is-active NetworkManager)"
for u in systemd-networkd.service systemd-networkd.socket systemd-networkd-varlink.socket systemd-networkd-resolve-hook.socket; do
  echo "R20DIAG is-active $u: $(systemctl is-active $u) enabled: $(systemctl is-enabled $u 2>&1)"
done
echo "R20DIAG is-active systemd-resolved: $(systemctl is-active systemd-resolved)"
nmcli -t device 2>&1 | sed 's/^/R20DIAG nmcli device: /'
resolvectl dns 2>&1 | sed 's/^/R20DIAG resolvectl dns: /'
echo "R20DIAG getent hosts kernel.org: $(getent hosts kernel.org | head -1)"
echo "R20DIAG curl http://kernel.org/: $(curl -sSI -m 20 http://kernel.org/ 2>&1 | head -1 | tr -d '\r')"
echo "R20DIAG curl https://www.kernel.org/: $(curl -sSI -m 20 https://www.kernel.org/ 2>&1 | head -1 | tr -d '\r')"
echo "R20DIAG wpa_supplicant: $(wpa_supplicant -v 2>&1 | head -1)"
echo "R20DIAG firmware files: $(find /usr/lib/firmware -type f | wc -l)"
echo "R20DIAG failed units: $(systemctl --failed --no-legend | wc -l)"
systemctl --failed --no-legend 2>&1 | sed 's/^/R20DIAG failed: /'
journalctl -b -p err --no-pager 2>&1 | tail -n 15 | sed 's/^/R20DIAG journal err: /'
echo "R20DIAG end"
} > /dev/ttyS0 2>&1
EOF
sudo chmod 755 "$M/usr/local/sbin/r20-diag"
sudo tee "$M/etc/systemd/system/r20-diag.service" > /dev/null << 'EOF'
[Unit]
Description=Round 20 diagnostic (test copy only)
After=graphical.target network-online.target
[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 90
ExecStart=/usr/local/sbin/r20-diag
[Install]
WantedBy=graphical.target
EOF
sudo mkdir -p "$M/etc/systemd/system/graphical.target.wants"
sudo ln -sf /etc/systemd/system/r20-diag.service "$M/etc/systemd/system/graphical.target.wants/r20-diag.service"
sudo umount "$M"; sudo losetup -d "$LO"; rmdir "$M"
Q="python3 $W/qmpctl.py $R"
ACCEL=kvm bash $W/vm-start.sh "$FW" "" "$R" "$CP" virtio 6G > /dev/null
sleep 95; $Q shot "$NAME-greeter"; $Q click 766 489; sleep 1; $Q text "$PW"; $Q key ret; sleep 60; $Q shot "$NAME-desktop"
$Q click 1061 772; sleep 4; $Q shot "$NAME-applet"
for i in $(seq 1 30); do grep -q "R20DIAG end" "$R/serial.log" 2>/dev/null && break; sleep 10; done
$Q quit; for i in $(seq 1 30); do pgrep -f "qemu-system.*$R/" > /dev/null || break; sleep 1; done
grep -a "R20DIAG" "$R/serial.log" | tr -d '\r' > "$D/diag-$NAME.txt"
rm -f "$CP"
cat "$D/diag-$NAME.txt"
