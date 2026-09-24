#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Sed 4.9 isolated DESTDIR stage. Run as root on Builder,
# inside /mnt/lfs chroot. Do not run until the M04 GCC stage is complete.
# This script records a package manifest and compares it with both the stage
# and the rootfs; it never merges files into /mnt/lfs.

LFS=/mnt/lfs
RUN_ID=20260924-r1
GCC_RUN_ID=${GCC_RUN_ID:?Set GCC_RUN_ID to the completed GCC stage RUN_ID}
[[ "$GCC_RUN_ID" =~ ^[A-Za-z0-9._-]{1,48}$ ]] || { echo 'invalid GCC_RUN_ID' >&2; exit 2; }
PACKAGE=sed-4.9
BUILD=/mnt/lfs/build/${PACKAGE}-m04-${RUN_ID}
STAGE_HOST=/mnt/lfs/tmp/alp-m04-sed-stage-${RUN_ID}
STAGE_CHROOT=/tmp/alp-m04-sed-stage-${RUN_ID}
SOURCE=/mnt/lfs/sources/sed-4.9.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-sed-${RUN_ID}.log
MANIFEST=/mnt/lfs/tmp/alp-m04-sed-manifest-${RUN_ID}.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-sed-preflight-${RUN_ID}.log
STAGE_COMPARE=/mnt/lfs/tmp/alp-m04-sed-stage-compare-${RUN_ID}.log
ROOTFS_COMPARE=/mnt/lfs/tmp/alp-m04-sed-rootfs-compare-${RUN_ID}.log
GCC_STAGE_HOST=/mnt/lfs/tmp/alp-m04-gcc-stage-${GCC_RUN_ID}
GCC_MANIFEST=/mnt/lfs/tmp/alp-m04-gcc-15.2.0-manifest-${GCC_RUN_ID}.json
GCC_PREFLIGHT=/mnt/lfs/tmp/alp-m04-gcc-15.2.0-preflight-${GCC_RUN_ID}.log
GCC_LOG=/mnt/lfs/tmp/alp-logs/m04-gcc-15.2.0-stage-${GCC_RUN_ID}.log
GCC_SOURCE_SHA256=438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e
SOURCE_URL=https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz
# LFS 12.4-systemd Chapter 3 publishes this MD5. SHA-256 is recorded from the
# verified archive in the run log and manifest, rather than claimed as official.
EXPECTED_MD5=6aac9b2dbafcd5b7a67a8a9bcb8036c3
ALP_ENGINE_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
EMPTY_DB_SHA256=40a9bcde751533fc237fae2b7e5eaebbbfd5779f3069c09f0590c07be184f165

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL=${CAPTURE_TOOL:-$SCRIPT_DIR/capture-package-manifest.py}
COMPARE_TOOL=${COMPARE_TOOL:-$SCRIPT_DIR/compare-package-manifest.py}
MOUNTS=()
FINISHED=0

assert_no_lfs_mounts() {
  local output status
  if output=$(findmnt -rn -R "$LFS"); then
    echo "Refusing: mounts remain below $LFS: $output" >&2
    return 1
  else
    status=$?
  fi
  [[ $status -eq 1 ]] || {
    echo "Cannot verify mounts below $LFS (findmnt status $status)" >&2
    return 1
  }
}

assert_nbd_idle() {
  local mounts sources status pgrep_status devices device device_mounts device_regex='^/dev/nbd0(p[0-9]+)?$'
  [[ -b /dev/nbd0 ]] || { echo 'Cannot verify nbd0: block device is absent' >&2; return 1; }
  if [[ -e /sys/block/nbd0/pid ]]; then
    [[ -r /sys/block/nbd0/pid ]] || { echo 'Cannot read nbd0 pid sysfs attribute' >&2; return 1; }
    [[ -z $(tr -d '[:space:]' < /sys/block/nbd0/pid) ]] || { echo 'Refusing active nbd0 PID' >&2; return 1; }
  else
    [[ $(cat /sys/block/nbd0/size) == 0 ]] || { echo 'Refusing nbd0 with nonzero size (PID attribute absent)' >&2; return 1; }
  fi
  devices=$(lsblk -nrpo NAME /dev/nbd0) || { echo 'Cannot enumerate nbd0 and partition devices' >&2; return 1; }
  [[ -n "$devices" ]] || { echo 'lsblk returned no nbd0 device tree' >&2; return 1; }
  mounts=$(lsblk -nrpo NAME,MOUNTPOINTS /dev/nbd0) || { echo 'Cannot inspect nbd0 tree mountpoints' >&2; return 1; }
  [[ -z $(printf '%s\n' "$mounts" | awk 'NF > 1 {print $0}') ]] || { echo "Refusing mounted nbd0 tree device(s): $mounts" >&2; return 1; }
  while IFS= read -r device; do
    [[ "$device" =~ $device_regex ]] || { echo "Unexpected device in nbd0 tree: $device" >&2; return 1; }
    if device_mounts=$(findmnt -rn -S "$device"); then
      echo "Refusing mounted nbd0 descendant $device: $device_mounts" >&2
      return 1
    else
      status=$?
      [[ $status -eq 1 ]] || { echo "Cannot verify mounts for $device (findmnt status $status)" >&2; return 1; }
    fi
  done <<< "$devices"
  if pgrep -a qemu-nbd >/dev/null; then
    echo 'Refusing while qemu-nbd is running' >&2
    return 1
  else
    pgrep_status=$?
    [[ $pgrep_status -eq 1 ]] || { echo "Cannot inspect qemu-nbd state (pgrep status $pgrep_status)" >&2; return 1; }
  fi
  echo 'NBD_IDLE: verified'
}

assert_alp_and_empty_db() {
  [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_ENGINE_SHA256" ]]
  [[ $(sha256sum "$LFS/var/lib/alp/db.json" | awk '{print $1}') == "$EMPTY_DB_SHA256" ]]
  python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    db = json.load(stream)
if db.get("schema_version") != 1 or db.get("packages") != {}:
    raise SystemExit("expected pinned Alp engine and empty package database")
PY
}

assert_no_builder_images() {
  local images
  if images=$(find /tmp /mnt/lfs/tmp -maxdepth 3 -type f \
      \( -iname '*.vhdx' -o -iname '*.vhd' -o -iname '*.raw' \) -print 2>/dev/null); then
    [[ -z "$images" ]] || { echo "Refusing temporary disk image(s): $images" >&2; return 1; }
  else
    echo 'Cannot inspect Builder temporary directories for disk images' >&2
    return 1
  fi
}

assert_no_active_builds() {
  local process output status
  for process in make gmake ninja meson cmake cc1 cc1plus collect2 ld as ar ranlib qemu-nbd; do
    if output=$(pgrep -ax "$process" 2>&1); then
      echo "Refusing concurrent build or NBD process: $output" >&2
      return 1
    else
      status=$?
      [[ $status -eq 1 ]] || { echo "Cannot inspect $process process state (pgrep status $status): $output" >&2; return 1; }
    fi
  done
}

verify_completed_gcc_stage() {
  local gcc_manifest compare_status
  [[ $(hostname) == yrsk ]] || { echo "Refusing non-Builder host: $(hostname)" >&2; return 1; }
  [[ -d "$GCC_STAGE_HOST" && -x "$GCC_STAGE_HOST/usr/bin/gcc" && -x "$GCC_STAGE_HOST/usr/bin/g++" ]]
  [[ -s "$GCC_MANIFEST" && -s "$GCC_PREFLIGHT" && -s "$GCC_LOG" ]]
  grep -Fqx 'GCC_STAGE_MANIFEST_COMPARE_EXIT=0' "$GCC_PREFLIGHT"
  grep -Fqx "STAGE_OK: $GCC_STAGE_HOST" "$GCC_LOG"
  gcc_manifest=$(python3 - "$GCC_MANIFEST" "$GCC_SOURCE_SHA256" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    manifest = json.load(stream)
package = manifest.get("package", {})
source = package.get("source", {})
if (package.get("name"), package.get("version"), source.get("sha256")) != (
    "gcc", "15.2.0", sys.argv[2]
):
    raise SystemExit("GCC manifest identity/source hash does not match GCC 15.2.0")
print("GCC_MANIFEST_IDENTITY_OK")
PY
  )
  [[ "$gcc_manifest" == GCC_MANIFEST_IDENTITY_OK ]]
  if python3 "$COMPARE_TOOL" --manifest "$GCC_MANIFEST" --root "$GCC_STAGE_HOST"; then
    compare_status=0
  else
    compare_status=$?
  fi
  [[ $compare_status -eq 0 ]] || { echo "GCC stage/manifest comparison failed: $compare_status" >&2; return "$compare_status"; }
  echo "GCC_STAGE_GATE=passed run_id=$GCC_RUN_ID manifest=$GCC_MANIFEST stage=$GCC_STAGE_HOST"
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
[[ $(hostname) == yrsk ]] || { echo "Refusing non-Builder host: $(hostname)" >&2; exit 1; }
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" && ! -e "$STAGE_COMPARE" && ! -e "$ROOTFS_COMPARE" ]]
assert_no_lfs_mounts
assert_nbd_idle
assert_no_builder_images
assert_no_active_builds
assert_alp_and_empty_db
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
grep -q '^tester:.*:101:101:' "$LFS/etc/passwd"
for target in "$LFS/dev" "$LFS/dev/pts" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
  ! mountpoint -q "$target"
done
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 131072 ]]

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) run_id=$RUN_ID source_sha256=$(sha256sum "$SOURCE" | awk '{print $1}')"
echo "GCC_RUN_ID=$GCC_RUN_ID GCC_STAGE=$GCC_STAGE_HOST GCC_MANIFEST=$GCC_MANIFEST"
echo "source_md5=$(md5sum "$SOURCE" | awk '{print $1}') expected_lfs_md5=$EXPECTED_MD5"
echo 'Recipe=LFS 12.4-systemd Sed 4.9; tests=PATH=$PATH make check as tester; install_mode=DESTDIR; rootfs_merge=forbidden'
echo "ROOTFS_ALP_ENGINE_SHA256=$ALP_ENGINE_SHA256 ROOTFS_ALP_DB_SHA256=$EMPTY_DB_SHA256"
echo "AVAILABLE_KIB=$available_kib"
df -h "$LFS"
verify_completed_gcc_stage | tee -a "$PREFLIGHT"

mkdir -p "$BUILD" "$STAGE_HOST"
tar -xf "$SOURCE" -C "$BUILD" --strip-components=1
[[ -f "$BUILD/Makefile.in" && -f "$BUILD/doc/sed.x" ]]
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

# Follow LFS 8.31.1 exactly through configure, build, HTML generation, and
# tester-owned test suite. Installation is redirected entirely into DESTDIR.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
  HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    cd /build/sed-4.9-m04-20260924-r1
    ./configure --prefix=/usr
    make -j2
    make html
  '
chown -R 101:101 "$BUILD"
chroot "$LFS" /usr/bin/env -i \
  HOME=/home/tester TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    cd /build/sed-4.9-m04-20260924-r1
    su tester -c "PATH=\$PATH make check"
  '
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    cd /build/sed-4.9-m04-20260924-r1
    make DESTDIR=/tmp/alp-m04-sed-stage-20260924-r1 install
    install -d -m755 /tmp/alp-m04-sed-stage-20260924-r1/usr/share/doc/sed-4.9
    install -m644 doc/sed.html /tmp/alp-m04-sed-stage-20260924-r1/usr/share/doc/sed-4.9
  '

[[ -x "$STAGE_HOST/usr/bin/sed" && -s "$STAGE_HOST/usr/share/doc/sed-4.9/sed.html" ]]
smoke_output=$(printf 'alp staging smoke\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/sed" 's/staging/stage/; s/smoke/ok/')
[[ "$smoke_output" == 'alp stage ok' ]]
version_output=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/sed" --version | head -n 1)
[[ "$version_output" == "sed (GNU sed) 4.9" ]]
echo "SED_STAGE_SMOKE=$smoke_output"
echo "SED_STAGE_VERSION=$version_output"

assert_alp_and_empty_db
assert_nbd_idle
assert_no_builder_images
{
  echo "package=sed version=4.9 run_id=$RUN_ID"
  echo "source_url=$SOURCE_URL"
  echo "source_md5=$EXPECTED_MD5 (official LFS 12.4-systemd package list)"
  echo "source_sha256=$(sha256sum "$SOURCE" | awk '{print $1}') (measured after official MD5 verification)"
  echo "gcc_run_id=$GCC_RUN_ID gcc_stage=$GCC_STAGE_HOST gcc_manifest=$GCC_MANIFEST"
  echo "gcc_manifest_sha256=$(sha256sum "$GCC_MANIFEST" | awk '{print $1}')"
  echo "gcc_preflight_sha256=$(sha256sum "$GCC_PREFLIGHT" | awk '{print $1}')"
  echo "gcc_log_sha256=$(sha256sum "$GCC_LOG" | awk '{print $1}')"
  echo 'upstream_tests=PATH=$PATH make check, invoked as tester per LFS'
  echo "stage_smoke=$smoke_output"
  echo "stage_version=$version_output"
  echo "rootfs_alp_engine_sha256=$ALP_ENGINE_SHA256"
  echo "rootfs_alp_db_sha256=$EMPTY_DB_SHA256"
  echo 'install_mode=DESTDIR; rootfs_merge=forbidden'
} >> "$PREFLIGHT"

python3 "$CAPTURE_TOOL" \
  --stage "$STAGE_HOST" \
  --name sed \
  --version 4.9 \
  --source-url "$SOURCE_URL" \
  --source-sha256 "$(sha256sum "$SOURCE" | awk '{print $1}')" \
  --output "$MANIFEST" | tee -a "$PREFLIGHT"
chmod 0644 "$MANIFEST"

if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$STAGE_HOST" > "$STAGE_COMPARE" 2>&1; then
  stage_status=0
else
  stage_status=$?
fi
[[ $stage_status -eq 0 ]]
python3 - "$MANIFEST" "$STAGE_COMPARE" <<'PY' | tee -a "$PREFLIGHT"
import json, re, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    expected = len(json.load(stream)["entries"])
with open(sys.argv[2], encoding="utf-8") as stream:
    report = stream.read()
match = re.search(r"entries=(\d+) matched=(\d+) mismatched=(\d+)", report)
if not match:
    raise SystemExit("stage comparator summary missing")
entries, matched, mismatched = map(int, match.groups())
if entries != expected or matched != expected or mismatched != 0:
    raise SystemExit(f"stage manifest mismatch: expected={expected}, report={entries}/{matched}/{mismatched}")
print(f"STAGE_COMPARE_OK: entries={entries} matched={matched} mismatched=0")
PY

if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" > "$ROOTFS_COMPARE" 2>&1; then
  rootfs_status=0
else
  rootfs_status=$?
fi
case "$rootfs_status" in
  0) echo 'ROOTFS_PREFLIGHT=all staged paths match' | tee -a "$PREFLIGHT" ;;
  1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review before adoption' | tee -a "$PREFLIGHT" ;;
  *) echo "ROOTFS_PREFLIGHT=comparator error $rootfs_status" | tee -a "$PREFLIGHT"; exit "$rootfs_status" ;;
esac
{
  echo "ROOTFS_COMPARE_SHA256=$(sha256sum "$ROOTFS_COMPARE" | awk '{print $1}')"
  echo 'ROOTFS_COMPARE_REPORT_BEGIN'
  cat "$ROOTFS_COMPARE"
  echo 'ROOTFS_COMPARE_REPORT_END'
} | tee -a "$PREFLIGHT"
cat "$PREFLIGHT"
assert_alp_and_empty_db
assert_nbd_idle
assert_no_builder_images
assert_no_active_builds
FINISHED=1
