#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd GMP-6.3.0 isolated package stage. Run on the Builder.
# Draft only; review before use. The install step uses DESTDIR exclusively.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/gmp-6.3.0-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-gmp-stage-r1
GMP_STAGE_HOST="$STAGE_HOST"
STAGE_CHROOT=/tmp/alp-m04-gmp-stage-r1
SOURCE=/mnt/lfs/sources/gmp-6.3.0.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-gmp-6.3.0-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-m04-gmp-6.3.0-manifest-20260924-r1.json
GMP_MANIFEST="$MANIFEST"
PREFLIGHT=/mnt/lfs/tmp/alp-m04-gmp-6.3.0-preflight-20260924-r1.log
SOURCE_URL=https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
# MD5 is from the official LFS 12.4-systemd package list. GMP's upstream
# release page publishes detached GPG signatures rather than SHA-256; this
# SHA-256 is an independent cross-check from Fossies for the same archive.
# References:
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://gmplib.org/ (GMP 6.3.0 release and signature information)
# https://fossies.org/linux/misc/gmp-6.3.0.tar.xz/
EXPECTED_MD5=956dc04e864001a9c22429f761f2c283
EXPECTED_SHA256=a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
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
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" ]]
[[ ! -e "$MANIFEST" && ! -e "$PREFLIGHT" ]]
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

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
echo "LFS_MD5=$(md5sum "$SOURCE" | awk '{print $1}')"
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

# LFS 8.21: apply the GCC-15 configure compatibility sed; configure, make,
# make html, critical make check, require at least 199 PASS tests, then install
# files and HTML docs into DESTDIR. Stage smoke links only against this tree.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
    HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    TMPDIR=/build/gmp-6.3.0-m04-r1/tmp TMP=/build/gmp-6.3.0-m04-r1/tmp \
    TEMP=/build/gmp-6.3.0-m04-r1/tmp \
    /bin/bash --noprofile --norc -c '
        cd /build/gmp-6.3.0-m04-r1
        sed -i "/long long t1;/,+1s/()/(...)/" configure
        ./configure --prefix=/usr --enable-cxx --disable-static --docdir=/usr/share/doc/gmp-6.3.0
        make
        make html
        set -o pipefail
        if make check 2>&1 | tee gmp-check-log; then
            :
        else
            status=$?
            echo "GMP make check failed; failed test summary follows:" >&2
            awk "/# (FAIL|ERROR|XPASS):/ {print}" gmp-check-log >&2 || true
            exit "$status"
        fi
        passed=$(awk "/# PASS:/ {total += \$3} END {print total + 0}" gmp-check-log)
        test "$passed" -ge 199
        echo "GMP_TEST_PASS_COUNT=$passed"
    '
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        cd /build/gmp-6.3.0-m04-r1
        make DESTDIR=/tmp/alp-m04-gmp-stage-r1 install
        make DESTDIR=/tmp/alp-m04-gmp-stage-r1 install-html
    '

cat > "$BUILD/gmp-stage-smoke.c" <<'EOF'
#include <stdio.h>
#include <gmp.h>
int main(void) {
  mpz_t value;
  mpz_init_set_ui(value, 21);
  mpz_mul_ui(value, value, 2);
  int failed = mpz_cmp_ui(value, 42) != 0;
  printf("GMP_STAGE_SMOKE version=%s result=%s\n", gmp_version,
         failed ? "failed" : "passed");
  mpz_clear(value);
  return failed;
}
EOF
chown 1001:1001 "$BUILD/gmp-stage-smoke.c"
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        gcc -I/tmp/alp-m04-gmp-stage-r1/usr/include \
            /build/gmp-6.3.0-m04-r1/gmp-stage-smoke.c \
            -L/tmp/alp-m04-gmp-stage-r1/usr/lib -lgmp \
            -o /build/gmp-6.3.0-m04-r1/gmp-stage-smoke
        LD_LIBRARY_PATH=/tmp/alp-m04-gmp-stage-r1/usr/lib \
            /build/gmp-6.3.0-m04-r1/gmp-stage-smoke
    '
[[ -s "$STAGE_HOST/usr/lib/libgmp.so" || -L "$STAGE_HOST/usr/lib/libgmp.so" ]]
[[ -s "$STAGE_HOST/usr/lib/libgmpxx.so" || -L "$STAGE_HOST/usr/lib/libgmpxx.so" ]]
[[ -d "$STAGE_HOST/usr/share/doc/gmp-6.3.0" ]]

assert_alp_and_empty_db
[[ ! -s /sys/block/nbd0/pid ]]
{
    echo 'package=gmp version=6.3.0'
    echo "source_url=$SOURCE_URL"
    echo "source_md5=$EXPECTED_MD5"
    echo "source_sha256=$EXPECTED_SHA256"
    echo 'patches=none-required-by-LFS-12.4-systemd'
    echo 'install_mode=DESTDIR; rootfs_merge=forbidden'
    echo 'critical_tests=make check; PASS >=199'
    echo "builder=$(hostname)"
} > "$PREFLIGHT"
python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name gmp --version 6.3.0 \
    --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$GMP_MANIFEST" --root "$GMP_STAGE_HOST" >> "$PREFLIGHT" 2>&1; then
    stage_manifest_status=0
else
    stage_manifest_status=$?
fi
echo "GMP_STAGE_MANIFEST_COMPARE_EXIT=$stage_manifest_status" | tee -a "$PREFLIGHT"
if (( stage_manifest_status != 0 )); then
    echo "GMP stage does not match its captured manifest; refusing MPFR handoff" >&2
    exit "$stage_manifest_status"
fi
if python3 "$COMPARE_TOOL" --manifest "$GMP_MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then
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
