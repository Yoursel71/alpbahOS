#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Libcap 2.76 isolated package stage; never merges into rootfs.
LFS=/mnt/lfs
BUILD=/mnt/lfs/build/libcap-2.76-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-libcap-stage-r1
STAGE_CHROOT=/tmp/alp-m04-libcap-stage-r1
SOURCE=/mnt/lfs/sources/libcap-2.76.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-libcap-2.76-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-m04-libcap-2.76-manifest-20260924-r1.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-libcap-2.76-preflight-20260924-r1.log
STAGE_COMPARE=/mnt/lfs/tmp/alp-m04-libcap-2.76-stage-compare-20260924-r1.log
SOURCE_URL=https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.76.tar.xz
# LFS package-list MD5. SHA-256 is from kernel.org's PGP-signed sha256sums.asc.
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/libcap.html
# https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/sha256sums.asc
EXPECTED_MD5=449ade7d620b5c4eeb15a632fbaa4f74
EXPECTED_SHA256=629da4ab29900d0f7fcc36227073743119925fd711c99a1689bbf5c9b40c8e6f
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL="$SCRIPT_DIR/capture-package-manifest.py"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"
MOUNTS=(); FINISHED=0
cleanup() {
  local status=$?; trap - EXIT; set +e
  for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
  if ! assert_no_lfs_mounts; then status=1; fi
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
  python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f: db=json.load(f)
if db.get("schema_version") != 1 or db.get("packages") != {}: raise SystemExit("expected pinned Alp and empty DB")
PY
}
assert_nbd_idle() {
  [[ -b /dev/nbd0 ]] || { echo 'Cannot verify nbd0: block device is absent' >&2; return 1; }
  if [[ -e /sys/block/nbd0/pid ]]; then
    [[ -r /sys/block/nbd0/pid ]] || { echo 'Cannot read nbd0 pid sysfs attribute' >&2; return 1; }
    [[ -z $(tr -d '[:space:]' < /sys/block/nbd0/pid) ]] || { echo 'Refusing active nbd0 PID' >&2; return 1; }
  else
    [[ $(cat /sys/block/nbd0/size) == 0 ]] || { echo 'Refusing nbd0 with nonzero size (PID sysfs attribute absent)' >&2; return 1; }
  fi
  mounts=$(lsblk -dn -o MOUNTPOINTS /dev/nbd0 | tr -d '[:space:]')
  [[ -z "$mounts" ]] || { echo 'Refusing nbd0 with mountpoints' >&2; return 1; }
  if sources=$(findmnt -rn -S /dev/nbd0); then
    echo "Refusing nbd0 source reported by findmnt: ${sources:-<empty output>}" >&2
    return 1
  else
    findmnt_status=$?
    [[ $findmnt_status -eq 1 ]] || { echo "Cannot verify nbd0 mount source (findmnt status $findmnt_status)" >&2; return 1; }
  fi
  if pgrep -a qemu-nbd >/dev/null; then
    echo 'Refusing while qemu-nbd is running' >&2; return 1
  else
    pgrep_status=$?
    [[ $pgrep_status -eq 1 ]] || { echo "Cannot verify qemu-nbd process state (pgrep status $pgrep_status)" >&2; return 1; }
  fi
  echo 'NBD_IDLE: verified'
}
[[ $EUID -eq 0 && -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" && ! -e "$STAGE_COMPARE" ]]
assert_no_lfs_mounts
assert_nbd_idle
for process in make ninja meson cmake; do if pgrep -x "$process" >/dev/null; then echo "Refusing concurrent build: $process" >&2; exit 1; fi; done
if find /tmp /mnt/lfs/tmp -maxdepth 3 -type f \( -iname '*.vhdx' -o -iname '*.vhd' -o -iname '*.raw' \) -print -quit | grep -q .; then
  echo 'Refusing to start while a disk image is present in a temporary directory' >&2; exit 1
fi
assert_alp_and_empty_db
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 524288 ]]
mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
echo 'LFS_REQUIRED_PATCH=none; install_mode=DESTDIR; rootfs_merge=forbidden'
mkdir -p "$BUILD" "$STAGE_HOST"; tar -xJf "$SOURCE" -C "$BUILD" --strip-components=1
mkdir -p "$BUILD/tmp"; chown -R 1001:1001 "$BUILD"
bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
bind_mount /dev "$LFS/dev"; bind_mount /dev/pts "$LFS/dev/pts"; bind_mount /proc "$LFS/proc"; bind_mount /sys "$LFS/sys"; bind_mount /run "$LFS/run"
# LFS 8.26 sed, build, make test, then stage installation.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR=/build/libcap-2.76-m04-r1/tmp /bin/bash --noprofile --norc -c '
  cd /build/libcap-2.76-m04-r1
  sed -i "/install -m.*STA/d" libcap/Makefile
  make prefix=/usr lib=lib
'
# Tests may exercise privileged capability operations; run the LFS make test
# target as root inside the chroot after the unprivileged build.
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c 'cd /build/libcap-2.76-m04-r1 && make test'
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c 'cd /build/libcap-2.76-m04-r1 && make DESTDIR=/tmp/alp-m04-libcap-stage-r1 prefix=/usr lib=lib install'
[[ -s "$STAGE_HOST/usr/lib/libcap.so" || -L "$STAGE_HOST/usr/lib/libcap.so" ]]
[[ -s "$STAGE_HOST/usr/lib/libpsx.so" || -L "$STAGE_HOST/usr/lib/libpsx.so" ]]
[[ -x "$STAGE_HOST/usr/sbin/capsh" && -x "$STAGE_HOST/usr/sbin/getcap" && -x "$STAGE_HOST/usr/sbin/getpcaps" && -x "$STAGE_HOST/usr/sbin/setcap" ]]
cat > "$BUILD/libcap-stage-smoke.c" <<'EOF'
#include <sys/capability.h>
int main(void) { cap_t c=cap_get_proc(); if (!c) return 1; return cap_free(c) != 0; }
EOF
chown 1001:1001 "$BUILD/libcap-stage-smoke.c"
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
  gcc -I/tmp/alp-m04-libcap-stage-r1/usr/include /build/libcap-2.76-m04-r1/libcap-stage-smoke.c -L/tmp/alp-m04-libcap-stage-r1/usr/lib -lcap -o /build/libcap-2.76-m04-r1/libcap-stage-smoke
  readelf -d /build/libcap-2.76-m04-r1/libcap-stage-smoke | grep -F "Shared library: [libcap.so.2]"
  LD_LIBRARY_PATH=/tmp/alp-m04-libcap-stage-r1/usr/lib LD_DEBUG=libs /build/libcap-2.76-m04-r1/libcap-stage-smoke
' 2> "$BUILD/libcap-stage-loader-trace.log"
grep -Eq "calling init: $STAGE_CHROOT/usr/lib/libcap\.so\.2(\.76)?$" "$BUILD/libcap-stage-loader-trace.log"
assert_alp_and_empty_db; assert_nbd_idle
{ echo 'package=libcap version=2.76'; echo "source_url=$SOURCE_URL"; echo "source_md5=$EXPECTED_MD5 (LFS package list)"; echo "source_sha256=$EXPECTED_SHA256 (kernel.org signed sha256sums.asc)"; echo 'critical_tests=make test passed'; echo "smoke_loader_trace=$BUILD/libcap-stage-loader-trace.log sha256=$(sha256sum "$BUILD/libcap-stage-loader-trace.log" | awk '{print $1}')"; echo 'install_mode=DESTDIR; rootfs_merge=forbidden'; } > "$PREFLIGHT"
python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name libcap --version 2.76 --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" --output "$MANIFEST" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$STAGE_HOST" > "$STAGE_COMPARE" 2>&1; then stage_compare_status=0; else stage_compare_status=$?; fi
[[ $stage_compare_status -eq 0 ]]
python3 - "$MANIFEST" "$STAGE_COMPARE" <<'PY' | tee -a "$PREFLIGHT"
import json, re, sys
manifest_path, report_path = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as f:
    expected = len(json.load(f)["entries"])
with open(report_path, encoding="utf-8") as f:
    report = f.read()
match = re.search(r"entries=(\d+) matched=(\d+) mismatched=(\d+)", report)
if not match:
    raise SystemExit("stage comparator summary missing")
entries, matched, mismatched = map(int, match.groups())
if entries != expected or matched != expected or mismatched != 0:
    raise SystemExit(f"stage manifest mismatch: expected={expected}, report={entries}/{matched}/{mismatched}")
print(f"STAGE_COMPARE_OK: entries={entries} matched={matched} mismatched=0")
PY
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then compare_status=0; else compare_status=$?; fi
case "$compare_status" in 0) echo 'ROOTFS_PREFLIGHT=all staged paths match' | tee -a "$PREFLIGHT" ;; 1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review before adoption' | tee -a "$PREFLIGHT" ;; *) echo "ROOTFS_PREFLIGHT=comparator error $compare_status" | tee -a "$PREFLIGHT"; exit "$compare_status" ;; esac
cat "$PREFLIGHT"; assert_alp_and_empty_db; assert_nbd_idle; FINISHED=1
