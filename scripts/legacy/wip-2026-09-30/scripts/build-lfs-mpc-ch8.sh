#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly BINUTILS_TEST_LOG="$DATA/logs/lfs-12.4-systemd/binutils-ch8-20260926T212349Z-check.log"
readonly BINUTILS_INSTALL_LOG="$DATA/logs/lfs-12.4-systemd/binutils-ch8-20260926T212831Z-install.log"
readonly GMP_LOG="$DATA/logs/lfs-12.4-systemd/gmp-ch8-20260926T213337Z.log"
readonly MPFR_LOG="$DATA/logs/lfs-12.4-systemd/mpfr-ch8-20260926T213650812280449Z.log"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/mpc-1.3.1-ch8-$STAMP"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/mpc-ch8-$STAMP.log}"

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
[[ -r "$LFS/sources/mpc-1.3.1.tar.gz" && -r "$LFS/sources/md5sums" ]] || fail 'MPC source or official LFS source manifest is missing.'
if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    : "${ALPBAHOS_D34_BINUTILS_RUN_DIR:?D34 Binutils evidence directory is required}"
    : "${ALPBAHOS_D34_GMP_RUN_DIR:?D34 GMP evidence directory is required}"
    : "${ALPBAHOS_D34_MPFR_RUN_DIR:?D34 MPFR evidence directory is required}"
    python3 - "$ALPBAHOS_D34_BINUTILS_RUN_DIR" "$ALPBAHOS_D34_GMP_RUN_DIR" "$ALPBAHOS_D34_MPFR_RUN_DIR" <<'PY'
import json
import sys
from pathlib import Path

expected_root = Path('/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs')
def require_pass(path: str, package: str) -> tuple[dict, Path]:
    run_dir = Path(path).resolve(strict=True)
    if expected_root not in run_dir.parents:
        raise SystemExit(f'{package}: evidence path is outside the D34 replay store')
    status = json.loads((run_dir / 'status.json').read_text())
    if (status.get('package') != package or status.get('result') != 'PASS'
            or status.get('builder_exit_code') != 0 or status.get('continuation_exit_code', 0) != 0):
        raise SystemExit(f'{package}: D34 package status is not PASS')
    return status, run_dir

binutils, binutils_dir = require_pass(sys.argv[1], 'binutils')
gmp, gmp_dir = require_pass(sys.argv[2], 'gmp')
mpfr, mpfr_dir = require_pass(sys.argv[3], 'mpfr')
if '# FAIL:  0' not in (binutils_dir / 'package.log').read_text(errors='replace'):
    raise SystemExit('Binutils: D34 critical-check summary is missing or reports failures')
if 'critical check passed with 199 PASS tests' not in (gmp_dir / 'continuation.log').read_text(errors='replace'):
    raise SystemExit('GMP: D34 199-test critical check is not verified')
mpfr_log = (mpfr_dir / 'package.log').read_text(errors='replace')
for marker in ('MPFR_TEST_TOTAL=198', 'MPFR_TEST_PASS_COUNT=198', 'MPFR_TEST_FAIL_COUNT=0', 'Status: PASS'):
    if marker not in mpfr_log:
        raise SystemExit(f'MPFR: D34 check/install evidence lacks {marker}')
print('Verified D34 Binutils, portable GMP, and MPFR 198/198 check/install records.')
PY
else
    [[ -f "$BINUTILS_TEST_LOG" && -f "$BINUTILS_INSTALL_LOG" ]] || fail 'The Chapter 8 Binutils check/install logs are missing.'
    rg -q '^HOST_TEST_EXIT=0$' "$BINUTILS_TEST_LOG" || fail 'The Chapter 8 Binutils critical test did not pass.'
    rg -q '^INSTALL_EXIT=0$' "$BINUTILS_INSTALL_LOG" || fail 'The Chapter 8 Binutils install did not complete.'
    if rg -q '^FAIL:' "$BINUTILS_TEST_LOG"; then
        fail 'The Chapter 8 Binutils test log contains FAIL lines.'
    fi
    rg -q '^GMP_TEST_PASS_COUNT=199$' "$GMP_LOG" || fail 'The Chapter 8 GMP critical test did not pass all 199 tests.'
    rg -q '^Status: PASS$' "$GMP_LOG" || fail 'The Chapter 8 GMP install did not complete.'
    rg -q '^MPFR_TEST_TOTAL=198$' "$MPFR_LOG" || fail 'The Chapter 8 MPFR test suite is incomplete.'
    rg -q '^MPFR_TEST_PASS_COUNT=198$' "$MPFR_LOG" || fail 'The Chapter 8 MPFR critical test did not pass all 198 tests.'
    rg -q '^Status: PASS$' "$MPFR_LOG" || fail 'The Chapter 8 MPFR install did not complete.'
fi
sudo -n chroot "$LFS" /usr/bin/ld --version | head -n 1 | grep -F 'GNU Binutils) 2.45' >/dev/null || fail 'The Chapter 8 Binutils linker is not installed.'
sudo -n chroot "$LFS" /usr/bin/gcc --version | head -n 1 | grep -F '15.2.0' >/dev/null || fail 'The LFS GCC toolchain is not installed.'
for path in "$LFS/usr/lib/libgmp.so" "$LFS/usr/lib/libmpfr.so" "$LFS/usr/include/gmp.h" "$LFS/usr/include/mpfr.h"; do
    [[ -e "$path" || -L "$path" ]] || fail "Required dependency is missing: $path"
done
for path in "$LFS/usr/lib/libmpc.so" "$LFS/usr/lib/libmpc.a" "$LFS/usr/include/mpc.h" "$LFS/usr/share/doc/mpc-1.3.1"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "MPC is already installed: $path"
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior MPC work: $WORK_ROOT"
if ps -eo comm= | awk '$1 == "make" || $1 == "runtest" || $1 == "dejagnu" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building and installing LFS Chapter 8 MPC 1.3.1.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "mpc-1.3.1.tar.gz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/mpc-1.3.1.tar.gz -C "$work_root"
        cd "$work_root/mpc-1.3.1"
        ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/mpc-1.3.1
        make
        make html
        set -o pipefail
        make check 2>&1 | tee mpc-check-log
        total=$(awk '\''/^# TOTAL:/ { n=$3 } END { print n + 0 }'\'' mpc-check-log)
        passed=$(awk '\''/^# PASS:/ { n=$3 } END { print n + 0 }'\'' mpc-check-log)
        failed=$(awk '\''/^# FAIL:/ { n=$3 } END { print n + 0 }'\'' mpc-check-log)
        printf "MPC_TEST_TOTAL=%s\\nMPC_TEST_PASS_COUNT=%s\\nMPC_TEST_FAIL_COUNT=%s\\n" "$total" "$passed" "$failed"
        test "$total" -eq 74
        test "$passed" -eq 74
        test "$failed" -eq 0
        make install
        make install-html
        test -e /usr/lib/libmpc.so
        test -s /usr/include/mpc.h
        test -d /usr/share/doc/mpc-1.3.1
        printf "Installed MPC 1.3.1 after its Chapter 8 check completed.\\n"
    ' mpc-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
