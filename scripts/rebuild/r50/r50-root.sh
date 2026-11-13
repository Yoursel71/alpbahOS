#!/bin/bash
# Round 50 (2026-11-13): root changes applied to the live r4-root (single writer). A read-only snapshot
# r4-snapshots/r4-before-r50 is taken first. Each step is one record:
#   remount    alpbahos-remount-r50: /etc/systemd/system/sysinit.target.wants/systemd-remount-fs.service (BOOT-RO-ROOT-01).
#              The installed system boots with root=UUID=... ro, but nothing pulled in systemd-remount-fs, so / stayed
#              read-only: no journal, no /etc/machine-id, sddm/logind units failed, the real PC froze after "Reached
#              Graphical Interface". Found by Codex 2026-11-13 on the real install (QEMU copy of the SSD), fixed there by
#              exactly this symlink; this record puts it in the image.
#   sddm       alpbahos-sddm-r50: /etc/sddm.conf without [Wayland] CompositorCommand=weston --shell=kiosk (SDDM-WESTON-01).
#              weston is not in the image and /etc/sddm.conf is read last, so it beat the nvidia drop-in's kwin_wayland
#              line: on the real PC the Wayland greeter failed ("Failed to start weston") and the screen stayed black.
#   rtkit-user alpbahos-rtkit-user-r50: system user/group rtkit (172) for rtkit-daemon (its D-Bus policy names it; systemd's
#              sysusers is built off here, so the account is written into /etc/passwd, group and shadow).
#   safegfx    alpbahos-safegfx-r50: SAFE-GFX-01, the "güvenli grafik" GRUB entry and the fallback to it after two unconfirmed
#              starts (/etc/grub.d/42_alpbahos_safe, alpbahos-boot-try/-ok and their units, wired by .wants links)
#   bootclean  alpbahos-bootclean-r50: errors of the real-PC boot journal (2026-11-13): udev rule calling the missing
#              /usr/lib/udev/tpm2_id (masked), pcspkr/snd_pcsp double registration (blacklisted), bluetooth.service
#              ConfigurationDirectoryMode (555 vs the 755 /etc/bluetooth), alpbahos-zram.service stop failing the unit at shutdown
#   desktopfix alpbahos-desktopfix-r50: AUDIO-WP-01 (the BLE MIDI monitor of WirePlumber is disabled: PipeWire has no bluez5/midi
#              SPA plugin) and CHROME-DECOR-01 (Flatpak Chrome gets the system title bar by default, via /etc/skel)
#   games      alpbahos-games-r50: GAMES-01, Steam and Bottles menu entries that install the Flathub app through alp on the
#              first start (D182; D129's native Steam is replaced by Flatpak Steam: multilib is not complete here)
#   grubroot   alpbahos-grub10-r50: GRUB-ROOT-01, /etc/grub.d/10_linux writes root=PARTUUID= (empty) for a root without a PARTUUID
#              (LUKS/dm-crypt: /dev/mapper/luks-...) when GRUB_DISABLE_LINUX_UUID=true; now falls back to the device path
# Usage: r50-root.sh <snapshot|remount|sddm|rtkit-user|safegfx|bootclean|desktopfix|games|grubroot|check|all>   (run as root, no chroot of r4-root may be active)
export LC_ALL=C
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=$(cd "$(dirname "$0")/../../.." && pwd)
SNAP=$SB/r4-root
RO=$SB/r4-snapshots/r4-before-r50
RC=$SB/r50
LED=$SB/r4-ledger/r50
ALP=$WT/docs/handoffs/ai/alp-prototype/alp.py
LIB=$WT/scripts/rebuild/r4/r4_lib.py
REC=$WT/scripts/rebuild/r8/stage-record-r8.py
HELPER=$WT/docs/handoffs/ai/alp-prototype/helpers/nvidia-stage.py
die() { echo "r50-root: $*" >&2; exit 1; }
log() { echo "[r50-root $(date +%T)] $*"; }
mkdir -p "$RC" "$LED"
record() { # <name> <version> <stage> [EXCLUDE...]  (same steps as integrate-trust.sh record())
  local name=$1 ver=$2 stage=$3; shift 3; local dir=$LED/$name man sha
  mkdir -p "$dir"
  REPLACE=1 python3 "$REC" "$SNAP" "$ALP" "$dir" "$stage" "$name" "$ver" "$@" > "$dir/record.log" 2>&1 || { cat "$dir/record.log"; die "record $name failed"; }
  man=$dir/manifest.json
  sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["package"]["source"]["sha256"])' "$man")
  python3 "$LIB" transfer --root "$SNAP" --alp "$ALP" --manifest "$man" --name "$name" --version "$ver" --log "$dir/transfers.tsv"
  python3 "$ALP" --root "$SNAP" adopt-base --manifest "$man" --name "$name" --version "$ver" --source-sha256 "$sha" > "$dir/adopt.log" 2>&1 \
    || { cat "$dir/adopt.log"; die "adopt-base $name failed"; }
  log "recorded $name $ver ($(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["entries"]))' "$man") entries); $(cat "$dir/adopt.log")"
}


step_snapshot() {
  [ ! -e "$RO" ] || die "$RO exists"
  findmnt -rn -o TARGET | grep -q "^$SNAP/" && die "something is mounted under r4-root (a writer is active)"
  pgrep -f "chroot $SNAP" > /dev/null && die "a chroot of r4-root is running"
  btrfs subvolume snapshot -r "$SNAP" "$RO" > /dev/null
  log "read-only snapshot $RO"
}
fresh() { local s=$RC/stage-$1; rm -rf "$s"; mkdir -p "$s"; echo "$s"; }
step_remount() {
  [ -f "$SNAP/usr/lib/systemd/system/systemd-remount-fs.service" ] || die "no systemd-remount-fs.service in r4-root"
  local S; S=$(fresh remount); mkdir -p "$S/etc/systemd/system/sysinit.target.wants"
  ln -s /usr/lib/systemd/system/systemd-remount-fs.service "$S/etc/systemd/system/sysinit.target.wants/systemd-remount-fs.service"
  record alpbahos-remount-r50 0.9-r50 "$S"
  [ "$(readlink "$SNAP/etc/systemd/system/sysinit.target.wants/systemd-remount-fs.service")" = /usr/lib/systemd/system/systemd-remount-fs.service ] \
    && log "remount-fs is wired into sysinit.target"
}
step_sddm() {
  local S; S=$(fresh sddm); mkdir -p "$S/etc"
  grep -q '^CompositorCommand=weston --shell=kiosk$' "$SNAP/etc/sddm.conf" || die "no weston CompositorCommand line in /etc/sddm.conf"
  sed '/^CompositorCommand=weston --shell=kiosk$/d' "$SNAP/etc/sddm.conf" > "$S/etc/sddm.conf"
  chmod --reference="$SNAP/etc/sddm.conf" "$S/etc/sddm.conf"; chown --reference="$SNAP/etc/sddm.conf" "$S/etc/sddm.conf"
  record alpbahos-sddm-r50 0.9-r50 "$S"
  ! grep -q '^CompositorCommand' "$SNAP/etc/sddm.conf" && log "sddm.conf has no CompositorCommand line"
}
step_rtkit_user() {
  local S; S=$(fresh rtkit-user); mkdir -p "$S/etc"
  grep -q '^rtkit:' "$SNAP/etc/passwd" && die "rtkit already in /etc/passwd"
  local f
  for f in passwd group shadow; do cp -p "$SNAP/etc/$f" "$S/etc/$f"; done
  echo 'rtkit:x:172:172:RealtimeKit:/proc:/usr/bin/false' >> "$S/etc/passwd"
  echo 'rtkit:x:172:' >> "$S/etc/group"
  echo 'rtkit:!:20000:0:99999:7:::' >> "$S/etc/shadow"
  record alpbahos-rtkit-user-r50 0.9-r50 "$S"
  grep -q '^rtkit:' "$SNAP/etc/passwd" && log "rtkit user is in r4-root /etc/passwd"
}
step_safegfx() {
  local S F; S=$(fresh safegfx); F=$WT/scripts/rebuild/r50/files
  mkdir -p "$S/etc/grub.d" "$S/usr/libexec/alpbahos" "$S/usr/lib/systemd/system/multi-user.target.wants" "$S/usr/lib/systemd/system/graphical.target.wants"
  install -m 755 "$F/42_alpbahos_safe" "$S/etc/grub.d/42_alpbahos_safe"
  install -m 755 "$F/alpbahos-boot-try" "$F/alpbahos-boot-ok" "$S/usr/libexec/alpbahos/"
  cat > "$S/usr/lib/systemd/system/alpbahos-boot-try.service" <<'EOF'
[Unit]
Description=alpbahOS start counter (safe graphics fallback)
Documentation=file:///etc/grub.d/42_alpbahos_safe
DefaultDependencies=no
After=local-fs.target
ConditionPathIsReadWrite=/boot/grub

[Service]
Type=oneshot
ExecStart=/usr/libexec/alpbahos/alpbahos-boot-try

[Install]
WantedBy=multi-user.target
EOF
  cat > "$S/usr/lib/systemd/system/alpbahos-boot-ok.service" <<'EOF'
[Unit]
Description=alpbahOS start confirmation (a graphical session stayed up)
After=display-manager.service systemd-logind.service
ConditionPathIsReadWrite=/boot/grub

[Service]
Type=simple
ExecStart=/usr/libexec/alpbahos/alpbahos-boot-ok

[Install]
WantedBy=graphical.target
EOF
  chmod 644 "$S"/usr/lib/systemd/system/alpbahos-boot-*.service
  ln -s ../alpbahos-boot-try.service "$S/usr/lib/systemd/system/multi-user.target.wants/alpbahos-boot-try.service"
  ln -s ../alpbahos-boot-ok.service "$S/usr/lib/systemd/system/graphical.target.wants/alpbahos-boot-ok.service"
  record alpbahos-safegfx-r50 0.9-r50 "$S"
  [ -L "$SNAP/usr/lib/systemd/system/graphical.target.wants/alpbahos-boot-ok.service" ] && log "boot-ok is wired into graphical.target"
}
step_bootclean() {
  local S; S=$(fresh bootclean)
  mkdir -p "$S/etc/udev/rules.d" "$S/etc/modprobe.d" "$S/etc/systemd/system/bluetooth.service.d" "$S/usr/libexec/alpbahos"
  # an empty file with the same name in /etc masks /usr/lib/udev/rules.d/60-tpm2-id.rules (tpm2_id is not built here)
  printf '# alpbahOS (BOOT-CLEAN-01): systemd is built without tpm2_id; masks 60-tpm2-id.rules, which calls it.\n' > "$S/etc/udev/rules.d/60-tpm2-id.rules"
  printf '# alpbahOS (BOOT-CLEAN-01): "Driver pcspkr is already registered, aborting" on the real PC; no PC speaker beeps wanted.\nblacklist pcspkr\nblacklist snd_pcsp\n' > "$S/etc/modprobe.d/alpbahos-pcspkr.conf"
  printf '# alpbahOS (BOOT-CLEAN-01): /etc/bluetooth is 755 here; the unit default 555 was logged as a mismatch at every boot.\n[Service]\nConfigurationDirectoryMode=0755\n' > "$S/etc/systemd/system/bluetooth.service.d/10-alpbahos-mode.conf"
  sed 's|swapoff "\$DEV" 2>/dev/null \|\| ! grep -q "^\$DEV " /proc/swaps \|\| { echo "swapoff \$DEV failed" >\&2; exit 1; }|swapoff "$DEV" 2>/dev/null \|\| ! grep -q "^$DEV " /proc/swaps \|\| echo "swapoff $DEV failed (systemd turns it off later at shutdown; not an error)" >\&2|' "$SNAP/usr/libexec/alpbahos/zram-swap" > "$S/usr/libexec/alpbahos/zram-swap"
  grep -q 'not an error)' "$S/usr/libexec/alpbahos/zram-swap" || die "zram-swap patch did not apply"
  chmod 755 "$S/usr/libexec/alpbahos/zram-swap"; chmod 644 "$S"/etc/udev/rules.d/60-tpm2-id.rules "$S"/etc/modprobe.d/alpbahos-pcspkr.conf "$S"/etc/systemd/system/bluetooth.service.d/10-alpbahos-mode.conf
  record alpbahos-bootclean-r50 0.9-r50 "$S"
  bash -n "$SNAP/usr/libexec/alpbahos/zram-swap" && log "bootclean recorded; zram-swap still parses"
}
step_desktopfix() {
  local S; S=$(fresh desktopfix)
  mkdir -p "$S/etc/wireplumber/wireplumber.conf.d" "$S/etc/skel/.var/app/com.google.Chrome/config/google-chrome/Default"
  cat > "$S/etc/wireplumber/wireplumber.conf.d/90-alpbahos-no-ble-midi.conf" <<'EOF'
# alpbahOS (AUDIO-WP-01): this PipeWire has no bluez5/midi SPA plugin, so the BLE MIDI monitor logged "can't create node"
# at every session start. Switched off until PipeWire is built with Bluetooth support.
wireplumber.profiles = {
  main = {
    monitor.bluez-midi = disabled
  }
}
EOF
  # Chrome (Flatpak) ignores the GTK decoration layout and draws a close-only frame; "Use system title bar and borders"
  # is the Preference browser.custom_chrome_frame=false. A new user's home starts with it.
  printf '{"browser":{"custom_chrome_frame":false}}\n' > "$S/etc/skel/.var/app/com.google.Chrome/config/google-chrome/Default/Preferences"
  chmod 644 "$S/etc/wireplumber/wireplumber.conf.d/90-alpbahos-no-ble-midi.conf" "$S/etc/skel/.var/app/com.google.Chrome/config/google-chrome/Default/Preferences"
  record alpbahos-desktopfix-r50 0.9-r50 "$S"
}
step_games() {
  local S F; S=$(fresh games); F=$WT/scripts/rebuild/r50/files
  mkdir -p "$S/usr/libexec/alpbahos" "$S/usr/share/applications"
  install -m 755 "$F/games-launch" "$S/usr/libexec/alpbahos/games-launch"
  cat > "$S/usr/share/applications/alpbahos-steam.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Steam
Comment=Game store and library (installs from Flathub on first start)
Comment[tr]=Oyun mağazası ve kütüphanesi (ilk açılışta Flathub'dan kurulur)
Exec=/usr/libexec/alpbahos/games-launch steam com.valvesoftware.Steam
Icon=applications-games
Terminal=true
Categories=Game;
Keywords=steam;game;oyun;
EOF
  cat > "$S/usr/share/applications/alpbahos-bottles.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Bottles
Comment=Run Windows programs and games (installs from Flathub on first start)
Comment[tr]=Windows programları ve oyunları çalıştır (ilk açılışta Flathub'dan kurulur)
Exec=/usr/libexec/alpbahos/games-launch bottles com.usebottles.bottles
Icon=wine
Terminal=true
Categories=Utility;Game;
Keywords=wine;windows;exe;bottles;
EOF
  chmod 644 "$S"/usr/share/applications/alpbahos-*.desktop
  record alpbahos-games-r50 0.9-r50 "$S"
}
step_grubroot() {
  local S F; S=$(fresh grubroot); F=$SNAP/etc/grub.d/10_linux; mkdir -p "$S/etc/grub.d"
  grep -q '^elif \[ "x${GRUB_DEVICE_UUID}" = "x" \]' "$F" || die "10_linux layout changed: the elif line was not found"
  python3 - "$F" "$S/etc/grub.d/10_linux" <<'PY'
import sys
s = open(sys.argv[1]).read()
old = 'elif [ "x${GRUB_DEVICE_UUID}" = "x" ] \\\n    || [ "x${GRUB_DISABLE_LINUX_UUID}" = "xtrue" ]; then\n  LINUX_ROOT_DEVICE=PARTUUID=${GRUB_DEVICE_PARTUUID}'
new = '# alpbahOS (GRUB-ROOT-01): a root without a PARTUUID (dm-crypt, /dev/mapper/luks-...) must not get an empty "root=PARTUUID="\nelif [ "x${GRUB_DEVICE_PARTUUID}" = "x" ] && [ "x${GRUB_DISABLE_LINUX_UUID}" = "xtrue" ]; then\n  LINUX_ROOT_DEVICE=${GRUB_DEVICE}\n' + old
assert s.count(old) == 1, "pattern not found exactly once"
open(sys.argv[2], "w").write(s.replace(old, new))
PY
  chmod --reference="$F" "$S/etc/grub.d/10_linux"; chown --reference="$F" "$S/etc/grub.d/10_linux"; bash -n "$S/etc/grub.d/10_linux" || die "patched 10_linux does not parse"
  record alpbahos-grub10-r50 0.9-r50 "$S"
  grep -q 'GRUB-ROOT-01' "$SNAP/etc/grub.d/10_linux" && log "10_linux patched in r4-root"
}
step_check() {
  mount --bind /dev "$SNAP/dev"; mount -t proc proc "$SNAP/proc"
  for c in "check" "list"; do
    set +e; out=$(chroot "$SNAP" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C python3 /usr/lib/alp/alp.py $c 2>&1); r=$?; set -e
    log "chroot alp $c: rc=$r, $(printf '%s\n' "$out" | tail -n 1 | cut -c1-100)"
  done
  umount "$SNAP/proc"; umount "$SNAP/dev"
  bash "$WT/scripts/rebuild/trust/iso-gate.sh" --auto "$SNAP" && log "iso-gate --auto: PASS"
}
case "${1:-}" in
  snapshot|remount|sddm|rtkit-user|safegfx|bootclean|desktopfix|games|grubroot|check) "step_${1//-/_}" ;;
  all) step_snapshot; step_remount; step_sddm; step_rtkit_user; step_safegfx; step_bootclean; step_desktopfix; step_games; step_grubroot; step_check ;;
  *) die "usage: r50-root.sh snapshot|remount|sddm|rtkit-user|safegfx|bootclean|desktopfix|games|grubroot|check|all" ;;
esac
