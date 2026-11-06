#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Psmisc 23.7 isolated DESTDIR stage after completed GCC
# and Sed stages. The Builder rootfs toolchain performs this build; GCC/Sed
# stages are prerequisite evidence only. Run as root on yrsk; never merge.
LFS=/mnt/lfs
RUN_ID=${RUN_ID:-20260924-r1}
[[ "$RUN_ID" =~ ^[A-Za-z0-9._-]{1,48}$ ]] || { echo 'invalid RUN_ID' >&2; exit 2; }
PACKAGE=psmisc-23.7
BUILD=$LFS/build/${PACKAGE}-m04-${RUN_ID}
STAGE_HOST=$LFS/tmp/alp-m04-psmisc-stage-${RUN_ID}
STAGE_CHROOT=/tmp/alp-m04-psmisc-stage-${RUN_ID}
SOURCE=$LFS/sources/psmisc-23.7.tar.xz
LOG=$LFS/tmp/alp-logs/m04-psmisc-${RUN_ID}.log
MANIFEST=$LFS/tmp/alp-m04-psmisc-manifest-${RUN_ID}.json
PREFLIGHT=$LFS/tmp/alp-m04-psmisc-preflight-${RUN_ID}.log
STAGE_COMPARE=$LFS/tmp/alp-m04-psmisc-stage-compare-${RUN_ID}.log
ROOTFS_COMPARE=$LFS/tmp/alp-m04-psmisc-rootfs-compare-${RUN_ID}.log
SOURCE_URL=https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-23.7.tar.xz
# Official LFS 12.4-systemd Chapter 3 checksum. SHA-256 is measured and
# recorded after this MD5 check because LFS does not publish a SHA-256 value.
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/psmisc.html
EXPECTED_MD5=53eae841735189a896d614cba440eb10
ALP_ENGINE_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
EMPTY_DB_SHA256=40a9bcde751533fc237fae2b7e5eaebbbfd5779f3069c09f0590c07be184f165
GCC_RUN_ID=${GCC_RUN_ID:?Set GCC_RUN_ID to the completed M04 GCC stage RUN_ID}
SED_RUN_ID=${SED_RUN_ID:?Set SED_RUN_ID to the completed M04 Sed stage RUN_ID}
[[ "$GCC_RUN_ID" =~ ^[A-Za-z0-9._-]{1,48}$ && "$SED_RUN_ID" =~ ^[A-Za-z0-9._-]{1,48}$ ]] || { echo 'invalid dependency RUN_ID' >&2; exit 2; }
GCC_STAGE=$LFS/tmp/alp-m04-gcc-stage-${GCC_RUN_ID}
GCC_MANIFEST=$LFS/tmp/alp-m04-gcc-15.2.0-manifest-${GCC_RUN_ID}.json
GCC_PREFLIGHT=$LFS/tmp/alp-m04-gcc-15.2.0-preflight-${GCC_RUN_ID}.log
GCC_LOG=$LFS/tmp/alp-logs/m04-gcc-15.2.0-stage-${GCC_RUN_ID}.log
SED_STAGE=$LFS/tmp/alp-m04-sed-stage-${SED_RUN_ID}
SED_MANIFEST=$LFS/tmp/alp-m04-sed-manifest-${SED_RUN_ID}.json
SED_PREFLIGHT=$LFS/tmp/alp-m04-sed-preflight-${SED_RUN_ID}.log
SED_LOG=$LFS/tmp/alp-logs/m04-sed-${SED_RUN_ID}.log
GCC_SOURCE_SHA256=438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL=$SCRIPT_DIR/capture-package-manifest.py
COMPARE_TOOL=$SCRIPT_DIR/compare-package-manifest.py
MOUNTS=()
FINISHED=0

assert_no_lfs_mounts() {
  local output status
  if output=$(findmnt -rn -R "$LFS"); then
    echo "Refusing: mounts remain below $LFS: $output" >&2; return 1
  else status=$?; fi
  [[ $status -eq 1 ]] || { echo "Cannot verify mounts below $LFS (findmnt status $status)" >&2; return 1; }
}

assert_nbd_idle() {
  local status devices device device_mounts mounts pgrep_status
  [[ -b /dev/nbd0 ]] || { echo 'Cannot verify nbd0: block device absent' >&2; return 1; }
  if [[ -e /sys/block/nbd0/pid ]]; then
    [[ -r /sys/block/nbd0/pid ]] || { echo 'Cannot read nbd0 PID attribute' >&2; return 1; }
    [[ -z $(tr -d '[:space:]' < /sys/block/nbd0/pid) ]] || { echo 'Refusing active nbd0 PID' >&2; return 1; }
  else
    [[ $(cat /sys/block/nbd0/size) == 0 ]] || { echo 'Refusing nbd0 with nonzero size and no PID attribute' >&2; return 1; }
  fi
  devices=$(lsblk -nrpo NAME /dev/nbd0) || { echo 'Cannot enumerate nbd0 descendants' >&2; return 1; }
  [[ -n "$devices" ]] || { echo 'lsblk returned an empty nbd0 tree' >&2; return 1; }
  mounts=$(lsblk -nrpo NAME,MOUNTPOINTS /dev/nbd0) || { echo 'Cannot inspect nbd0 tree mountpoints' >&2; return 1; }
  [[ -z $(printf '%s\n' "$mounts" | awk 'NF > 1 {print $0}') ]] || { echo "Refusing mounted nbd0 descendant(s): $mounts" >&2; return 1; }
  while IFS= read -r device; do
    [[ "$device" =~ ^/dev/nbd0(p[0-9]+)?$ ]] || { echo "Unexpected nbd0 tree device: $device" >&2; return 1; }
    if device_mounts=$(findmnt -rn -S "$device"); then
      echo "Refusing mounted nbd0 descendant $device: $device_mounts" >&2; return 1
    else
      status=$?
      [[ $status -eq 1 ]] || { echo "Cannot check mount for $device (findmnt status $status)" >&2; return 1; }
    fi
  done <<< "$devices"
  if pgrep -a qemu-nbd >/dev/null; then echo 'Refusing while qemu-nbd is running' >&2; return 1
  else pgrep_status=$?; [[ $pgrep_status -eq 1 ]] || { echo "Cannot inspect qemu-nbd (pgrep status $pgrep_status)" >&2; return 1; }; fi
  echo 'NBD_IDLE: verified'
}

assert_alp_and_empty_db() {
  [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_ENGINE_SHA256" ]]
  [[ $(sha256sum "$LFS/var/lib/alp/db.json" | awk '{print $1}') == "$EMPTY_DB_SHA256" ]]
  python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f: db = json.load(f)
if db.get("schema_version") != 1 or db.get("packages") != {}:
    raise SystemExit("expected pinned Alp engine and empty database")
PY
}

assert_no_images_and_builds() {
  local images process output status
  images=$(find /tmp "$LFS/tmp" -maxdepth 3 -type f \
    \( -iname '*.vhdx' -o -iname '*.vhd' -o -iname '*.raw' \) -print 2>/dev/null) || {
      echo 'Cannot inspect temporary directories for disk images' >&2; return 1; }
  [[ -z "$images" ]] || { echo "Refusing temporary image(s): $images" >&2; return 1; }
  for process in make gmake ninja meson cmake cc1 cc1plus collect2 ld as ar ranlib qemu-nbd; do
    if output=$(pgrep -ax "$process" 2>&1); then
      echo "Refusing concurrent build/NBD process: $output" >&2; return 1
    else
      status=$?
      [[ $status -eq 1 ]] || { echo "Cannot inspect process $process (pgrep $status): $output" >&2; return 1; }
    fi
  done
}

check_manifest() {
  local manifest=$1 root=$2 name=$3 version=$4 report=$5 status
  if python3 "$COMPARE_TOOL" --manifest "$manifest" --root "$root" > "$report" 2>&1; then status=0; else status=$?; fi
  [[ $status -eq 0 ]] || { echo "$name stage comparator failed: $status" >&2; cat "$report" >&2; return "$status"; }
  python3 - "$manifest" "$report" "$name" "$version" <<'PY'
import json, re, sys
m=json.load(open(sys.argv[1], encoding="utf-8")); report=open(sys.argv[2], encoding="utf-8").read()
p=m.get("package", {})
if (p.get("name"), p.get("version")) != (sys.argv[3], sys.argv[4]):
    raise SystemExit(f"unexpected dependency manifest identity: {p}")
match=re.search(r"entries=(\d+) matched=(\d+) mismatched=(\d+)", report)
if not match: raise SystemExit("dependency comparator summary missing")
entries, matched, mismatched=map(int, match.groups())
if entries != len(m["entries"]) or matched != entries or mismatched:
    raise SystemExit(f"dependency stage not exact: {entries}/{matched}/{mismatched}")
print(f"{sys.argv[3].upper()}_STAGE_MANIFEST_COMPARE_EXIT=0 entries={entries}")
PY
}

verify_prerequisites() {
  local gcc_identity sed_identity
  [[ $(hostname) == yrsk ]] || { echo "Refusing non-Builder host: $(hostname)" >&2; return 1; }
  [[ -d "$GCC_STAGE/usr/bin" && -x "$GCC_STAGE/usr/bin/gcc" && -x "$GCC_STAGE/usr/bin/g++" ]]
  [[ -s "$GCC_MANIFEST" && -s "$GCC_PREFLIGHT" && -s "$GCC_LOG" ]]
  grep -Fqx 'GCC_STAGE_MANIFEST_COMPARE_EXIT=0' "$GCC_PREFLIGHT"
  grep -Fqx "STAGE_OK: $GCC_STAGE" "$GCC_LOG"
  gcc_identity=$(python3 - "$GCC_MANIFEST" "$GCC_SOURCE_SHA256" <<'PY'
import json, sys
p=json.load(open(sys.argv[1], encoding="utf-8"))["package"]
if (p.get("name"), p.get("version"), p.get("source", {}).get("sha256")) != ("gcc", "15.2.0", sys.argv[2]):
    raise SystemExit("GCC manifest identity/source hash mismatch")
print("GCC_MANIFEST_IDENTITY_OK")
PY
  )
  [[ "$gcc_identity" == GCC_MANIFEST_IDENTITY_OK ]]
  check_manifest "$GCC_MANIFEST" "$GCC_STAGE" gcc 15.2.0 "$LFS/tmp/alp-m04-psmisc-gcc-compare-${RUN_ID}.log" | tee -a "$PREFLIGHT"

  [[ -d "$SED_STAGE/usr/bin" && -x "$SED_STAGE/usr/bin/sed" ]]
  [[ -s "$SED_MANIFEST" && -s "$SED_PREFLIGHT" && -s "$SED_LOG" ]]
  grep -Fqx "STAGE_OK: $SED_STAGE" "$SED_LOG"
  grep -Fqx 'source_md5=6aac9b2dbafcd5b7a67a8a9bcb8036c3 (official LFS 12.4-systemd package list)' "$SED_PREFLIGHT"
  grep -Eq '^STAGE_COMPARE_OK: entries=[0-9]+ matched=[0-9]+ mismatched=0$' "$SED_PREFLIGHT"
  sed_identity=$(python3 - "$SED_MANIFEST" "$SED_PREFLIGHT" <<'PY'
import json, sys
manifest=json.load(open(sys.argv[1], encoding="utf-8")); p=manifest["package"]
preflight=open(sys.argv[2], encoding="utf-8").read()
if (p.get("name"), p.get("version")) != ("sed", "4.9"):
    raise SystemExit("Sed manifest identity mismatch")
source_hash=p.get("source", {}).get("sha256")
if not source_hash or f"source_sha256={source_hash} " not in preflight:
    raise SystemExit("Sed manifest source hash is not tied to the completed preflight")
print("SED_MANIFEST_IDENTITY_OK")
PY
  )
  [[ "$sed_identity" == SED_MANIFEST_IDENTITY_OK ]]
  grep -Fq 'GCC_STAGE_MANIFEST_COMPARE_EXIT=0' "$SED_PREFLIGHT"
  check_manifest "$SED_MANIFEST" "$SED_STAGE" sed 4.9 "$LFS/tmp/alp-m04-psmisc-sed-compare-${RUN_ID}.log" | tee -a "$PREFLIGHT"
  echo "GCC_DEPENDENCY_MANIFEST_SHA256=$(sha256sum "$GCC_MANIFEST" | awk '{print $1}')" | tee -a "$PREFLIGHT"
  echo "SED_DEPENDENCY_MANIFEST_SHA256=$(sha256sum "$SED_MANIFEST" | awk '{print $1}')" | tee -a "$PREFLIGHT"
}

cleanup() {
  local status=$? i
  trap - EXIT
  set +e
  for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do
    umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
  done
  assert_no_lfs_mounts || status=1
  if (( FINISHED )) && (( status == 0 )); then
    echo "STAGE_OK: $STAGE_HOST"
    echo "MANIFEST: $MANIFEST"
    echo "PREFLIGHT: $PREFLIGHT"
  else
    echo 'STAGE_INCOMPLETE: preserve build/stage/log for diagnosis' >&2
    (( status != 0 )) || status=1
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

[[ $EUID -eq 0 && -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/gcc" && -f "$SOURCE" ]]
[[ "$ALP_ENGINE_SHA256" =~ ^[0-9a-f]{64}$ && "$EMPTY_DB_SHA256" =~ ^[0-9a-f]{64}$ ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" && ! -e "$STAGE_COMPARE" && ! -e "$ROOTFS_COMPARE" && ! -e "$LFS/tmp/alp-m04-psmisc-gcc-compare-${RUN_ID}.log" && ! -e "$LFS/tmp/alp-m04-psmisc-sed-compare-${RUN_ID}.log" ]]
assert_no_lfs_mounts
assert_nbd_idle
assert_no_images_and_builds
assert_alp_and_empty_db
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
for target in "$LFS/dev" "$LFS/dev/pts" "$LFS/proc" "$LFS/sys" "$LFS/run"; do ! mountpoint -q "$target"; done
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 131072 ]]

mkdir -p "$LFS/build" "$LFS/tmp/alp-logs"
exec > >(tee -a "$LOG") 2>&1
echo "package=psmisc version=23.7 run_id=$RUN_ID" > "$PREFLIGHT"
echo "Builder=$(hostname) run_id=$RUN_ID source_sha256=$(sha256sum "$SOURCE" | awk '{print $1}')"
echo "Recipe=LFS 12.4-systemd §8.32 Psmisc 23.7; tests=make check; build_toolchain=/mnt/lfs rootfs GCC; GCC/Sed stages=prerequisite evidence only; install_mode=DESTDIR; package_stage_only=true; rootfs_merge=forbidden"
echo "ROOTFS_ALP_ENGINE_SHA256=$ALP_ENGINE_SHA256 ROOTFS_ALP_DB_SHA256=$EMPTY_DB_SHA256 AVAILABLE_KIB=$available_kib"
df -h "$LFS"
verify_prerequisites

mkdir -p "$BUILD" "$STAGE_HOST"
tar -xf "$SOURCE" -C "$BUILD" --strip-components=1
[[ -f "$BUILD/configure" && -f "$BUILD/Makefile.in" ]]
chown -R 1001:1001 "$BUILD"

bind_mount() {
  local src=$1 dst=$2
  if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
  mount --bind "$src" "$dst"
  MOUNTS+=("$dst")
}
bind_mount /dev "$LFS/dev"
bind_mount /dev/pts "$LFS/dev/pts"
bind_mount /proc "$LFS/proc"
bind_mount /sys "$LFS/sys"
bind_mount /run "$LFS/run"

chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
  HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    cd /build/psmisc-23.7-m04-'"$RUN_ID"'
    ./configure --prefix=/usr
    make -j2
  '
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    cd /build/psmisc-23.7-m04-'"$RUN_ID"'
    make check
  '
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    cd /build/psmisc-23.7-m04-'"$RUN_ID"'
    make DESTDIR='"$STAGE_CHROOT"' install
  '

for program in fuser killall peekfd prtstat pslog pstree; do [[ -x "$STAGE_HOST/usr/bin/$program" ]]; done
[[ -L "$STAGE_HOST/usr/bin/pstree.x11" ]]
pstree_version=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/pstree" --version 2>&1 | head -n 1)
[[ "$pstree_version" == *23.7* ]]
pstree_smoke=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/pstree" -p 1)
[[ -n "$pstree_smoke" ]]
fuser_version=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/fuser" --version 2>&1 | head -n 1)
[[ "$fuser_version" == *23.7* ]]
echo "PSMISC_PSTREE_VERSION=$pstree_version"
echo "PSMISC_FUSER_VERSION=$fuser_version"
echo "PSMISC_PSTREE_SMOKE=$pstree_smoke"

assert_alp_and_empty_db
assert_nbd_idle
assert_no_images_and_builds
{
  echo "package=psmisc version=23.7 run_id=$RUN_ID"
  echo "source_url=$SOURCE_URL"
  echo "source_md5=$EXPECTED_MD5 (official LFS 12.4-systemd package list)"
  echo "source_sha256=$(sha256sum "$SOURCE" | awk '{print $1}') (measured after official MD5 verification)"
  echo "gcc_run_id=$GCC_RUN_ID gcc_manifest=$GCC_MANIFEST gcc_manifest_sha256=$(sha256sum "$GCC_MANIFEST" | awk '{print $1}')"
  echo "sed_run_id=$SED_RUN_ID sed_manifest=$SED_MANIFEST sed_manifest_sha256=$(sha256sum "$SED_MANIFEST" | awk '{print $1}')"
  echo 'upstream_tests=make check (LFS §8.32)'
  echo "pstree_version=$pstree_version"
  echo "fuser_version=$fuser_version"
  echo "pstree_smoke=$pstree_smoke"
  echo "rootfs_alp_engine_sha256=$ALP_ENGINE_SHA256"
  echo "rootfs_alp_db_sha256=$EMPTY_DB_SHA256"
  echo 'build_toolchain=/mnt/lfs rootfs GCC; GCC/Sed stages=prerequisite evidence only; install_mode=DESTDIR; package_stage_only=true; rootfs_merge=forbidden'
} >> "$PREFLIGHT"

python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name psmisc --version 23.7 \
  --source-url "$SOURCE_URL" --source-sha256 "$(sha256sum "$SOURCE" | awk '{print $1}')" \
  --output "$MANIFEST" | tee -a "$PREFLIGHT"
chmod 0644 "$MANIFEST"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$STAGE_HOST" > "$STAGE_COMPARE" 2>&1; then stage_status=0; else stage_status=$?; fi
[[ $stage_status -eq 0 ]]
python3 - "$MANIFEST" "$STAGE_COMPARE" <<'PY' | tee -a "$PREFLIGHT"
import json, re, sys
expected=len(json.load(open(sys.argv[1], encoding="utf-8"))["entries"])
report=open(sys.argv[2], encoding="utf-8").read()
m=re.search(r"entries=(\d+) matched=(\d+) mismatched=(\d+)", report)
if not m: raise SystemExit("stage comparator summary missing")
entries, matched, mismatched=map(int, m.groups())
if entries != expected or matched != expected or mismatched: raise SystemExit(f"stage manifest mismatch {entries}/{matched}/{mismatched}, expected {expected}")
print(f"STAGE_COMPARE_OK: entries={entries} matched={matched} mismatched=0")
PY
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" > "$ROOTFS_COMPARE" 2>&1; then rootfs_status=0; else rootfs_status=$?; fi
case "$rootfs_status" in
  0) echo 'ROOTFS_PREFLIGHT=all staged paths match' | tee -a "$PREFLIGHT" ;;
  1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review before adoption' | tee -a "$PREFLIGHT" ;;
  *) echo "ROOTFS_PREFLIGHT=comparator error $rootfs_status" | tee -a "$PREFLIGHT"; exit "$rootfs_status" ;;
esac
{
  echo "ROOTFS_COMPARE_SHA256=$(sha256sum "$ROOTFS_COMPARE" | awk '{print $1}')"
  echo 'ROOTFS_COMPARE_REPORT_BEGIN'; cat "$ROOTFS_COMPARE"; echo 'ROOTFS_COMPARE_REPORT_END'
} | tee -a "$PREFLIGHT"
cat "$PREFLIGHT"
assert_alp_and_empty_db
assert_nbd_idle
assert_no_images_and_builds
FINISHED=1
