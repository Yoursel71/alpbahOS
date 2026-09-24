#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd MPFR 4.2.2 isolated package stage. Run on the Builder.
# Draft only; review before use. Installs are DESTDIR-only; no rootfs merge.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/mpfr-4.2.2-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-mpfr-stage-r1
STAGE_CHROOT=/tmp/alp-m04-mpfr-stage-r1
GMP_STAGE_HOST=/mnt/lfs/tmp/alp-m04-gmp-stage-r1
GMP_STAGE_CHROOT=/tmp/alp-m04-gmp-stage-r1
GMP_MANIFEST=/mnt/lfs/tmp/alp-m04-gmp-6.3.0-manifest-20260924-r1.json
EXPECTED_GMP_MANIFEST_SHA256=5e68e60e1fb1032940b25e5bd565a36e14bb0c42a6fc2a88af18ebb356f06e62
SOURCE=/mnt/lfs/sources/mpfr-4.2.2.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-mpfr-4.2.2-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-m04-mpfr-4.2.2-manifest-20260924-r1.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-mpfr-4.2.2-preflight-20260924-r1.log
SOURCE_URL=https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.2.tar.xz
# MD5 is from the official LFS 12.4-systemd package list. SHA-256 is from
# MPFR's primary release announcement and matches the official release file.
# References:
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/mpfr.html
# https://gcc.gnu.org/pipermail/gcc/2025-March/245769.html
EXPECTED_MD5=7c32c39b8b6e3ae85f25156228156061
EXPECTED_SHA256=b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL="$SCRIPT_DIR/capture-package-manifest.py"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"
MOUNTS=()
FINISHED=0

cleanup() {
    local status=$?
    trap - EXIT
    set +e
    for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do
        umount "${MOUNTS[$i]}" || status=1
    done
    if findmnt -rn -R "$LFS"; then
        echo "CLEANUP_FAILED: mounts remain below $LFS" >&2
        status=1
    else
        echo "CLEANUP_OK: no mounts remain below $LFS"
    fi
    if (( FINISHED )); then
        echo "STAGE_OK: $STAGE_HOST"
    else
        echo 'STAGE_INCOMPLETE: preserve build/stage/logs for diagnosis' >&2
        status=1
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

assert_alp_and_empty_db() {
    [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
    python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    database = json.load(stream)
if database.get("schema_version") != 1 or database.get("packages") != {}:
    raise SystemExit("refusing: Alp must remain pinned at schema 1 with an empty package DB")
PY
}

[[ $EUID -eq 0 ]]
[[ -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ -f "$GMP_MANIFEST" && -d "$GMP_STAGE_HOST/usr/include" ]]
[[ -s "$GMP_STAGE_HOST/usr/include/gmp.h" ]]
[[ -s "$GMP_STAGE_HOST/usr/lib/libgmp.so" || -L "$GMP_STAGE_HOST/usr/lib/libgmp.so" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" ]]
[[ ! -e "$MANIFEST" && ! -e "$PREFLIGHT" ]]
[[ $(sha256sum "$GMP_MANIFEST" | awk '{print $1}') == "$EXPECTED_GMP_MANIFEST_SHA256" ]]
python3 - "$GMP_MANIFEST" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    manifest = json.load(stream)
package = manifest.get("package", {})
source = package.get("source", {})
if package.get("name") != "gmp" or package.get("version") != "6.3.0":
    raise SystemExit("refusing: staged dependency manifest is not GMP 6.3.0")
if source.get("sha256") != "a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898":
    raise SystemExit("refusing: GMP manifest source SHA-256 differs from the pinned GMP draft")
PY
[[ -z $(findmnt -rn -R "$LFS" || true) ]]
[[ ! -s /sys/block/nbd0/pid ]]
for process in make ninja meson; do
    if pgrep -x "$process" >/dev/null; then
        echo "Refusing concurrent build process: $process" >&2
        exit 1
    fi
done
assert_alp_and_empty_db
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
available_kib=$(df -Pk "$LFS" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 524288 ]]

# Pin and revalidate the exact GMP stage tree before MPFR configuration.
: > "$PREFLIGHT"
echo "GMP_MANIFEST_SHA256=$EXPECTED_GMP_MANIFEST_SHA256" >> "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$GMP_MANIFEST" --root "$GMP_STAGE_HOST" >> "$PREFLIGHT" 2>&1; then
    gmp_stage_manifest_status=0
else
    gmp_stage_manifest_status=$?
fi
echo "GMP_STAGE_MANIFEST_COMPARE_EXIT=$gmp_stage_manifest_status" >> "$PREFLIGHT"
if (( gmp_stage_manifest_status != 0 )); then
    echo 'Refusing MPFR configure: the retained GMP stage differs from its pinned manifest' >&2
    exit "$gmp_stage_manifest_status"
fi

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
echo "LFS_MD5=$(md5sum "$SOURCE" | awk '{print $1}')"
echo "GMP_MANIFEST_SHA256=$EXPECTED_GMP_MANIFEST_SHA256"
echo 'LFS_REQUIRED_PATCH=none'
echo 'LFS_ROOTFS_MERGE=forbidden install_mode=DESTDIR'
df -h "$LFS"
mkdir -p "$BUILD" "$STAGE_HOST"
tar -xJf "$SOURCE" -C "$BUILD" --strip-components=1
mkdir -p "$BUILD/tmp"
chown -R 1001:1001 "$BUILD"

bind_mount() {
    local source=$1 target=$2
    if /usr/bin/mountpoint -q "$target"; then
        echo "Refusing pre-existing mount: $target" >&2
        return 1
    fi
    mount --bind "$source" "$target"
    MOUNTS+=("$target")
}
bind_mount /dev "$LFS/dev"
bind_mount /dev/pts "$LFS/dev/pts"
bind_mount /proc "$LFS/proc"
bind_mount /sys "$LFS/sys"
bind_mount /run "$LFS/run"

# LFS 8.22: build and run the full 198-test suite. The staged GMP tree is
# explicitly selected for configure and link; preload it during tests so an
# inherited DT_RPATH cannot redirect GMP resolution to the Builder rootfs.
# Installation only
# populates MPFR's unique DESTDIR stage.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
    HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    TMPDIR=/build/mpfr-4.2.2-m04-r1/tmp TMP=/build/mpfr-4.2.2-m04-r1/tmp \
    TEMP=/build/mpfr-4.2.2-m04-r1/tmp \
    GMP_STAGE="$GMP_STAGE_CHROOT" \
    CPPFLAGS="-I$GMP_STAGE_CHROOT/usr/include" \
    LDFLAGS="-L$GMP_STAGE_CHROOT/usr/lib" \
    LD_LIBRARY_PATH="$GMP_STAGE_CHROOT/usr/lib" \
    /bin/bash --noprofile --norc -c '
        cd /build/mpfr-4.2.2-m04-r1
        ./configure --prefix=/usr --disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr-4.2.2
        make
        make html
        set -o pipefail
        if LD_PRELOAD="$GMP_STAGE/usr/lib/libgmp.so.10.5.0" make check 2>&1 | tee mpfr-check-log; then
            :
        else
            status=$?
            echo "MPFR make check failed; test summary follows:" >&2
            awk "/# (FAIL|ERROR|XPASS):/ {print}" mpfr-check-log >&2 || true
            exit "$status"
        fi
        total=$(awk "/# TOTAL:/ {value = \$3} END {print value + 0}" mpfr-check-log)
        passed=$(awk "/# PASS:/ {value = \$3} END {print value + 0}" mpfr-check-log)
        failed=$(awk "/# (FAIL|ERROR|XPASS):/ {value += \$3} END {print value + 0}" mpfr-check-log)
        test "$total" -eq 198
        test "$passed" -eq 198
        test "$failed" -eq 0
        echo "MPFR_TEST_TOTAL=$total MPFR_TEST_PASS=$passed MPFR_TEST_FAILURES=$failed"
    '
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        cd /build/mpfr-4.2.2-m04-r1
        make DESTDIR=/tmp/alp-m04-mpfr-stage-r1 install
        make DESTDIR=/tmp/alp-m04-mpfr-stage-r1 install-html
    '

cat > "$BUILD/mpfr-stage-smoke.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include <gmp.h>
#include <mpfr.h>
int main(void) {
  mpfr_t value;
  mpfr_init2(value, 128);
  mpfr_set_ui(value, 21, MPFR_RNDN);
  mpfr_mul_ui(value, value, 2, MPFR_RNDN);
  int failed = mpfr_cmp_ui(value, 42) != 0 || strcmp(mpfr_get_version(), "4.2.2") != 0;
  printf("MPFR_STAGE_SMOKE version=%s result=%s\n", mpfr_get_version(),
         failed ? "failed" : "passed");
  mpfr_clear(value);
  return failed;
}
EOF
chown 1001:1001 "$BUILD/mpfr-stage-smoke.c"
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        gcc -I/tmp/alp-m04-mpfr-stage-r1/usr/include \
            -I/tmp/alp-m04-gmp-stage-r1/usr/include \
            /build/mpfr-4.2.2-m04-r1/mpfr-stage-smoke.c \
            -L/tmp/alp-m04-mpfr-stage-r1/usr/lib \
            -L/tmp/alp-m04-gmp-stage-r1/usr/lib -lmpfr -lgmp \
            -o /build/mpfr-4.2.2-m04-r1/mpfr-stage-smoke
        LD_LIBRARY_PATH=/tmp/alp-m04-mpfr-stage-r1/usr/lib:/tmp/alp-m04-gmp-stage-r1/usr/lib \
            /build/mpfr-4.2.2-m04-r1/mpfr-stage-smoke
    '
[[ -s "$STAGE_HOST/usr/lib/libmpfr.so" || -L "$STAGE_HOST/usr/lib/libmpfr.so" ]]
[[ -d "$STAGE_HOST/usr/share/doc/mpfr-4.2.2" ]]

assert_alp_and_empty_db
[[ ! -s /sys/block/nbd0/pid ]]
{
    echo 'package=mpfr version=4.2.2'
    echo "source_url=$SOURCE_URL"
    echo "source_md5=$EXPECTED_MD5"
    echo "source_sha256=$EXPECTED_SHA256"
    echo 'patches=none-required-by-LFS-12.4-systemd'
    echo 'dependency=gmp 6.3.0; staged manifest SHA-256 pinned by GMP_MANIFEST_SHA256'
    echo 'install_mode=DESTDIR; rootfs_merge=forbidden'
    echo 'critical_tests=make check; TOTAL=198 PASS=198 FAIL=ERROR=XPASS=0'
    echo "builder=$(hostname)"
} >> "$PREFLIGHT"
python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name mpfr --version 4.2.2 \
    --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$STAGE_HOST" >> "$PREFLIGHT" 2>&1; then
    stage_manifest_status=0
else
    stage_manifest_status=$?
fi
echo "MPFR_STAGE_MANIFEST_COMPARE_EXIT=$stage_manifest_status" | tee -a "$PREFLIGHT"
if (( stage_manifest_status != 0 )); then
    echo 'MPFR stage does not match its captured manifest; refusing completion' >&2
    exit "$stage_manifest_status"
fi
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then
    compare_status=0
else
    compare_status=$?
fi
case "$compare_status" in
    0) echo 'ROOTFS_PREFLIGHT=all staged paths already match the live rootfs' | tee -a "$PREFLIGHT" ;;
    1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review recorded mismatches before any adoption' | tee -a "$PREFLIGHT" ;;
    *) echo "ROOTFS_PREFLIGHT=compare tool failed status=$compare_status" | tee -a "$PREFLIGHT"; exit "$compare_status" ;;
esac
cat "$PREFLIGHT"
assert_alp_and_empty_db
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
