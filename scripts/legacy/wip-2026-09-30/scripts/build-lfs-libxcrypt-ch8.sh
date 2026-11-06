#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly LIBCAP_STATUS="$DATA/logs/lfs-12.4-systemd/libcap-ch8-20260926T214516482039212Z.status"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/libxcrypt-4.4.38-ch8-$STAMP"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/libxcrypt-ch8-$STAMP.log}"

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
[[ -r "$LFS/sources/libxcrypt-4.4.38.tar.xz" && -r "$LFS/sources/md5sums" ]] || fail 'Libxcrypt source or official LFS source manifest is missing.'
if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    : "${ALPBAHOS_D34_LIBCAP_RUN_DIR:?D34 Libcap evidence directory is required}"
    python3 - "$ALPBAHOS_D34_LIBCAP_RUN_DIR" <<'PY'
import json
import sys
from pathlib import Path

root = Path('/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs')
run = Path(sys.argv[1]).resolve(strict=True)
if root not in run.parents:
    raise SystemExit('Libcap evidence path is outside the D34 replay store')
status = json.loads((run / 'resume-status.json').read_text())
if status.get('package') != 'libcap' or status.get('result') != 'PASS' or status.get('continuation_exit_code') != 0:
    raise SystemExit('Libcap D34 install verification is not PASS')
if 'LIBCAP_TEST_RESULT=PASS' not in (run / 'package.log').read_text(errors='replace'):
    raise SystemExit('Libcap D34 make test PASS record is missing')
if 'Verified Libcap 2.76 installed commands' not in (run / 'continuation.log').read_text(errors='replace'):
    raise SystemExit('Libcap D34 install/runtime verification is missing')
print('Verified D34 Libcap make test and installed runtime.')
PY
else
    rg -q '^build_test=PASS \(make test\)$' "$LIBCAP_STATUS" || fail 'The Libcap test/install status is incomplete.'
fi
for path in "$LFS/usr/lib/libcap.so" "$LFS/usr/lib/libpsx.so" "$LFS/usr/sbin/getcap"; do
    [[ -e "$path" || -L "$path" ]] || fail "Required Libcap dependency is missing: $path"
done
for path in "$LFS/usr/lib/libcrypt.so" "$LFS/usr/lib/libcrypt.so.2" "$LFS/usr/lib/libcrypt.a" "$LFS/usr/include/crypt.h"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Libxcrypt is already installed: $path"
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Libxcrypt work: $WORK_ROOT"
if ps -eo comm= | awk '$1 == "make" || $1 == "runtest" || $1 == "dejagnu" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building and installing LFS Chapter 8 Libxcrypt 4.4.38.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "libxcrypt-4.4.38.tar.xz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/libxcrypt-4.4.38.tar.xz -C "$work_root"
        cd "$work_root/libxcrypt-4.4.38"
        ./configure --prefix=/usr --enable-hashes=strong,glibc --enable-obsolete-api=no --disable-static --disable-failure-tokens
        make
        set -o pipefail
        make check 2>&1 | tee libxcrypt-check-log
        printf "LIBXCRYPT_CHECK_RESULT=PASS\\n"
        make install
        test -e /usr/lib/libcrypt.so
        test -e /usr/lib/libcrypt.so.2
        test -s /usr/include/crypt.h
        printf "Installed Libxcrypt 4.4.38 after make check passed.\\n"
    ' libxcrypt-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
