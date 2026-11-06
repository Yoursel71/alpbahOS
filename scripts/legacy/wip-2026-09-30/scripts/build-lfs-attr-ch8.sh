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
readonly MPC_LOG="$DATA/logs/lfs-12.4-systemd/mpc-ch8-20260926T213917895137305Z.log"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/attr-2.5.2-ch8-$STAMP"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/attr-ch8-$STAMP.log}"

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
[[ -r "$LFS/sources/attr-2.5.2.tar.gz" && -r "$LFS/sources/md5sums" ]] || fail 'Attr source or official LFS source manifest is missing.'
if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    : "${ALPBAHOS_D34_BINUTILS_RUN_DIR:?D34 Binutils evidence directory is required}"
    : "${ALPBAHOS_D34_GMP_RUN_DIR:?D34 GMP evidence directory is required}"
    : "${ALPBAHOS_D34_MPFR_RUN_DIR:?D34 MPFR evidence directory is required}"
    : "${ALPBAHOS_D34_MPC_RUN_DIR:?D34 MPC evidence directory is required}"
    python3 - "$ALPBAHOS_D34_BINUTILS_RUN_DIR" "$ALPBAHOS_D34_GMP_RUN_DIR" "$ALPBAHOS_D34_MPFR_RUN_DIR" "$ALPBAHOS_D34_MPC_RUN_DIR" <<'PY'
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

binutils, bdir = require_pass(sys.argv[1], 'binutils')
gmp, gdir = require_pass(sys.argv[2], 'gmp')
mpfr, fdir = require_pass(sys.argv[3], 'mpfr')
mpc, cdir = require_pass(sys.argv[4], 'mpc')
checks = [
    (bdir / 'package.log', '# FAIL:  0'),
    (gdir / 'continuation.log', 'critical check passed with 199 PASS tests'),
    (fdir / 'package.log', 'MPFR_TEST_PASS_COUNT=198'),
    (fdir / 'package.log', 'Status: PASS'),
    (cdir / 'package.log', 'MPC_TEST_PASS_COUNT=74'),
    (cdir / 'package.log', 'Status: PASS'),
]
for path, marker in checks:
    if marker not in path.read_text(errors='replace'):
        raise SystemExit(f'{path.parent.name}: required check/install evidence is missing: {marker}')
print('Verified D34 Binutils, GMP, MPFR, and MPC dependency/test records.')
PY
else
    [[ -f "$BINUTILS_TEST_LOG" && -f "$BINUTILS_INSTALL_LOG" ]] || fail 'The Chapter 8 Binutils check/install logs are missing.'
    rg -q '^HOST_TEST_EXIT=0$' "$BINUTILS_TEST_LOG" || fail 'The Chapter 8 Binutils critical test did not pass.'
    rg -q '^INSTALL_EXIT=0$' "$BINUTILS_INSTALL_LOG" || fail 'The Chapter 8 Binutils install did not complete.'
    if rg -q '^FAIL:' "$BINUTILS_TEST_LOG"; then fail 'The Chapter 8 Binutils test log contains FAIL lines.'; fi
    rg -q '^GMP_TEST_PASS_COUNT=199$' "$GMP_LOG" || fail 'GMP critical tests are incomplete.'
    rg -q '^Status: PASS$' "$GMP_LOG" || fail 'The Chapter 8 GMP install did not complete.'
    rg -q '^MPFR_TEST_PASS_COUNT=198$' "$MPFR_LOG" || fail 'MPFR critical tests are incomplete.'
    rg -q '^Status: PASS$' "$MPFR_LOG" || fail 'The Chapter 8 MPFR install did not complete.'
    rg -q '^# PASS:  74$' "$MPC_LOG" || fail 'The Chapter 8 MPC tests are incomplete.'
    rg -q '^Status: PASS$' "$MPC_LOG" || fail 'The Chapter 8 MPC install did not complete.'
fi
sudo -n chroot "$LFS" /usr/bin/ld --version | head -n 1 | grep -F 'GNU Binutils) 2.45' >/dev/null || fail 'The Chapter 8 Binutils linker is not installed.'
sudo -n chroot "$LFS" /usr/bin/gcc --version | head -n 1 | grep -F '15.2.0' >/dev/null || fail 'The LFS GCC toolchain is not installed.'
for path in "$LFS/usr/lib/libgmp.so" "$LFS/usr/lib/libmpfr.so" "$LFS/usr/lib/libmpc.so"; do
    [[ -e "$path" || -L "$path" ]] || fail "Required toolchain dependency is missing: $path"
done
for path in "$LFS/usr/bin/attr" "$LFS/usr/bin/getfattr" "$LFS/usr/bin/setfattr" "$LFS/usr/lib/libattr.so" "$LFS/usr/lib/libattr.a" "$LFS/usr/include/attr/libattr.h" "$LFS/usr/share/doc/attr-2.5.2"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Attr is already installed: $path"
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Attr work: $WORK_ROOT"
if ps -eo comm= | awk '$1 == "make" || $1 == "runtest" || $1 == "dejagnu" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building and installing LFS Chapter 8 Attr 2.5.2.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "attr-2.5.2.tar.gz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/attr-2.5.2.tar.gz -C "$work_root"
        cd "$work_root/attr-2.5.2"
        ./configure --prefix=/usr --disable-static --sysconfdir=/etc --docdir=/usr/share/doc/attr-2.5.2
        make
        set -o pipefail
        make check 2>&1 | tee attr-check-log
        make install
        test -x /usr/bin/attr
        test -x /usr/bin/getfattr
        test -x /usr/bin/setfattr
        test -e /usr/lib/libattr.so
        test -s /usr/include/attr/libattr.h
        test -d /usr/share/doc/attr-2.5.2
        printf "Installed Attr 2.5.2 after its ext4-backed Chapter 8 check completed.\\n"
    ' attr-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
