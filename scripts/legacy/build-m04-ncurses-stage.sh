#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Ncurses 6.5-20250809, isolated DESTDIR package stage.
# This script never merges the staged files into /mnt/lfs.
LFS=/mnt/lfs
RUN_ID=20260924-r3
PACKAGE=ncurses-6.5-20250809
BUILD=/mnt/lfs/build/${PACKAGE}-m04-${RUN_ID}
STAGE_HOST=/mnt/lfs/tmp/alp-m04-ncurses-stage-${RUN_ID}
STAGE_CHROOT=/tmp/alp-m04-ncurses-stage-${RUN_ID}
SOURCE=/mnt/lfs/sources/ncurses-6.5-20250809.tgz
LOG=/mnt/lfs/tmp/alp-logs/m04-ncurses-${RUN_ID}.log
MANIFEST=/mnt/lfs/tmp/alp-m04-ncurses-manifest-${RUN_ID}.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-ncurses-preflight-${RUN_ID}.log
STAGE_COMPARE=/mnt/lfs/tmp/alp-m04-ncurses-stage-compare-${RUN_ID}.log
ROOTFS_COMPARE=/mnt/lfs/tmp/alp-m04-ncurses-rootfs-compare-${RUN_ID}.log
SOURCE_URL=https://invisible-mirror.net/archives/ncurses/current/ncurses-6.5-20250809.tgz
# Official LFS 12.4-systemd package-list MD5. SHA-256 was measured from the
# Builder archive after its MD5 matched the published LFS value; no official
# SHA-256 sidecar was found for this snapshot.
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/ncurses.html
EXPECTED_MD5=679987405412f970561cc85e1e6428a2
EXPECTED_SHA256=b071468b8c79099a378ed9bea937a605509f71e720402e2541abe20ad753c555
ALP_ENGINE_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
EMPTY_DB_SHA256=40a9bcde751533fc237fae2b7e5eaebbbfd5779f3069c09f0590c07be184f165

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL="$SCRIPT_DIR/capture-package-manifest.py"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"
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

assert_nbd_idle() {
  local mounts sources status pgrep_status
  [[ -b /dev/nbd0 ]] || { echo 'Cannot verify nbd0: block device is absent' >&2; return 1; }
  if [[ -e /sys/block/nbd0/pid ]]; then
    [[ -r /sys/block/nbd0/pid ]] || { echo 'Cannot read nbd0 pid sysfs attribute' >&2; return 1; }
    [[ -z $(tr -d '[:space:]' < /sys/block/nbd0/pid) ]] || { echo 'Refusing active nbd0 PID' >&2; return 1; }
  else
    [[ $(cat /sys/block/nbd0/size) == 0 ]] || { echo 'Refusing nbd0 with nonzero size (PID attribute absent)' >&2; return 1; }
  fi
  mounts=$(lsblk -dn -o MOUNTPOINTS /dev/nbd0) || { echo 'Cannot inspect nbd0 mountpoints' >&2; return 1; }
  [[ -z $(printf '%s' "$mounts" | tr -d '[:space:]') ]] || { echo "Refusing nbd0 mountpoints: $mounts" >&2; return 1; }
  if sources=$(findmnt -rn -S /dev/nbd0); then
    echo "Refusing nbd0 source reported by findmnt: ${sources:-<empty output>}" >&2
    return 1
  else
    status=$?
    [[ $status -eq 1 ]] || { echo "Cannot verify nbd0 source (findmnt status $status)" >&2; return 1; }
  fi
  if pgrep -a qemu-nbd >/dev/null; then
    echo 'Refusing while qemu-nbd is running' >&2
    return 1
  else
    pgrep_status=$?
    [[ $pgrep_status -eq 1 ]] || { echo "Cannot inspect qemu-nbd state (pgrep status $pgrep_status)" >&2; return 1; }
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

[[ $EUID -eq 0 && -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/gcc" && -f "$SOURCE" ]]
[[ "$ALP_ENGINE_SHA256" =~ ^[0-9a-f]{64}$ && "$EMPTY_DB_SHA256" =~ ^[0-9a-f]{64}$ ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" && ! -e "$STAGE_COMPARE" && ! -e "$ROOTFS_COMPARE" ]]
assert_no_lfs_mounts
assert_nbd_idle
for process in make ninja meson cmake; do
  if pgrep -x "$process" >/dev/null; then
    echo "Refusing concurrent build: $process" >&2
    exit 1
  else
    pgrep_status=$?
    [[ $pgrep_status -eq 1 ]] || { echo "Cannot inspect $process process state (pgrep status $pgrep_status)" >&2; exit 1; }
  fi
done
if temp_images=$(find /tmp /mnt/lfs/tmp -maxdepth 3 -type f \( -iname '*.vhdx' -o -iname '*.vhd' -o -iname '*.raw' \) -print 2>/dev/null); then
  [[ -z "$temp_images" ]] || { echo "Refusing temporary disk image(s): $temp_images" >&2; exit 1; }
else
  echo 'Cannot inspect temporary directories for disk images' >&2
  exit 1
fi
assert_alp_and_empty_db
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 524288 ]]

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) run_id=$RUN_ID source=$(sha256sum "$SOURCE")"
echo 'Recipe=LFS 12.4-systemd Ncurses 6.5-20250809; install_mode=DESTDIR; rootfs_merge=forbidden'
echo 'Upstream suite: LFS says tests run after installation in test/; test/README describes example/demo programs and says they are not a complete test set. No make check is prescribed; that suite is not claimed or run here.'
echo "ROOTFS_ALP_ENGINE_SHA256=$ALP_ENGINE_SHA256 ROOTFS_ALP_DB_SHA256=$EMPTY_DB_SHA256"
echo "AVAILABLE_KIB=$available_kib"

mkdir -p "$BUILD" "$STAGE_HOST"
tar -xzf "$SOURCE" -C "$BUILD" --strip-components=1
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

# LFS 8.30 configure and make; install only to a unique DESTDIR inside the
# chroot. The active-root library replacement and cp into / from the book are
# deliberately omitted. Header and compatibility-link edits stay in DESTDIR.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
  HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
  TMPDIR=/build/${PACKAGE}-m04-${RUN_ID}/tmp \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    cd /build/ncurses-6.5-20250809-m04-20260924-r3
    ./configure --prefix=/usr \
                --mandir=/usr/share/man \
                --with-shared \
                --without-debug \
                --without-normal \
                --with-cxx-shared \
                --enable-pc-files \
                --with-pkg-config-libdir=/usr/lib/pkgconfig
    make
  '

# Ncurses tests are install-after-build and terminal-oriented; LFS points to
# test/README and does not prescribe a noninteractive "make check" target.
# Record that suite boundary, then run an isolated staged-library/terminfo
# smoke test instead of claiming upstream-suite coverage.
[[ -s "$BUILD/test/README" ]]
TEST_README_SHA256=$(sha256sum "$BUILD/test/README" | awk '{print $1}')
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    cd /build/ncurses-6.5-20250809-m04-20260924-r3
    make DESTDIR=/tmp/alp-m04-ncurses-stage-20260924-r3 install
  '

[[ -s "$STAGE_HOST/usr/lib/libncursesw.so.6.5" ]]
[[ -s "$STAGE_HOST/usr/include/curses.h" ]]
[[ -d "$STAGE_HOST/usr/lib/pkgconfig" ]]
[[ -d "$STAGE_HOST/usr/share/terminfo" ]]

chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    stage=/tmp/alp-m04-ncurses-stage-20260924-r3
    cd /build/ncurses-6.5-20250809-m04-20260924-r3
    sed -e "s/^#if.*XOPEN.*$/#if 1/" -i "$stage/usr/include/curses.h"
    for lib in ncurses form panel menu; do
      ln -sfv "lib${lib}w.so" "$stage/usr/lib/lib${lib}.so"
      ln -sfv "${lib}w.pc" "$stage/usr/lib/pkgconfig/${lib}.pc"
    done
    ln -sfv libncursesw.so "$stage/usr/lib/libcurses.so"
    mkdir -p "$stage/usr/share/doc"
    cp -v -R doc -T "$stage/usr/share/doc/ncurses-6.5-20250809"
  '

cat > "$BUILD/ncurses-stage-smoke.c" <<'EOF'
#define _XOPEN_SOURCE 700
#include <curses.h>
#include <term.h>
#include <stdio.h>

int main(void) {
    int error = 0;
    if (setupterm("xterm", 1, &error) != OK) {
        fprintf(stderr, "setupterm failed: %d\n", error);
        return 1;
    }
    int col_count = tigetnum("cols");
    if (col_count <= 0) {
        fprintf(stderr, "xterm cols capability unavailable: %d\n", col_count);
        return 2;
    }
    printf("XTERM_COLUMNS=%d\n", col_count);
    return 0;
}
EOF
chown 1001:1001 "$BUILD/ncurses-stage-smoke.c"
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
  PATH=/usr/bin:/usr/sbin:/bin:/sbin \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    stage=/tmp/alp-m04-ncurses-stage-20260924-r3
    gcc -D_XOPEN_SOURCE=700 \
      -I"$stage/usr/include" \
      /build/ncurses-6.5-20250809-m04-20260924-r3/ncurses-stage-smoke.c \
      -L"$stage/usr/lib" -Wl,-rpath-link,"$stage/usr/lib" -lncursesw \
      -o /build/ncurses-6.5-20250809-m04-20260924-r3/ncurses-stage-smoke
    readelf -d /build/ncurses-6.5-20250809-m04-20260924-r3/ncurses-stage-smoke | grep -F "Shared library: [libncursesw.so.6]"
  '
chroot "$LFS" /usr/bin/env -i \
  PATH=/usr/bin:/usr/sbin:/bin:/sbin \
  LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
  TERMINFO="$STAGE_CHROOT/usr/share/terminfo" \
  LD_DEBUG=libs \
  /bin/bash --noprofile --norc -c '
    set -Eeuo pipefail
    /build/ncurses-6.5-20250809-m04-20260924-r3/ncurses-stage-smoke
  ' 2> "$BUILD/ncurses-stage-loader-trace.log" | tee "$BUILD/ncurses-stage-smoke.log"
grep -F "$STAGE_CHROOT/usr/lib/libncursesw.so.6" "$BUILD/ncurses-stage-loader-trace.log" >/dev/null
grep -Eq '^XTERM_COLUMNS=[1-9][0-9]*$' "$BUILD/ncurses-stage-smoke.log"

# Preserve the LFS optional documentation install and compatibility edits,
# but apply every operation to DESTDIR only. Keep libncursesw.so.6.5 in stage:
# LFS removes its staged copy only after replacing the active target /usr/lib.
assert_alp_and_empty_db
assert_nbd_idle

{
  echo "package=ncurses version=6.5-20250809 run_id=$RUN_ID"
  echo "source_url=$SOURCE_URL"
  echo "source_md5=$EXPECTED_MD5 (LFS package list)"
  echo "source_sha256=$EXPECTED_SHA256 (measured from matching LFS archive)"
  echo "test_readme_sha256=$TEST_README_SHA256"
  echo 'upstream_tests=not run; LFS describes tests as installed test/ programs; no make check is prescribed'
  echo "staged_runtime_smoke_sha256=$(sha256sum "$BUILD/ncurses-stage-smoke.log" | awk '{print $1}')"
  echo "staged_loader_trace_sha256=$(sha256sum "$BUILD/ncurses-stage-loader-trace.log" | awk '{print $1}')"
  echo "rootfs_alp_engine_sha256=$ALP_ENGINE_SHA256"
  echo "rootfs_alp_db_sha256=$EMPTY_DB_SHA256"
  echo 'install_mode=DESTDIR; compatibility_edits=DESTDIR-only; rootfs_merge=forbidden'
} > "$PREFLIGHT"

python3 "$CAPTURE_TOOL" \
  --stage "$STAGE_HOST" \
  --name ncurses \
  --version 6.5-20250809 \
  --source-url "$SOURCE_URL" \
  --source-sha256 "$EXPECTED_SHA256" \
  --output "$MANIFEST" | tee -a "$PREFLIGHT"

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
FINISHED=1
