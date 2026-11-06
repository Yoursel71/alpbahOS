#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly PASS2_LOG="$DATA/logs/lfs-12.4-systemd/gcc-pass2-20260926T165648Z.log"
readonly BINUTILS_LOG="$DATA/logs/lfs-12.4-systemd/binutils-ch8-20260926T212831Z-install.log"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/gcc-15.2.0-ch8-$STAMP"
readonly BUILD_ROOT="$WORK_ROOT/build"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/gcc-ch8-build-$STAMP.log}"
readonly BUILD_JOBS=8
readonly CHROOT_LOG_DIR="$WORK_ROOT/gcc-logs"
readonly HOST_LOG_DIR="$LFS$CHROOT_LOG_DIR"
readonly CONFIGURE_LOG="$CHROOT_LOG_DIR/configure.log"
readonly BUILD_LOG="$CHROOT_LOG_DIR/compile.log"
readonly CHECK_LOG="$CHROOT_LOG_DIR/check.log"
readonly SUMMARY_LOG="$CHROOT_LOG_DIR/test-summary.log"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA" ]] || fail 'The LFS target or HDD build data directory is missing.'
if [[ -z "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    [[ -d "$DATA/lfs" ]] || fail 'The HDD-backed LFS build directory is missing.'
fi
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
[[ -r "$LFS/sources/gcc-15.2.0.tar.xz" && -r "$LFS/sources/md5sums" ]] || fail 'GCC source or official LFS source manifest is missing.'
if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    : "${ALPBAHOS_D34_BINUTILS_RUN_DIR:?D34 Binutils evidence directory is required}"
    python3 - "$ALPBAHOS_D34_BINUTILS_RUN_DIR" <<'PY'
import json
import sys
from pathlib import Path

root = Path('/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs')
run = Path(sys.argv[1]).resolve(strict=True)
if root not in run.parents:
    raise SystemExit('Binutils evidence path is outside the D34 replay store')
status = json.loads((run / 'status.json').read_text())
if status.get('package') != 'binutils' or status.get('result') != 'PASS' or status.get('builder_exit_code') != 0:
    raise SystemExit('Binutils D34 install/check status is not PASS')
if '# FAIL:  0' not in (run / 'package.log').read_text(errors='replace'):
    raise SystemExit('Binutils D34 check summary is missing or reports failures')
print('Verified D34 Binutils install/check; GCC Pass 2 will be checked in the target root.')
PY
else
    [[ -f "$PASS2_LOG" ]] || fail 'The GCC Pass 2 install log is missing.'
    rg -q 'Installed LFS GCC Pass 2 into /mnt/lfs/usr' "$PASS2_LOG" || fail 'The GCC Pass 2 install was not recorded as complete.'
    rg -q '^INSTALL_EXIT=0$' "$BINUTILS_LOG" || fail 'The Chapter 8 Binutils install did not complete.'
fi
for path in "$LFS/usr/bin/ld" "$LFS/usr/lib/libgmp.so" "$LFS/usr/lib/libmpfr.so" "$LFS/usr/lib/libmpc.so" "$LFS/usr/lib/libz.so" "$LFS/usr/include/gmp.h" "$LFS/usr/include/mpfr.h" "$LFS/usr/include/mpc.h" "$LFS/usr/include/zlib.h"; do
    [[ -e "$path" || -L "$path" ]] || fail "Required GCC dependency is missing: $path"
done
for path in "$LFS/usr/bin/gcc" "$LFS/usr/bin/g++" "$LFS/usr/bin/cc" "$LFS/usr/lib/gcc/x86_64-lfs-linux-gnu/15.2.0"; do
    [[ -e "$path" || -L "$path" ]] || fail "The expected GCC Pass 2 output is missing: $path"
done
sudo -n chroot "$LFS" /usr/bin/gcc --version | head -n 1 | grep -F '15.2.0' >/dev/null || fail 'GCC Pass 2 version check failed.'
sudo -n chroot "$LFS" /usr/bin/ld --version | head -n 1 | grep -F 'GNU Binutils) 2.45' >/dev/null || fail 'Chapter 8 Binutils is not active.'
awk -F: '$1 == "tester" { uid=$3; gid=$4 } END { if (uid < 1 || gid < 1) exit 1 }' "$LFS/etc/passwd" || fail 'The non-privileged LFS tester account is missing.'
awk -F: '$1 == "tester" { found=1 } END { exit found ? 0 : 1 }' "$LFS/etc/group" || fail 'The LFS tester group is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior GCC work: $WORK_ROOT"
if ps -eo comm= | awk '$1 == "make" || $1 == "runtest" || $1 == "dejagnu" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building and testing LFS Chapter 8 GCC 15.2.0.\n'
printf 'LFS root: %s\nIsolated source/build root: %s\nBuild MAKEFLAGS: -j%s; GCC check MAKEFLAGS: -j4\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$BUILD_JOBS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Existing GCC Pass 2 tree and installed toolchain are preserved; final GCC will be installed only after test-log review.\n'
printf 'Configure log: %s/configure.log\nCompile log: %s/compile.log\nCheck log: %s/check.log\nSummary log: %s/test-summary.log\n\n' "$HOST_LOG_DIR" "$HOST_LOG_DIR" "$HOST_LOG_DIR" "$HOST_LOG_DIR"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX "MAKEFLAGS=-j$BUILD_JOBS" \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        configure_log="$2"
        build_log="$3"
        check_log="$4"
        summary_log="$5"

        mapfile -t expected < <(awk '\''$2 == "gcc-15.2.0.tar.xz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)
        mkdir -pv "$work_root"
        tar -xf /sources/gcc-15.2.0.tar.xz -C "$work_root"
        mkdir -pv "$work_root/gcc-logs"
        cd "$work_root/gcc-15.2.0"
        case "$(uname -m)" in
          x86_64) sed -e '\''/m64=/s/lib64/lib/'\'' -i.orig gcc/config/i386/t-linux64 ;;
        esac
        mkdir -v build
        cd build
        if ../configure --prefix=/usr LD=ld --enable-languages=c,c++ --enable-default-pie --enable-default-ssp --enable-host-pie --disable-multilib --disable-bootstrap --disable-fixincludes --with-system-zlib >"$configure_log" 2>&1; then
            printf "GCC_CONFIGURE_RESULT=PASS\\n"
        else
            status=$?
            printf "GCC_CONFIGURE_RESULT=FAIL exit=%s\\n" "$status"
            tail -n 50 "$configure_log"
            exit "$status"
        fi
        if make MAKEFLAGS=-j8 >"$build_log" 2>&1; then
            printf "GCC_BUILD_RESULT=PASS\\n"
        else
            status=$?
            printf "GCC_BUILD_RESULT=FAIL exit=%s\\n" "$status"
            tail -n 60 "$build_log"
            exit "$status"
        fi
        sed -e '\''/cpython/d'\'' -i ../gcc/testsuite/gcc.dg/plugin/plugin.exp
        ulimit -s -H unlimited
        chown -R tester:tester .
        if su tester -c '\''PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j4 make -k check'\'' >"$check_log" 2>&1; then
            check_status=0
        else
            check_status=$?
        fi
        if su tester -c '\''PATH=/usr/bin:/usr/sbin ../contrib/test_summary'\'' >"$summary_log" 2>&1; then
            summary_status=0
        else
            summary_status=$?
        fi
        printf "GCC_CHECK_EXIT=%s\\nGCC_TEST_SUMMARY_EXIT=%s\\n" "$check_status" "$summary_status"
        printf "GCC_TEST_LOG_SIZE=%s bytes\\n" "$(wc -c <"$check_log")"
        printf "GCC_TEST_SUMMARY_EXCERPT:\\n"
        tail -n 80 "$summary_log"
        printf "GCC_BUILD_TEST_RESULT=REVIEW_REQUIRED\\n"
        printf "GCC_BUILD_DIR=%s\\n" "$PWD"
    ' gcc-ch8 "$WORK_ROOT" "$CONFIGURE_LOG" "$BUILD_LOG" "$CHECK_LOG" "$SUMMARY_LOG"

printf '\nFinished: %s\nBuild/test phase: complete; GCC results need review before install\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
