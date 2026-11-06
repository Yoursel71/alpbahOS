#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly ACL_LOG_GLOB="$DATA/logs/lfs-12.4-systemd/acl-ch8-*.log"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/libcap-2.76-ch8-$STAMP"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/libcap-ch8-$STAMP.log}"

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
[[ -r "$LFS/sources/libcap-2.76.tar.xz" && -r "$LFS/sources/md5sums" ]] || fail 'Libcap source or official LFS source manifest is missing.'
if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    : "${ALPBAHOS_D34_ACL_RUN_DIR:?D34 ACL evidence directory is required}"
    python3 - "$ALPBAHOS_D34_ACL_RUN_DIR" <<'PY'
import json
import sys
from pathlib import Path

root = Path('/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs')
run = Path(sys.argv[1]).resolve(strict=True)
if root not in run.parents:
    raise SystemExit('ACL evidence path is outside the D34 replay store')
status = json.loads((run / 'status.json').read_text())
if status.get('package') != 'acl' or status.get('result') != 'PASS' or status.get('builder_exit_code') != 0:
    raise SystemExit('ACL D34 package/install status is not PASS')
log = (run / 'package.log').read_text(errors='replace')
if 'ACL_TEST_STATUS=KNOWN_LFS_CP_TEST_FAILURE' not in log or 'Status: PASS' not in log:
    raise SystemExit('ACL D34 known-test/install evidence is incomplete')
print('Verified D34 ACL install and documented LFS cp.test exception.')
PY
else
    shopt -s nullglob
    acl_logs=( $ACL_LOG_GLOB )
    shopt -u nullglob
    [[ "${#acl_logs[@]}" -ge 1 ]] || fail 'The ACL Chapter 8 build/install log is missing.'
    acl_log=${acl_logs[-1]}
    rg -q '^Status: PASS$' "$acl_log" || fail 'The Chapter 8 ACL install did not complete.'
fi
for path in "$LFS/usr/lib/libattr.so" "$LFS/usr/lib/libacl.so" "$LFS/usr/include/acl/libacl.h"; do
    [[ -e "$path" || -L "$path" ]] || fail "Required ACL/Attr dependency is missing: $path"
done
for path in "$LFS/usr/sbin/capsh" "$LFS/usr/sbin/getcap" "$LFS/usr/sbin/getpcaps" "$LFS/usr/sbin/setcap" "$LFS/usr/lib/libcap.so" "$LFS/usr/lib/libpsx.so" "$LFS/usr/lib/libcap.a"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Libcap is already installed: $path"
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Libcap work: $WORK_ROOT"
if ps -eo comm= | awk '$1 == "make" || $1 == "runtest" || $1 == "dejagnu" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building and installing LFS Chapter 8 Libcap 2.76.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "libcap-2.76.tar.xz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/libcap-2.76.tar.xz -C "$work_root"
        cd "$work_root/libcap-2.76"
        sed -i '\''/install -m.*STA/d'\'' libcap/Makefile
        make prefix=/usr lib=lib
        set -o pipefail
        make test 2>&1 | tee libcap-test-log
        printf "LIBCAP_TEST_RESULT=PASS\\n"
        make prefix=/usr lib=lib install
        test -x /usr/sbin/capsh
        test -x /usr/bin/getcap
        test -x /usr/bin/getpcaps
        test -x /usr/bin/setcap
        test -e /usr/lib/libcap.so
        test -e /usr/lib/libpsx.so
        test ! -e /usr/lib/libcap.a
        printf "Installed Libcap 2.76 after make test passed.\\n"
    ' libcap-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
