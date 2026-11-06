#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCE=/sources/mpfr-4.2.2.tar.xz
readonly BINUTILS_TEST_LOG="$DATA/logs/lfs-12.4-systemd/binutils-ch8-20260926T212349Z-check.log"
readonly BINUTILS_INSTALL_LOG="$DATA/logs/lfs-12.4-systemd/binutils-ch8-20260926T212831Z-install.log"
readonly GMP_LOG="$DATA/logs/lfs-12.4-systemd/gmp-ch8-20260926T213337Z.log"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/mpfr-4.2.2-ch8-$STAMP"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/mpfr-ch8-$STAMP.log}"

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
[[ -r "$LFS/sources/mpfr-4.2.2.tar.xz" && -r "$LFS/sources/md5sums" ]] || fail 'MPFR source or official LFS source manifest is missing.'
if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    : "${ALPBAHOS_D34_BINUTILS_RUN_DIR:?D34 Binutils evidence directory is required}"
    : "${ALPBAHOS_D34_GMP_RUN_DIR:?D34 GMP evidence directory is required}"
    python3 - "$ALPBAHOS_D34_BINUTILS_RUN_DIR" "$ALPBAHOS_D34_GMP_RUN_DIR" <<'PY'
import json
import sys
from pathlib import Path

def require_pass(run_dir: Path, package: str) -> dict:
    expected_root = Path('/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs')
    run_dir = run_dir.resolve(strict=True)
    if expected_root not in run_dir.parents:
        raise SystemExit(f'{package}: evidence path is outside the D34 replay store')
    status = json.loads((run_dir / 'status.json').read_text())
    if status.get('package') != package or status.get('result') != 'PASS' or status.get('builder_exit_code') != 0:
        raise SystemExit(f'{package}: D34 package status is not PASS')
    if status.get('continuation_exit_code', 0) != 0:
        raise SystemExit(f'{package}: D34 continuation did not pass')
    return status

binutils = require_pass(Path(sys.argv[1]), 'binutils')
gmp = require_pass(Path(sys.argv[2]), 'gmp')
binutils_log = Path(binutils['stream_path']).parent / 'package.log'
if '# FAIL:  0' not in binutils_log.read_text(errors='replace'):
    raise SystemExit('Binutils: D34 critical-check summary is missing or reports failures')
gmp_dir = Path(gmp['stream_path']).parent
continuation = (gmp_dir / 'continuation.log').read_text(errors='replace')
if 'critical check passed with 199 PASS tests' not in continuation:
    raise SystemExit('GMP: D34 continuation lacks the 199-test critical-check PASS')
source = Path('/mnt/lfs/sources/gmp-6.3.0-ch8-20260929T230657Z/gmp-6.3.0')
makefile = (source / 'Makefile').read_text(errors='replace')
if 'CFLAGS = -O2 -march=x86-64 -mtune=generic' not in makefile or '-march=znver3' in makefile:
    raise SystemExit('GMP: configured Makefile does not use the generic x86_64 baseline')
mparam = source / 'gmp-mparam.h'
if not mparam.is_symlink() or mparam.resolve() != source / 'mpn/x86_64/fat/gmp-mparam.h':
    raise SystemExit('GMP: runtime-dispatched fat parameters are not selected')
print('Verified the D34 Binutils check and portable GMP 199/199 check/configuration.')
PY
else
    [[ -f "$BINUTILS_TEST_LOG" && -f "$BINUTILS_INSTALL_LOG" ]] || fail 'The Chapter 8 Binutils check/install logs are missing.'
    rg -q '^HOST_TEST_EXIT=0$' "$BINUTILS_TEST_LOG" || fail 'The Chapter 8 Binutils critical test did not pass.'
    rg -q '^INSTALL_EXIT=0$' "$BINUTILS_INSTALL_LOG" || fail 'The Chapter 8 Binutils install did not complete.'
    if rg -q '^FAIL:' "$BINUTILS_TEST_LOG"; then
        fail 'The Chapter 8 Binutils test log contains FAIL lines.'
    fi
    [[ -f "$GMP_LOG" ]] || fail 'The Chapter 8 GMP build log is missing.'
    rg -q '^GMP_TEST_PASS_COUNT=199$' "$GMP_LOG" || fail 'The Chapter 8 GMP critical test did not pass all 199 tests.'
    rg -q '^Status: PASS$' "$GMP_LOG" || fail 'The Chapter 8 GMP install did not complete.'
fi
sudo -n chroot "$LFS" /usr/bin/ld --version | head -n 1 | grep -F 'GNU Binutils) 2.45' >/dev/null || fail 'The Chapter 8 Binutils linker is not installed.'
sudo -n chroot "$LFS" /usr/bin/gcc --version | head -n 1 | grep -F '15.2.0' >/dev/null || fail 'The LFS GCC toolchain is not installed.'
for path in "$LFS/usr/lib/libgmp.so" "$LFS/usr/lib/libgmpxx.so" "$LFS/usr/include/gmp.h" "$LFS/usr/share/doc/gmp-6.3.0"; do
    [[ -e "$path" || -L "$path" ]] || fail "Required GMP dependency is missing: $path"
done
for path in "$LFS/usr/lib/libmpfr.so" "$LFS/usr/lib/libmpfr.so.6" "$LFS/usr/lib/libmpfr.a" "$LFS/usr/include/mpfr.h" "$LFS/usr/share/doc/mpfr-4.2.2"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "MPFR is already installed: $path"
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior MPFR work: $WORK_ROOT"
if ps -eo comm= | awk '$1 == "make" || $1 == "runtest" || $1 == "dejagnu" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building and installing LFS Chapter 8 MPFR 4.2.2.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "mpfr-4.2.2.tar.xz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/mpfr-4.2.2.tar.xz -C "$work_root"
        cd "$work_root/mpfr-4.2.2"
        ./configure --prefix=/usr --disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr-4.2.2
        make
        make html
        set -o pipefail
        make check 2>&1 | tee mpfr-check-log
        total=$(awk '\''/^# TOTAL:/ { n=$3 } END { print n + 0 }'\'' mpfr-check-log)
        passed=$(awk '\''/^# PASS:/ { n=$3 } END { print n + 0 }'\'' mpfr-check-log)
        failed=$(awk '\''/^# FAIL:/ { n=$3 } END { print n + 0 }'\'' mpfr-check-log)
        printf "MPFR_TEST_TOTAL=%s\\nMPFR_TEST_PASS_COUNT=%s\\nMPFR_TEST_FAIL_COUNT=%s\\n" "$total" "$passed" "$failed"
        test "$total" -eq 198
        test "$passed" -eq 198
        test "$failed" -eq 0
        make install
        make install-html
        test -e /usr/lib/libmpfr.so
        test -s /usr/include/mpfr.h
        test -d /usr/share/doc/mpfr-4.2.2
        printf "Installed MPFR 4.2.2; critical check passed with %s/%s PASS tests.\\n" "$passed" "$total"
    ' mpfr-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
