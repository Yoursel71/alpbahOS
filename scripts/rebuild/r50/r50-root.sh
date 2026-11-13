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
# Usage: r50-root.sh <snapshot|remount|sddm|check|all>   (run as root, no chroot of r4-root may be active)
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
  snapshot|remount|sddm|check) "step_$1" ;;
  all) step_snapshot; step_remount; step_sddm; step_check ;;
  *) die "usage: r50-root.sh snapshot|remount|sddm|check|all" ;;
esac
