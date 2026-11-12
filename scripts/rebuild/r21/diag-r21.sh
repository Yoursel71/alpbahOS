#!/bin/bash
# Round 21 text checks of an installed system (SUDO-01, ZRAM-01, FIREWALL-01, LOCALE-DEFAULT-01, PERF-01, and the
# round 20 rows again), without typing in the GUI. Same method as scripts/rebuild/r20/diag-r20.sh: a CoW copy of the
# installed raw image gets a one-shot diagnostic unit (test instrumentation on the copy only; the copy is deleted),
# the copy boots under KVM -cpu qemu64, results come from the serial log (lines "R21DIAG").
# Inbound probe: QEMU forwards host 127.0.0.1:$PORT to guest port 8080, where the guest runs a small HTTP server.
#   Windows are 120 s each (the host probes up to about 60 s after the window opens). The probe runs after the
#   test user's session is up, so the host side (busy with the greeter login until then)
#   is already waiting for it (the first version ran it earlier and both host probes came after the windows).
#   probe 1 with the firewall on (expected: no HTTP answer), probe 2 with the firewall stopped (expected: HTTP 200,
#   the control), then the firewall is started again. The host side waits for the guest's "probe-N-ready" line.
# The guest also: logs the test user in at the greeter (screenshots), measures idle memory 5 minutes after login
#   (profiles/perf/collect_session_metrics.py, PERF-01 method step 3), checks sudo -v for the first user (right and
#   wrong password) and for a new user outside wheel, and with FLATPAK=1 installs org.gnome.Calculator from Flathub.
# Usage: diag-r21.sh <bios|uefi> <installed-raw> <run-name>      env: FLATPAK=1, NIC_NONE=1 (no network, no probe),
#   MEM (guest RAM, default 6G; 4G for the PERF-01 target class)
# Round 21 matrix additions (defaults unchanged): BUS (virtio|sata|nvme, default virtio), OUTD (output directory;
#   when set, an existing run directory or result file is refused instead of removed), DIAG_HOOK (host file that is
#   installed in the copy and run by the diagnostic before the failed-units line; its output comes as
#   "R21DIAG hook:" lines). EXTRA_ARGS and NVME_BOOTINDEX go to vm-start.sh through the environment.
set -u
FW=$1; SRC=$2; NAME=$3
B=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=${MATRIX_WT:-/home/yrslf/alpbahOS/wt-t2-kisayol}
W=$WT/scripts/rebuild/image
D=${OUTD:-$B/lfs13-logs/iso-beta-0.9/r21}
R=$D/$NAME; CP=$D/$NAME-copy.raw; M=$D/mnt-$NAME
PW=$(cat "${DIAG_PWF:-$B/test-secrets/r21.pw}")   # DIAG_PWF: password file of the installs under test
PORT=$((18080 + RANDOM % 1000))
mkdir -p "$D"
if [ -n "${OUTD:-}" ]; then
  for e in "$R" "$M" "$D/diag-$NAME.txt" "$D/probe-$NAME.txt"; do [ ! -e "$e" ] || { echo "$e exists"; exit 2; }; done
else rm -rf "$R"; fi
[ ! -e "$CP" ] || { echo "$CP exists"; exit 2; }
cp --reflink=always "$SRC" "$CP"
LO=$(sudo losetup -f -P --show "$CP")
P=""; for p in "$LO"p*; do [ "$(sudo blkid -o value -s TYPE "$p")" = ext4 ] && P=$p; done
[ -n "$P" ] || { echo "no ext4 root in $CP"; sudo losetup -d "$LO"; rm -f "$CP"; exit 1; }
mkdir -p "$M"; sudo mount "$P" "$M"
sudo install -m 755 "$WT/profiles/perf/collect_session_metrics.py" "$M/usr/local/sbin/r21-collect-metrics"
# The password goes into the copy only (deleted at the end); it is never written to the serial log.
printf '%s\n' "$PW" | sudo tee "$M/root/.r21-pw" > /dev/null; sudo chmod 600 "$M/root/.r21-pw"
echo "${FLATPAK:-0} ${NIC_NONE:-0}" | sudo tee "$M/root/.r21-mode" > /dev/null
# Round 45: no automatic screen lock during the idle wait of this copy (round 44 B1 locked at the 5 minute mark and
# kscreenlocker_greet, 318 MiB, was counted as idle memory). Test copy only; installed systems keep the KDE default.
if [ -d "$M/home/testuser" ] && ! sudo grep -qs '^Autolock=' "$M/home/testuser/.config/kscreenlockerrc"; then
  sudo install -d -o 1000 -g 1000 "$M/home/testuser/.config"
  printf '\n[Daemon]\nAutolock=false\n' | sudo tee -a "$M/home/testuser/.config/kscreenlockerrc" > /dev/null
  sudo chown 1000:1000 "$M/home/testuser/.config/kscreenlockerrc"
fi
[ -z "${DIAG_HOOK:-}" ] || sudo install -m 755 "$DIAG_HOOK" "$M/usr/local/sbin/r21-diag-hook"
sudo tee "$M/usr/local/sbin/r21-diag" > /dev/null << 'EOF'
#!/bin/sh
O=/dev/ttyS0
say() { echo "R21DIAG $*" > $O; }
read FLATPAK NONET < /root/.r21-mode
say "begin $(date -Is)"
say "id testuser: $(id testuser)"
say "getent passwd live: [$(getent passwd live)]; owner of /: $(stat -c %u:%g /)"
say "localtime: $(readlink /etc/localtime); $(grep -E '^(LANG|LC_TIME)=' /etc/locale.conf | tr '\n' ' ')"
say "boot: $(systemd-analyze 2>&1 | head -1); graphical.target: $(systemd-analyze 2>&1 | grep -o 'graphical.target reached after [^ ]*')"
say "wait-online: $(systemctl is-active NetworkManager-wait-online) ($(systemctl show -p Result --value NetworkManager-wait-online)); network-online.target: $(systemctl is-active network-online.target)"
for u in NetworkManager systemd-networkd systemd-resolved alpbahos-firewall alpbahos-zram; do
  say "is-active $u: $(systemctl is-active $u)"
done
say "swapon: $(swapon --noheadings --raw --show=NAME,TYPE,SIZE,PRIO | tr '\n' ' ')"
say "zramctl: $(zramctl --noheadings --raw --output NAME,ALGORITHM,DISKSIZE | tr '\n' ' ')"
say "iptables INPUT policy: $(iptables -S INPUT | head -1); rules: $(iptables -S INPUT | wc -l); ip6tables: $(ip6tables -S INPUT | head -1)"
nmcli -t device 2>&1 | while read -r l; do say "nmcli device: $l"; done
say "resolvectl dns: $(resolvectl dns 2>&1 | tr '\n' ' ')"
if [ "$NONET" = 0 ]; then
  say "curl https://www.kernel.org/: $(curl -sSI -m 20 https://www.kernel.org/ 2>&1 | head -1 | tr -d '\r')"
fi
# sudo: first user with the right and a wrong password, and a user outside wheel.
PW=$(cat /root/.r21-pw)
su - testuser -c "printf '%s\n' '$PW' | sudo -S -k -v" > /tmp/s1.out 2>&1; R1=$?
su - testuser -c "printf 'wrong-password\n' | sudo -S -k -v" > /tmp/s2.out 2>&1; R2=$?
useradd -m -s /bin/bash r21nowheel; echo 'r21nowheel:R21-nowheel-pw' | chpasswd
su - r21nowheel -c "printf 'R21-nowheel-pw\n' | sudo -S -k -v" > /tmp/s3.out 2>&1; R3=$?
say "sudo -v testuser right password: rc=$R1"
say "sudo -v testuser wrong password: rc=$R2 ($(grep -v '^\[sudo\]' /tmp/s2.out | tail -1))"
say "sudo -v r21nowheel (not in wheel): rc=$R3 ($(tail -1 /tmp/s3.out | sed 's/.*password for r21nowheel: //'))"
userdel -r r21nowheel 2>/dev/null
say "visudo -c: $(visudo -c 2>&1 | tr '\n' ' ')"
# PERF-01 idle memory: 5 minutes after the test user's session started (plasmashell running).
for i in $(seq 1 60); do pgrep -u testuser plasmashell > /dev/null && break; sleep 5; done
say "session up: $(pgrep -u testuser plasmashell > /dev/null && echo yes || echo no)"
if [ "$NONET" = 0 ]; then
  # Inbound probe (host side in diag-r21.sh).
  python3 -m http.server --bind 0.0.0.0 8080 > /dev/null 2>&1 &
  HP=$!; sleep 3
  say "probe setup: addr $(ip -4 -br addr show | tr -s ' ' | tr '\n' ';') listen $(ss -ltnH 'sport = :8080' | tr -s ' ' | tr '\n' ';') local curl $(curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/)"
  iptables -Z INPUT
  say "probe-1-ready (firewall $(systemctl is-active alpbahos-firewall))"; sleep 120
  say "probe-1 counters: $(iptables -nvxL INPUT | head -1) | tcp 8080 conntrack: $(grep -c 'dport=8080' /proc/net/nf_conntrack 2>/dev/null)"
  systemctl stop alpbahos-firewall
  say "probe-2-ready (firewall $(systemctl is-active alpbahos-firewall), policy $(iptables -S INPUT | head -1))"; sleep 120
  systemctl start alpbahos-firewall
  say "probe-done (firewall $(systemctl is-active alpbahos-firewall), policy $(iptables -S INPUT | head -1))"
  kill $HP
fi
say "waiting 300 s idle"
sleep 300
/usr/local/sbin/r21-collect-metrics --label r21-idle --uid "$(id -u testuser)" --home /home/testuser --no-dbus --out /root/r21-perf.json > /dev/null 2>&1
say "perf: $(python3 -c 'import json; d=json.load(open("/root/r21-perf.json"))["memory"]; print(" ".join(f"{k}={v}" for k,v in d.items()))' 2>&1)"
say "free -m: $(free -m | tr -s ' ' | tr '\n' ';')"
# round 43: the largest processes at the idle point (round 42 B2 was 1098.8 MiB against 934 in r39: no list to see why)
say "top rss: $(ps -eo rss=,comm= --sort=-rss | head -n 12 | awk '{printf "%s %d MiB; ", $2, $1/1024}')"
say "slab/shmem: $(grep -E '^(Shmem|Slab|SUnreclaim):' /proc/meminfo | tr -s ' ' | tr '\n' ';')"
if [ "$FLATPAK" = 1 ]; then
  flatpak install -y --noninteractive flathub org.gnome.Calculator > /tmp/fp.out 2>&1; FR=$?
  say "flatpak install org.gnome.Calculator: rc=$FR; $(tail -1 /tmp/fp.out)"
  say "flatpak list: $(flatpak list --app --columns=application 2>&1 | tr '\n' ' ')"
fi
[ -x /usr/local/sbin/r21-diag-hook ] && /usr/local/sbin/r21-diag-hook 2>&1 | while read -r l; do say "hook: $l"; done
say "failed units: $(systemctl --failed --no-legend | wc -l)"
systemctl --failed --no-legend 2>&1 | while read -r l; do say "failed: $l"; done
journalctl -b -p err --no-pager 2>&1 | tail -n 15 | while read -r l; do say "journal err: $l"; done
rm -f /root/.r21-pw
say "end"
EOF
sudo chmod 755 "$M/usr/local/sbin/r21-diag"
sudo tee "$M/etc/systemd/system/r21-diag.service" > /dev/null << 'EOF'
[Unit]
Description=Round 21 diagnostic (test copy only)
After=graphical.target
[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 60
ExecStart=/usr/local/sbin/r21-diag
TimeoutStartSec=3600
[Install]
WantedBy=graphical.target
EOF
sudo mkdir -p "$M/etc/systemd/system/graphical.target.wants"
sudo ln -sf /etc/systemd/system/r21-diag.service "$M/etc/systemd/system/graphical.target.wants/r21-diag.service"
sudo umount "$M"; sudo losetup -d "$LO"; rmdir "$M"
if [ "${NIC_NONE:-0}" = 1 ]; then NICV=none; else NICV="user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:$PORT-:8080"; fi
Q="python3 $W/qmpctl.py $R"
NIC="$NICV" ACCEL=kvm bash $W/vm-start.sh "$FW" "" "$R" "$CP" "${BUS:-virtio}" "${MEM:-6G}" > /dev/null
sleep 95; $Q shot "$NAME-greeter"; $Q click 622 474; sleep 1; $Q text "$PW"; $Q key ret; sleep 60; $Q shot "$NAME-desktop"
if [ "${NIC_NONE:-0}" != 1 ]; then
  for n in 1 2; do
    for i in $(seq 1 60); do grep -aq "probe-$n-ready" "$R/serial.log" && break; sleep 5; done
    sleep 3
    OUT=$(curl -sS -m 10 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" 2>&1); RC=$?
    echo "host probe $n (127.0.0.1:$PORT -> guest 8080): curl rc=$RC http_code/err=$OUT" | tee -a "$D/probe-$NAME.txt"
  done
fi
for i in $(seq 1 120); do grep -aq "R21DIAG end" "$R/serial.log" 2>/dev/null && break; sleep 15; done
$Q shot "$NAME-end"; $Q quit; for i in $(seq 1 30); do pgrep -f "qemu-system.*$R/" > /dev/null || break; sleep 1; done
grep -a "R21DIAG" "$R/serial.log" | tr -d '\r' > "$D/diag-$NAME.txt"
rm -f "$CP"
cat "$D/diag-$NAME.txt" "$D/probe-$NAME.txt" 2>/dev/null
