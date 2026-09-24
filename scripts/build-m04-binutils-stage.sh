#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Binutils-2.45 isolated package stage. Run on the Builder.
# Draft only: review before use. Package installation is DESTDIR-only; no
# package files are merged into /mnt/lfs/usr or /mnt/lfs/etc.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/binutils-2.45-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-binutils-stage-r1
STAGE_CHROOT=/tmp/alp-m04-binutils-stage-r1
SOURCE=/mnt/lfs/sources/binutils-2.45.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-binutils-2.45-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-m04-binutils-2.45-manifest-20260924-r1.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-binutils-2.45-preflight-20260924-r1.log
SOURCE_URL=https://sourceware.org/pub/binutils/releases/binutils-2.45.tar.xz
# MD5 from the LFS 12.4-systemd package list; SHA-256 from the GNU Binutils
# 2.45 release announcement. LFS 12.4-systemd requires no Binutils patch.
# References:
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
# https://lists.gnu.org/archive/html/info-gnu/2025-07/msg00009.html
# https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/patches.html
EXPECTED_MD5=dee5b4267e0305a99a3c9d6131f45759
EXPECTED_SHA256=c50c0e7f9cb188980e2cc97e4537626b1672441815587f1eab69d2a1bfbef5d2
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
[[ "$available_kib" =~ ^[0-9]+$ && $available_kib -ge 2097152 ]]

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

# Follow LFS 8.20 exactly: dedicated build directory; configure with the
# listed options; make tooldir=/usr; critical `make -k check`; install. LFS
# Chapter 3 lists no Binutils patch. TMPDIR keeps test scratch under BUILD.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
    HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    TMPDIR=/build/binutils-2.45-m04-r1/tmp TMP=/build/binutils-2.45-m04-r1/tmp \
    TEMP=/build/binutils-2.45-m04-r1/tmp \
    /bin/bash --noprofile --norc -c '
        cd /build/binutils-2.45-m04-r1
        mkdir -v build
        cd build
        ../configure --prefix=/usr \
            --sysconfdir=/etc \
            --enable-ld=default \
            --enable-plugins \
            --enable-shared \
            --disable-werror \
            --enable-64-bit-bfd \
            --enable-new-dtags \
            --with-system-zlib \
            --enable-default-hash-style=gnu
        make tooldir=/usr
    '
chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    TMPDIR=/build/binutils-2.45-m04-r1/tmp TMP=/build/binutils-2.45-m04-r1/tmp \
    TEMP=/build/binutils-2.45-m04-r1/tmp \
    /bin/bash --noprofile --norc -c '
        cd /build/binutils-2.45-m04-r1/build
        if make -k check; then
            test_status=0
        else
            test_status=$?
        fi
        echo "BINUTILS_MAKE_CHECK_EXIT=$test_status"

        # LFS Chapter 8.20 diagnostic: retain every matching FAIL line and
        # its exit status in the surrounding Builder log.
        if grep "^FAIL:" $(find -name "*.log"); then
            diagnostic_status=0
        else
            diagnostic_status=$?
        fi
        echo "BINUTILS_FAIL_DIAGNOSTIC_EXIT=$diagnostic_status"

        if (( diagnostic_status > 1 )); then
            echo "Binutils FAIL diagnostic errored (status $diagnostic_status)" >&2
            exit "$diagnostic_status"
        fi
        if (( test_status != 0 )); then
            echo "Binutils make -k check failed (status $test_status)" >&2
            exit "$test_status"
        fi
        if (( diagnostic_status == 0 )); then
            echo "Binutils FAIL diagnostic found failing test logs" >&2
            exit 1
        fi
    '
echo 'BINUTILS_CRITICAL_TEST_SUITE=passed'
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        cd /build/binutils-2.45-m04-r1/build
        make tooldir=/usr DESTDIR=/tmp/alp-m04-binutils-stage-r1 install
        rm -rfv /tmp/alp-m04-binutils-stage-r1/usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
            /tmp/alp-m04-binutils-stage-r1/usr/share/doc/gprofng/
    '

# Run version/help smoke checks against the staged binaries and libraries.
for tool in ld as readelf objdump; do
    [[ -x "$STAGE_HOST/usr/bin/$tool" ]]
    tool_output=$(chroot "$LFS" /usr/bin/env LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
        "$STAGE_CHROOT/usr/bin/$tool" --version)
    first_line=${tool_output%%$'\n'*}
    printf '%s\n' "$first_line"
done
[[ -s "$STAGE_HOST/usr/lib/libbfd.so" || -L "$STAGE_HOST/usr/lib/libbfd.so" ]]
[[ -s "$STAGE_HOST/usr/lib/libopcodes.so" || -L "$STAGE_HOST/usr/lib/libopcodes.so" ]]
[[ ! -e "$STAGE_HOST/usr/lib/libbfd.a" && ! -e "$STAGE_HOST/usr/share/doc/gprofng" ]]
echo 'BINUTILS_STAGE_SMOKE=passed'

assert_alp_and_empty_db
[[ ! -s /sys/block/nbd0/pid ]]
{
    echo 'package=binutils version=2.45'
    echo "source_url=$SOURCE_URL"
    echo "source_md5=$EXPECTED_MD5"
    echo "source_sha256=$EXPECTED_SHA256"
    echo 'patches=none-required-by-LFS-12.4-systemd'
    echo 'install_mode=DESTDIR; rootfs_merge=forbidden'
    echo 'critical_test_suite=make -k check passed'
    echo "builder=$(hostname)"
} > "$PREFLIGHT"
python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name binutils --version 2.45 \
    --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST" | tee -a "$PREFLIGHT"
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
[[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
assert_alp_and_empty_db
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
