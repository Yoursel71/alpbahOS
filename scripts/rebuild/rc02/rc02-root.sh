#!/bin/bash
# BETA-RC-02 (2026-11-12), run as root on the host. Release candidate 2 WITHOUT touching the live r4-root:
#   1. writable btrfs snapshot of r4-root: r4-snapshots/r4-rc02-2026-11-12
#   2. the rc01 changes, with rc01's own script (rc01-root.sh, SNAP/RC pointed at rc02 by RC01_SNAP/RC01_RC):
#      plymouth 037 patch, alp.py with ALP-LOCK-MSG-01, then (after the steps below) catalog and checks
#   3. protobuf 36.2 (protoc; abseil-cpp 20250512.1 built in as a CMake module, static, no network), recorded as
#      protobuf 36.2-alp1 -- netavark's build.rs needs protoc (tonic-prost-build) and r4-root has none
#   4. netavark 1.17.2 and aardvark-dns 1.17.1 (the 1.x line podman 5.8 works with; 2.x is for podman 6), tag
#      sources + upstream vendor tarballs, cargo --offline with the r4-root Rust (/opt/rustc 1.97.1), installed to
#      /usr/libexec/podman/{netavark,aardvark-dns}, ISA audit (D146), recorded as netavark-rc02 / aardvark-dns-rc02
# Usage: rc02-root.sh <step: snapshot|rc01|protobuf|netavark|aardvark|catalog|check>
set -euo pipefail
export LC_ALL=C
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=$(cd "$(dirname "$0")/../../.." && pwd)
SNAP=$SB/r4-snapshots/r4-rc02-2026-11-12
RC=$SB/rc02
DL=$RC/dl
LED=$RC/ledger
ALP=$WT/docs/handoffs/ai/alp-prototype/alp.py
LIB=$WT/scripts/rebuild/r4/r4_lib.py
REC=$WT/scripts/rebuild/r8/stage-record-r8.py
AUDIT=$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh
RC01=$WT/scripts/rebuild/rc01/rc01-root.sh
die() { echo "rc02-root: $*" >&2; exit 1; }
log() { echo "[rc02-root $(date +%T)] $*"; }
mkdir -p "$RC" "$LED"
[ "$(realpath -m "$SNAP")" != "$(realpath "$SB/r4-root")" ] || die "refusing the live r4-root"

record() { # <name> <version> <stage> [EXCLUDE...]  (same steps as rc01-root.sh / integrate-trust.sh record())
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
inchroot() { # <log> <script>  build in the snapshot (network not used: cargo --offline, FetchContent disconnected)
  chroot_mounts; set +e
  chroot "$SNAP" /usr/bin/env -i PATH=/opt/rustc/bin:/usr/bin:/usr/sbin:/bin:/sbin HOME=/root LC_ALL=C \
    CARGO_HOME=/tmp/cargo-home SOURCE_DATE_EPOCH=1762905600 sh -c "set -e; $2" > "$1" 2>&1
  local rc=$?; set -e; chroot_umounts; return $rc
}
fresh_build() { # <workdir> <build dirs inside the snapshot...>
  local w=$1 d; shift; [ ! -e "$w" ] || die "$w exists"; mkdir -p "$w"
  for d in "$@"; do [ ! -e "$SNAP$d" ] || die "$SNAP$d already exists"; done
}
audit() { # <stage> <workdir>
  set +e; "$AUDIT" "$1" > "$2/audit-isa.txt" 2>&1; local arc=$?; set -e
  log "ISA audit rc=$arc ($(tail -n 1 "$2/audit-isa.txt"))"; [ "$arc" = 0 ] || die "ISA audit failed"
}

step_snapshot() {
  [ ! -e "$SNAP" ] || die "$SNAP exists"
  findmnt -rn -o TARGET | grep -q "^$SB/r4-root" && die "something is mounted under r4-root (a writer is active)"
  ps -eo args | grep -q "^chroot $SB/r4-root" && die "a chroot of r4-root is running"
  btrfs subvolume snapshot "$SB/r4-root" "$SNAP" > /dev/null
  log "snapshot $SNAP of r4-root (r4-root db.json $(stat -c '%y' "$SB/r4-root/var/lib/alp/db.json" | cut -c1-19), $(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["packages"]))' "$SNAP/var/lib/alp/db.json") records)"
}

step_rc01() { # the rc01 changes with rc01's script, pointed at the rc02 snapshot and ledger
  RC01_SNAP=$SNAP RC01_RC=$RC bash "$RC01" plymouth
  RC01_SNAP=$SNAP RC01_RC=$RC bash "$RC01" alp
}

step_protobuf() {
  local W=$RC/build/protobuf B=/tmp/protobuf-36.2 A=/tmp/abseil-cpp-20250512.1 ST=/tmp/stage-protobuf
  fresh_build "$W" "$B" "$A" "$ST"
  (cd "$DL" && sha256sum protobuf-36.2.tar.gz abseil-cpp-20250512.1.tar.gz) | tee "$W/inputs.txt"
  tar -xzf "$DL/protobuf-36.2.tar.gz" -C "$SNAP/tmp"; tar -xzf "$DL/abseil-cpp-20250512.1.tar.gz" -C "$SNAP/tmp"
  if ! inchroot "$W/build.log" "cd $B && cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -Dprotobuf_BUILD_TESTS=OFF \
      -Dprotobuf_BUILD_CONFORMANCE=OFF -Dprotobuf_BUILD_EXAMPLES=OFF -Dprotobuf_INSTALL=ON -Dprotobuf_WITH_ZLIB=OFF \
      -DFETCHCONTENT_FULLY_DISCONNECTED=ON -DFETCHCONTENT_SOURCE_DIR_ABSL=$A -DABSL_PROPAGATE_CXX_STD=ON \
      && ninja -C build -j16 && DESTDIR=$ST ninja -C build install && $ST/usr/bin/protoc --version"; then
    rm -rf "${SNAP:?}$B" "${SNAP:?}$A" "${SNAP:?}$ST"; tail -n 30 "$W/build.log"; die "protobuf build failed"; fi
  log "protobuf build: $(tail -n 1 "$W/build.log")"
  cp -a "$SNAP$ST" "$W/stage"; rm -rf "${SNAP:?}$B" "${SNAP:?}$A" "${SNAP:?}$ST"
  audit "$W/stage" "$W"
  record protobuf 36.2-alp1 "$W/stage"
}

cargo_build() { # <name> <version> <tag-tarball> <vendor-tarball> <binary>
  local n=$1 v=$2 W=$RC/build/$1 B=/tmp/$1-$2 ST=/tmp/stage-$1
  fresh_build "$W" "$B" "$ST" /tmp/cargo-home
  (cd "$DL" && sha256sum "$3" "$4") | tee "$W/inputs.txt"
  tar -xzf "$DL/$3" -C "$SNAP/tmp"; tar -xzf "$DL/$4" -C "$SNAP$B"
  # vendored crates only: cargo is told to use $B/vendor instead of crates.io, and --offline/--locked
  if ! inchroot "$W/build.log" "cd $B && mkdir -p /tmp/cargo-home && printf '[source.crates-io]\nreplace-with = \"vendored-sources\"\n[source.vendored-sources]\ndirectory = \"$B/vendor\"\n' > /tmp/cargo-home/config.toml \
      && rustc --version && cargo --version && PROTOC=/usr/bin/protoc cargo build --release --offline --locked -j 16 \
      && install -D -m 0755 target/release/$5 $ST/usr/libexec/podman/$5 && $ST/usr/libexec/podman/$5 --version"; then
    rm -rf "${SNAP:?}$B" "${SNAP:?}$ST" "${SNAP:?}/tmp/cargo-home"; tail -n 30 "$W/build.log"; die "$n build failed"; fi
  log "$n build: $(tail -n 1 "$W/build.log")"
  cp -a "$SNAP$ST" "$W/stage"; rm -rf "${SNAP:?}$B" "${SNAP:?}$ST" "${SNAP:?}/tmp/cargo-home"
  audit "$W/stage" "$W"
  record "$n-rc02" "$v-alp1" "$W/stage"
}
step_netavark() { [ -x "$SNAP/usr/bin/protoc" ] || die "protoc missing (run the protobuf step)"
  cargo_build netavark 1.17.2 netavark-1.17.2.tar.gz netavark-v1.17.2-vendor.tar.gz netavark; }
step_aardvark() { cargo_build aardvark-dns 1.17.1 aardvark-dns-1.17.1.tar.gz aardvark-dns-v1.17.1-vendor.tar.gz aardvark-dns; }

step_catalog() { RC01_SNAP=$SNAP RC01_RC=$RC bash "$RC01" catalog; }
step_check() {
  RC01_SNAP=$SNAP RC01_RC=$RC bash "$RC01" check
  ls -la "$SNAP/usr/libexec/podman"
  python3 -c 'import json,sys; p=json.load(open(sys.argv[1]))["packages"]; print({k: p[k]["version"] for k in ("plymouth","alp-lockmsg-rc01","protobuf","netavark-rc02","aardvark-dns-rc02","alp-catalog") if k in p})' "$SNAP/var/lib/alp/db.json"
}

case "${1:-}" in
  snapshot|rc01|protobuf|netavark|aardvark|catalog|check) "step_$1" ;;
  *) die "usage: rc02-root.sh snapshot|rc01|protobuf|netavark|aardvark|catalog|check" ;;
esac
