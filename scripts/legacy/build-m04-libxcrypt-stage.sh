#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Libxcrypt 4.4.38 isolated package stage; never merges rootfs.
LFS=/mnt/lfs
BUILD=/mnt/lfs/build/libxcrypt-4.4.38-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-libxcrypt-stage-r1
STAGE_CHROOT=/tmp/alp-m04-libxcrypt-stage-r1
SOURCE=/mnt/lfs/sources/libxcrypt-4.4.38.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-libxcrypt-4.4.38-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-m04-libxcrypt-4.4.38-manifest-20260924-r1.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-libxcrypt-4.4.38-preflight-20260924-r1.log
STAGE_COMPARE=/mnt/lfs/tmp/alp-m04-libxcrypt-4.4.38-stage-compare-20260924-r1.log
SOURCE_URL=https://github.com/besser82/libxcrypt/releases/download/v4.4.38/libxcrypt-4.4.38.tar.xz
# LFS package-list MD5 and upstream release SHA256SUMS sidecar.
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/libxcrypt.html
# https://github.com/besser82/libxcrypt/releases/download/v4.4.38/libxcrypt-4.4.38.tar.xz.sha256sum
EXPECTED_MD5=1796a5d20098e9dd9e3f576803c83000
EXPECTED_SHA256=80304b9c306ea799327f01d9a7549bdb28317789182631f1b54f4511b4206dd6
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
EMPTY_DB_SHA256=40a9bcde751533fc237fae2b7e5eaebbbfd5779f3069c09f0590c07be184f165
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL="$SCRIPT_DIR/capture-package-manifest.py"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"
TEST_VERIFY_TOOL="$SCRIPT_DIR/verify-libxcrypt-tests.py"
MOUNTS=(); FINISHED=0

assert_no_lfs_mounts() {
  local output status
  if output=$(findmnt -rn -R "$LFS"); then
    echo "Refusing: mounts remain below $LFS: $output" >&2
    return 1
  else
    status=$?
  fi
  [[ $status -eq 1 ]] || { echo "Cannot verify mounts below $LFS (findmnt status $status)" >&2; return 1; }
}

assert_alp_and_empty_db() {
  [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
  [[ $(sha256sum "$LFS/var/lib/alp/db.json" | awk '{print $1}') == "$EMPTY_DB_SHA256" ]]
  python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    db = json.load(f)
if db.get("schema_version") != 1 or db.get("packages") != {}:
    raise SystemExit("expected pinned Alp and empty package database")
PY
}

assert_nbd_idle() {
  local mounts sources status pgrep_status
  [[ -b /dev/nbd0 ]] || { echo 'Cannot verify nbd0: block device is absent' >&2; return 1; }
  if [[ -e /sys/block/nbd0/pid ]]; then
    [[ -r /sys/block/nbd0/pid ]] || { echo 'Cannot read nbd0 pid sysfs attribute' >&2; return 1; }
    [[ -z $(tr -d '[:space:]' < /sys/block/nbd0/pid) ]] || { echo 'Refusing active nbd0 PID' >&2; return 1; }
  else
    [[ $(cat /sys/block/nbd0/size) == 0 ]] || { echo 'Refusing nbd0 with nonzero size (PID sysfs attribute absent)' >&2; return 1; }
  fi
  mounts=$(lsblk -dn -o MOUNTPOINTS /dev/nbd0) || { echo 'Cannot inspect nbd0 mountpoints' >&2; return 1; }
  [[ -z $(printf '%s' "$mounts" | tr -d '[:space:]') ]] || { echo "Refusing nbd0 mountpoints: $mounts" >&2; return 1; }
  if sources=$(findmnt -rn -S /dev/nbd0); then
    echo "Refusing nbd0 source reported by findmnt: ${sources:-<empty output>}" >&2
    return 1
  else
    status=$?
    [[ $status -eq 1 ]] || { echo "Cannot verify nbd0 mount source (findmnt status $status)" >&2; return 1; }
  fi
  if pgrep -a qemu-nbd >/dev/null; then
    echo 'Refusing while qemu-nbd is running' >&2; return 1
  else
    pgrep_status=$?
    [[ $pgrep_status -eq 1 ]] || { echo "Cannot verify qemu-nbd process state (pgrep status $pgrep_status)" >&2; return 1; }
  fi
  echo 'NBD_IDLE: verified'
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
  else
    echo 'STAGE_INCOMPLETE: preserve files for diagnosis' >&2
    (( status != 0 )) || status=1
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

[[ $EUID -eq 0 && -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/passwd" && -f "$SOURCE" ]]
[[ "$ALP_SHA256" =~ ^[0-9a-f]{64}$ && "$EMPTY_DB_SHA256" =~ ^[0-9a-f]{64}$ ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" && -f "$TEST_VERIFY_TOOL" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" && ! -e "$STAGE_COMPARE" ]]
assert_no_lfs_mounts
assert_nbd_idle
for process in make ninja meson cmake; do
  if pgrep -x "$process" >/dev/null; then echo "Refusing concurrent build: $process" >&2; exit 1; else pgrep_status=$?; [[ $pgrep_status -eq 1 ]] || { echo "Cannot inspect process state for $process (pgrep status $pgrep_status)" >&2; exit 1; }; fi
done
if temp_images=$(find /tmp /mnt/lfs/tmp -maxdepth 3 -type f \( -iname '*.vhdx' -o -iname '*.vhd' -o -iname '*.raw' \)); then
  [[ -z "$temp_images" ]] || { echo "Refusing to start while an image is present in a temporary directory: $temp_images" >&2; exit 1; }
else
  echo 'Cannot inspect temporary directories for disk images' >&2; exit 1
fi
assert_alp_and_empty_db
PASSWD_DB_SHA256=$(sha256sum "$LFS/etc/passwd" | awk '{print $1}')
SHADOW_DB_SHA256=$(sha256sum "$LFS/etc/shadow" | awk '{print $1}')
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 524288 ]]

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
echo 'LFS_REQUIRED_PATCH=none; install_mode=DESTDIR; rootfs_merge=forbidden'
echo "ROOTFS_ALP_SHA256=$ALP_SHA256"
echo "ROOTFS_ALP_DB_SHA256=$EMPTY_DB_SHA256"
echo "AVAILABLE_KIB=$available_kib"
mkdir -p "$BUILD" "$STAGE_HOST"
tar -xJf "$SOURCE" -C "$BUILD" --strip-components=1
mkdir -p "$BUILD/tmp"
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

# LFS 8.27 configure, build, full make check, then DESTDIR-only installation.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR=/build/libxcrypt-4.4.38-m04-r1/tmp /bin/bash --noprofile --norc -c '
  set -Eeuo pipefail
  cd /build/libxcrypt-4.4.38-m04-r1
  ./configure --prefix=/usr --enable-hashes=strong,glibc --enable-obsolete-api=no --disable-static --disable-failure-tokens
  make
  if make check > make-check-transcript.log 2>&1; then
    cat make-check-transcript.log
  else
    status=$?; cat make-check-transcript.log >&2; exit "$status"
  fi
'
TEST_SUMMARY=$(python3 "$TEST_VERIFY_TOOL" --transcript "$BUILD/make-check-transcript.log" --suite-log "$BUILD/test-suite.log")
echo "$TEST_SUMMARY" | tee -a "$LOG"

chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c 'set -Eeuo pipefail; cd /build/libxcrypt-4.4.38-m04-r1; make DESTDIR=/tmp/alp-m04-libxcrypt-stage-r1 install'
[[ -s "$STAGE_HOST/usr/lib/libcrypt.so" || -L "$STAGE_HOST/usr/lib/libcrypt.so" ]]
[[ -s "$STAGE_HOST/usr/include/crypt.h" ]]
[[ -s "$STAGE_HOST/usr/lib/libcrypt.so.2" || -L "$STAGE_HOST/usr/lib/libcrypt.so.2" ]]

cat > "$BUILD/libxcrypt-stage-smoke.c" <<'EOF'
#include <crypt.h>
#include <string.h>
int main(void) {
    char *v = crypt("alp-stage-check", "$6$alpcheck$");
    return !v || strncmp(v, "$6$alpcheck$", 12) != 0;
}
EOF
chown 1001:1001 "$BUILD/libxcrypt-stage-smoke.c"
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
  set -Eeuo pipefail
  gcc -I/tmp/alp-m04-libxcrypt-stage-r1/usr/include /build/libxcrypt-4.4.38-m04-r1/libxcrypt-stage-smoke.c -L/tmp/alp-m04-libxcrypt-stage-r1/usr/lib -lcrypt -o /build/libxcrypt-4.4.38-m04-r1/libxcrypt-stage-smoke
  readelf -d /build/libxcrypt-4.4.38-m04-r1/libxcrypt-stage-smoke | grep -F "Shared library: [libcrypt.so.2]"
  LD_LIBRARY_PATH=/tmp/alp-m04-libxcrypt-stage-r1/usr/lib LD_DEBUG=libs /build/libxcrypt-4.4.38-m04-r1/libxcrypt-stage-smoke
' 2> "$BUILD/libxcrypt-stage-loader-trace.log"
grep -Eq "calling init: $STAGE_CHROOT/usr/lib/libcrypt\.so\.2(\.0\.0)?$" "$BUILD/libxcrypt-stage-loader-trace.log"
grep -F "$STAGE_CHROOT/usr/lib/libcrypt.so.2" "$BUILD/libxcrypt-stage-loader-trace.log" >/dev/null

# Existing passwd must continue to run against the staged ABI without writes.
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
  set -Eeuo pipefail
  readelf -d /usr/bin/passwd | grep -F "Shared library: [libcrypt.so.2]"
  LD_LIBRARY_PATH=/tmp/alp-m04-libxcrypt-stage-r1/usr/lib LD_DEBUG=libs /usr/bin/passwd --help >/dev/null
' 2> "$BUILD/passwd-stage-loader-trace.log"
grep -Eq "calling init: $STAGE_CHROOT/usr/lib/libcrypt\.so\.2(\.0\.0)?$" "$BUILD/passwd-stage-loader-trace.log"
[[ $(sha256sum "$LFS/etc/passwd" | awk '{print $1}') == "$PASSWD_DB_SHA256" ]]
[[ $(sha256sum "$LFS/etc/shadow" | awk '{print $1}') == "$SHADOW_DB_SHA256" ]]

assert_alp_and_empty_db
assert_nbd_idle
{
  echo 'package=libxcrypt version=4.4.38'
  echo "source_url=$SOURCE_URL"
  echo "source_md5=$EXPECTED_MD5 (LFS package list)"
  echo "source_sha256=$EXPECTED_SHA256 (upstream release sidecar)"
  echo "test_transcript_sha256=$(sha256sum "$BUILD/make-check-transcript.log" | awk '{print $1}')"
  echo "test_suite_log_sha256=$(sha256sum "$BUILD/test-suite.log" | awk '{print $1}')"
  echo "test_expectation_baseline_sha256=e3912e4ceed71053ef61a16dc6682886c494ba03b76001ac4659c004113598be"
  echo "$TEST_SUMMARY"
  echo "stage_loader_trace_sha256=$(sha256sum "$BUILD/libxcrypt-stage-loader-trace.log" | awk '{print $1}')"
  echo "passwd_loader_trace_sha256=$(sha256sum "$BUILD/passwd-stage-loader-trace.log" | awk '{print $1}')"
  echo "etc_passwd_before_after_sha256=$PASSWD_DB_SHA256"
  echo "etc_shadow_before_after_sha256=$SHADOW_DB_SHA256"
  echo "rootfs_alp_sha256=$ALP_SHA256"
  echo "rootfs_alp_db_sha256=$EMPTY_DB_SHA256"
  echo 'install_mode=DESTDIR; rootfs_merge=forbidden'
} > "$PREFLIGHT"

python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name libxcrypt --version 4.4.38 --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" --output "$MANIFEST" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$STAGE_HOST" > "$STAGE_COMPARE" 2>&1; then
  stage_compare_status=0
else
  stage_compare_status=$?
fi
[[ $stage_compare_status -eq 0 ]]
python3 - "$MANIFEST" "$STAGE_COMPARE" <<'PY' | tee -a "$PREFLIGHT"
import json, re, sys
manifest_path, report_path = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as stream:
    expected = len(json.load(stream)["entries"])
with open(report_path, encoding="utf-8") as stream:
    report = stream.read()
match = re.search(r"entries=(\d+) matched=(\d+) mismatched=(\d+)", report)
if not match:
    raise SystemExit("stage comparator summary missing")
entries, matched, mismatched = map(int, match.groups())
if entries != expected or matched != expected or mismatched != 0:
    raise SystemExit(f"stage manifest mismatch: expected={expected}, report={entries}/{matched}/{mismatched}")
print(f"STAGE_COMPARE_OK: entries={entries} matched={matched} mismatched=0")
PY
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then
  rootfs_compare_status=0
else
  rootfs_compare_status=$?
fi
case "$rootfs_compare_status" in
  0) echo 'ROOTFS_PREFLIGHT=all staged paths match' | tee -a "$PREFLIGHT" ;;
  1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review before adoption' | tee -a "$PREFLIGHT" ;;
  *) echo "ROOTFS_PREFLIGHT=comparator error $rootfs_compare_status" | tee -a "$PREFLIGHT"; exit "$rootfs_compare_status" ;;
esac
cat "$PREFLIGHT"
assert_alp_and_empty_db
assert_nbd_idle
FINISHED=1
