#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly ATTR_INSTALL_LOG="$DATA/logs/lfs-12.4-systemd/attr-ch8-install-resume-20260926T214341337230577Z.log"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/acl-2.3.2-ch8-$STAMP"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/acl-ch8-$STAMP.log}"

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
[[ -r "$LFS/sources/acl-2.3.2.tar.xz" && -r "$LFS/sources/md5sums" ]] || fail 'ACL source or official LFS source manifest is missing.'
if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    : "${ALPBAHOS_D34_ATTR_RUN_DIR:?D34 Attr evidence directory is required}"
    python3 - "$ALPBAHOS_D34_ATTR_RUN_DIR" <<'PY'
import json
import sys
from pathlib import Path

root = Path('/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs')
run = Path(sys.argv[1]).resolve(strict=True)
if root not in run.parents:
    raise SystemExit('Attr evidence path is outside the D34 replay store')
status = json.loads((run / 'resume-status.json').read_text())
if status.get('package') != 'attr' or status.get('result') != 'PASS' or status.get('continuation_exit_code') != 0:
    raise SystemExit('Attr D34 install continuation is not PASS')
log = (run / 'continuation.log').read_text(errors='replace')
for marker in ('Installed Attr 2.5.2.', '1 PASS, 1 known SELinux-label FAIL'):
    if marker not in log:
        raise SystemExit(f'Attr D34 continuation record is missing {marker}')
print('Verified the D34 Attr install and reviewed SELinux-label test exception.')
PY
else
    rg -q '^INSTALL_RESULT: PASS$' "$ATTR_INSTALL_LOG" || fail 'Attr 2.5.2 was not installed.'
fi
for path in "$LFS/usr/lib/libattr.so" "$LFS/usr/include/attr/libattr.h" "$LFS/usr/bin/getfattr"; do
    [[ -e "$path" || -L "$path" ]] || fail "Required Attr dependency is missing: $path"
done
for path in "$LFS/usr/bin/chacl" "$LFS/usr/bin/getfacl" "$LFS/usr/bin/setfacl" "$LFS/usr/lib/libacl.so" "$LFS/usr/lib/libacl.a" "$LFS/usr/include/acl/libacl.h" "$LFS/usr/share/doc/acl-2.3.2"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "ACL is already installed: $path"
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior ACL work: $WORK_ROOT"
if ps -eo comm= | awk '$1 == "make" || $1 == "runtest" || $1 == "dejagnu" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building and installing LFS Chapter 8 ACL 2.3.2.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "acl-2.3.2.tar.xz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/acl-2.3.2.tar.xz -C "$work_root"
        cd "$work_root/acl-2.3.2"
        ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/acl-2.3.2
        make
        set -o pipefail
        check_status=0
        if make check 2>&1 | tee acl-check-log; then
            check_status=0
        else
            check_status=$?
        fi
        fail_count=$(awk '\''/^FAIL: / { n++ } END { print n + 0 }'\'' acl-check-log)
        test_name=$(awk '\''/^FAIL: / { print; exit }'\'' acl-check-log)
        if test "$check_status" -eq 0; then
            test "$fail_count" -eq 0
            test_status=PASS
        else
            test "$fail_count" -eq 1
            test "$test_name" = "FAIL: test/cp.test"
            grep -F "# ERROR: 0" acl-check-log >/dev/null
            test_status=KNOWN_LFS_CP_TEST_FAILURE
        fi
        printf "ACL_TEST_EXIT=%s\\nACL_TEST_FAIL_COUNT=%s\\nACL_TEST_STATUS=%s\\n" "$check_status" "$fail_count" "$test_status"
        make install
        test -x /usr/bin/chacl
        test -x /usr/bin/getfacl
        test -x /usr/bin/setfacl
        test -e /usr/lib/libacl.so
        test -s /usr/include/acl/libacl.h
        test -d /usr/share/doc/acl-2.3.2
        printf "Installed ACL 2.3.2; test status: %s.\\n" "$test_status"
    ' acl-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
