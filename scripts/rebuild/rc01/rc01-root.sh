#!/bin/bash
# BETA-RC-01 (2026-11-12), run as root on the host. Makes the release-candidate root WITHOUT touching the live r4-root:
#   1. writable btrfs snapshot of r4-root: r4-snapshots/r4-rc01-2026-11-12 (r4-root is only read by the snapshot)
#   2. plymouth 26.134.222 + docs/handoffs/ai/patches/037-plymouth-keyboard-removed.patch, built in a chroot of
#      the snapshot with the original meson options (r10/plymouth/build.log), ISA audit (D146), recorded as
#      plymouth 26.134.222-alp1 (only the paths the old plymouth record owned; config files stay with their records)
#   3. alp.py of this worktree (with ALP-LOCK-MSG-01) recorded as alp-lockmsg-rc01 0.9-trust1.4 (takes alp.py over
#      from alp-kutu-r40b, the way the kutu records did)
#   4. catalog regenerated and re-signed (scripts/rebuild/trust/record-catalog.sh), alp check/list in a chroot,
#      iso-gate.sh --auto
# Usage: rc01-root.sh <step: snapshot|plymouth|alp|catalog|check|all>
set -euo pipefail
export LC_ALL=C
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=$(cd "$(dirname "$0")/../../.." && pwd)
SNAP=${RC01_SNAP:-$SB/r4-snapshots/r4-rc01-2026-11-12}   # RC01_SNAP, RC01_RC: reused by rc02-root.sh
RC=${RC01_RC:-$SB/rc01}
LED=$RC/ledger
ALP=$WT/docs/handoffs/ai/alp-prototype/alp.py
LIB=$WT/scripts/rebuild/r4/r4_lib.py
REC=$WT/scripts/rebuild/r8/stage-record-r8.py
PATCH=$WT/docs/handoffs/ai/patches/037-plymouth-keyboard-removed.patch
TARBALL=$SB/r10/dl/plymouth-26.134.222.tar.xz
OPTS="--prefix=/usr --buildtype=release -Db_lto=false -Dbackground-color=0x0b1014 -Dbackground-end-color-stop=0x0b1014 -Dbackground-start-color-stop=0x0b1014 -Ddocs=false -Dgtk=disabled -Drelease-file=/etc/os-release -Dsystemd-integration=true -Dtracing=false -Dudev=enabled -Dupstart-monitoring=false"
die() { echo "rc01-root: $*" >&2; exit 1; }
log() { echo "[rc01-root $(date +%T)] $*"; }
mkdir -p "$RC" "$LED"
[ "$(realpath -m "$SNAP")" != "$(realpath "$SB/r4-root")" ] || die "refusing the live r4-root"

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
chroot_mounts() { mount --bind /dev "$SNAP/dev"; mount -t proc proc "$SNAP/proc"; mount -t sysfs sys "$SNAP/sys"; mount -t tmpfs tmpfs "$SNAP/run"; }
chroot_umounts() { local t; for t in "$SNAP/run" "$SNAP/sys" "$SNAP/proc" "$SNAP/dev"; do
  mountpoint -q "$t" && { umount "$t" 2>/dev/null || umount -l "$t" 2>/dev/null || true; }; done
  echo "mounts left under the snapshot: $(findmnt -rn -o TARGET | grep -c "^$SNAP")"; }
trap chroot_umounts EXIT

step_snapshot() {
  [ ! -e "$SNAP" ] || die "$SNAP exists"
  findmnt -rn -o TARGET | grep -q "^$SB/r4-root" && die "something is mounted under r4-root (a writer is active)"
  pgrep -f "chroot $SB/r4-root" > /dev/null && die "a chroot of r4-root is running"
  btrfs subvolume snapshot "$SB/r4-root" "$SNAP" > /dev/null
  log "snapshot $SNAP of r4-root (r4-root db.json $(stat -c '%y' "$SB/r4-root/var/lib/alp/db.json" | cut -c1-19), $(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["packages"]))' "$SNAP/var/lib/alp/db.json") records)"
}

step_plymouth() {
  local B=/tmp/plymouth-26.134.222 ST=/tmp/stage-plymouth W=$RC/build/plymouth
  [ ! -e "$W" ] || die "$W exists"
  mkdir -p "$W"
  echo "tarball sha256 $(sha256sum "$TARBALL" | cut -d' ' -f1); patch sha256 $(sha256sum "$PATCH" | cut -d' ' -f1)" | tee "$W/inputs.txt"
  [ ! -e "$SNAP$B" ] && [ ! -e "$SNAP$ST" ] || die "build tree already in the snapshot"
  tar -xJf "$TARBALL" -C "$SNAP/tmp"; cp "$PATCH" "$SNAP/tmp/037.patch"
  chroot_mounts
  set +e
  chroot "$SNAP" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin HOME=/root LC_ALL=C sh -c \
    "set -e; cd $B && patch -Np1 -i /tmp/037.patch && meson setup build $OPTS && ninja -C build -j16 && DESTDIR=$ST ninja -C build install" > "$W/build.log" 2>&1
  local rc=$?; set -e
  chroot_umounts
  log "chroot build rc=$rc (log $W/build.log)"
  [ "$rc" = 0 ] || { rm -rf "$SNAP$B" "$SNAP$ST" "$SNAP/tmp/037.patch"; die "plymouth build failed"; }
  grep -n "keyboard_removed_handler (manager->event_handler_data, keyboard)" "$SNAP$B/src/libply-splash-core/ply-device-manager.c" | tee -a "$W/inputs.txt"
  cp -a "$SNAP$ST" "$W/stage"; rm -rf "$SNAP$B" "$SNAP$ST" "$SNAP/tmp/037.patch"
  set +e; "$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh" "$W/stage" > "$W/audit-isa.txt" 2>&1; local arc=$?; set -e
  log "ISA audit rc=$arc ($(tail -n 1 "$W/audit-isa.txt"))"
  [ "$arc" = 0 ] || die "ISA audit failed"
  # Only the paths the current plymouth record owns; everything else in the stage (config files owned by the
  # alpbahos-plymouth-* records, ...) is excluded so those records keep their files.
  python3 - "$SNAP/var/lib/alp/db.json" "$W/stage" "$W" << 'PY'
import json, os, sys
db, stage, w = sys.argv[1:4]
rec = json.load(open(db))["packages"]["plymouth"]
owned = set(rec.get("files", [])) | set(rec.get("symlinks", []))
staged = set()
for dp, dirs, names in os.walk(stage):
    for n in names + [d for d in dirs if os.path.islink(os.path.join(dp, d))]:
        staged.add(os.path.relpath(os.path.join(dp, n), stage))
excl = sorted(staged - owned); missing = sorted(owned - staged)
open(os.path.join(w, "exclude.txt"), "w").write("\n".join(excl) + ("\n" if excl else ""))
open(os.path.join(w, "owned-not-staged.txt"), "w").write("\n".join(missing) + ("\n" if missing else ""))
print(f"plymouth record owns {len(owned)} paths; staged {len(staged)}; excluded (not owned) {len(excl)}; owned but not staged {len(missing)}")
PY
  head -n 20 "$W/exclude.txt" | sed 's/^/   excluded: /'
  # shellcheck disable=SC2046
  record plymouth 26.134.222-alp1 "$W/stage" $(cat "$W/exclude.txt")
  log "installed libply-splash-core: $(sha256sum "$SNAP/usr/lib/libply-splash-core.so.5.0.0" | cut -c1-16)"
}

step_alp() {
  local S=$RC/build/alp-stage
  [ ! -e "$S" ] || die "$S exists"
  grep -q "verify_catalog_signature" "$ALP" || die "$ALP is not the signed-catalog alp"
  mkdir -p "$S/usr/lib/alp"; install -m 755 "$ALP" "$S/usr/lib/alp/alp.py"
  record alp-lockmsg-rc01 0.9-trust1.4 "$S"
  log "alp.py in the snapshot: $(sha256sum "$SNAP/usr/lib/alp/alp.py" | cut -c1-16) (repo $(sha256sum "$ALP" | cut -c1-16))"
}

step_catalog() { bash "$WT/scripts/rebuild/trust/record-catalog.sh" "$SNAP" "$LED"; }

step_check() {
  mount --bind /dev "$SNAP/dev"; mount -t proc proc "$SNAP/proc"
  for c in "check" "list" "search bash"; do
    set +e; out=$(chroot "$SNAP" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C python3 /usr/lib/alp/alp.py $c 2>&1); r=$?; set -e
    log "chroot alp $c: rc=$r, $(printf '%s\n' "$out" | wc -l) lines, $(printf '%s\n' "$out" | tail -n 1 | cut -c1-100)"
  done
  umount "$SNAP/proc"; umount "$SNAP/dev"
  bash "$WT/scripts/rebuild/trust/iso-gate.sh" --auto "$SNAP" && log "iso-gate --auto: PASS"
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); p=d["packages"]; print({k: p[k]["version"] for k in ("plymouth","alp-lockmsg-rc01","alp-kutu-r40b","alp-catalog") if k in p})' "$SNAP/var/lib/alp/db.json"
}

case "${1:-}" in
  snapshot|plymouth|alp|catalog|check) "step_$1" ;;
  all) step_snapshot; step_plymouth; step_alp; step_catalog; step_check ;;
  *) die "usage: rc01-root.sh snapshot|plymouth|alp|catalog|check|all" ;;
esac
