#!/bin/bash
# Round 49 (2026-11-13): root changes for the first round after the real-PC day (handoff 047), applied to the live
# r4-root (single writer). A read-only snapshot r4-snapshots/r4-before-r49 is taken first. Each step is one record:
#   alp        alp-r49: helpers/nvidia-stage.py now also writes the NVIDIA device-node tmpfiles rule (NVIDIA-DEVNODE-01)
#              and the SDDM Wayland drop-in (NVIDIA-SDDM-01); takes the helper over from alp-r41b
#   sddm       alpbahos-sddm-r49: /etc/sddm.conf without the explicit DisplayServer=x11 line (sddm defaults to x11), so
#              the nvidia package's /etc/sddm.conf.d drop-in can switch the greeter to Wayland
#   image      alpbahos-image-r49: /etc/profile.d/alpbahos-sbin.sh (PATH-SBIN-01), resolved LLMNR off (NET-EXPOSE-01)
#   kwrited    alpbahos-kwrited-r49: /usr/bin/kwrited mode 0755 instead of 4755 (SEC-KWRITED-01)
# Usage: r49-root.sh <snapshot|alp|sddm|image|kwrited|check|all>   (run as root, no chroot of r4-root may be active)
set -euo pipefail
export LC_ALL=C
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=$(cd "$(dirname "$0")/../../.." && pwd)
SNAP=$SB/r4-root
RO=$SB/r4-snapshots/r4-before-r49
RC=$SB/r49
LED=$SB/r4-ledger/r49
ALP=$WT/docs/handoffs/ai/alp-prototype/alp.py
LIB=$WT/scripts/rebuild/r4/r4_lib.py
REC=$WT/scripts/rebuild/r8/stage-record-r8.py
HELPER=$WT/docs/handoffs/ai/alp-prototype/helpers/nvidia-stage.py
die() { echo "r49-root: $*" >&2; exit 1; }
log() { echo "[r49-root $(date +%T)] $*"; }
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
step_alp() {
  local S; S=$(fresh alp); mkdir -p "$S/usr/lib/alp/helpers"
  install -m 755 "$HELPER" "$S/usr/lib/alp/helpers/nvidia-stage.py"
  record alp-r49 0.9-r49 "$S"
  cmp "$HELPER" "$SNAP/usr/lib/alp/helpers/nvidia-stage.py" && log "helper in r4-root equals the repo file"
}
step_sddm() {
  local S; S=$(fresh sddm); mkdir -p "$S/etc"
  grep -q '^DisplayServer=x11$' "$SNAP/etc/sddm.conf" || die "no DisplayServer=x11 line in /etc/sddm.conf"
  sed '/^DisplayServer=x11$/d' "$SNAP/etc/sddm.conf" > "$S/etc/sddm.conf"
  chmod --reference="$SNAP/etc/sddm.conf" "$S/etc/sddm.conf"; chown --reference="$SNAP/etc/sddm.conf" "$S/etc/sddm.conf"
  record alpbahos-sddm-r49 0.9-r49 "$S"
  ! grep -q '^DisplayServer' "$SNAP/etc/sddm.conf" && log "sddm.conf has no DisplayServer line"
}
step_image() {
  local S; S=$(fresh image); mkdir -p "$S/etc/profile.d" "$S/etc/systemd/resolved.conf.d"
  cat > "$S/etc/profile.d/alpbahos-sbin.sh" <<'EOF'
# alpbahOS (PATH-SBIN-01): ip, ss, rfkill, iptables live in /usr/sbin; a login shell needs it in PATH.
case ":$PATH:" in *:/usr/sbin:*) ;; *) PATH="$PATH:/usr/sbin" ;; esac
export PATH
EOF
  cat > "$S/etc/systemd/resolved.conf.d/10-alpbahos-llmnr.conf" <<'EOF'
# alpbahOS (NET-EXPOSE-01, decision 2026-11-13): no LLMNR listener on port 5355. Names on the LAN resolve through
# mDNS (nss-mdns, D176) and DNS.
[Resolve]
LLMNR=no
EOF
  chmod 644 "$S/etc/profile.d/alpbahos-sbin.sh" "$S/etc/systemd/resolved.conf.d/10-alpbahos-llmnr.conf"
  record alpbahos-image-r49 0.9-r49 "$S"
}
step_kwrited() {
  local S; S=$(fresh kwrited); mkdir -p "$S/usr/bin"
  install -m 755 "$SNAP/usr/bin/kwrited" "$S/usr/bin/kwrited"
  record alpbahos-kwrited-r49 0.9-r49 "$S"
  log "kwrited mode: $(stat -c %a "$SNAP/usr/bin/kwrited")"
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
  snapshot|alp|sddm|image|kwrited|check) "step_$1" ;;
  all) step_snapshot; step_alp; step_sddm; step_image; step_kwrited; step_check ;;
  *) die "usage: r49-root.sh snapshot|alp|sddm|image|kwrited|check|all" ;;
esac
