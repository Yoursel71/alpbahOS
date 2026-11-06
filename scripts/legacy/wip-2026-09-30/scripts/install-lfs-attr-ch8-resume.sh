#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCE_ROOT=/sources/attr-2.5.2-ch8-20260926T214210313624340Z/attr-2.5.2
readonly BUILD_LOG="$DATA/logs/lfs-12.4-systemd/attr-ch8-20260926T214210313624340Z.log"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="$LOG_DIR/attr-ch8-install-resume-$STAMP.log"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
[[ -f "$BUILD_LOG" ]] || fail 'The failed Attr build/check log is missing.'
rg -q '^attr-2.5.2.tar.gz: OK$' "$BUILD_LOG" || fail 'The official Attr source checksum did not pass.'
if rg -q '^Status: PASS$' "$BUILD_LOG"; then fail 'The Attr log already reports a completed installation.'; fi
for path in "$LFS/usr/bin/attr" "$LFS/usr/bin/getfattr" "$LFS/usr/bin/setfattr" "$LFS/usr/lib/libattr.so" "$LFS/usr/include/attr/libattr.h" "$LFS/usr/share/doc/attr-2.5.2"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Refusing to overwrite an existing Attr path: $path"
done
[[ -d "$LFS$SOURCE_ROOT" ]] || fail "The retained Attr source tree is missing: $SOURCE_ROOT"
if ps -eo comm= | awk '$1 == "make" || $1 == "runtest" || $1 == "dejagnu" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1

printf 'Resuming Attr 2.5.2 installation after an environment-specific check failure.\n'
printf 'Source root: %s\nStarted: %s\n' "$SOURCE_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Recorded check result: 1/2 tests passed; getfattr output includes Fedora security.selinux labels.\n\n'

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        cd "$1"
        test -s test-suite.log
        grep -F "# TOTAL: 2" test-suite.log >/dev/null
        grep -F "# PASS:  1" test-suite.log >/dev/null
        grep -F "# FAIL:  1" test-suite.log >/dev/null
        grep -F "FAIL test/root/getfattr.test" test-suite.log >/dev/null
        grep -F "security.selinux=\"unconfined_u:object_r:unlabeled_t:s0\"" test-suite.log >/dev/null
        printf "Verified Attr check failure is limited to the test comparison including Fedora security.selinux labels.\n"
        make install
        test -x /usr/bin/attr
        test -x /usr/bin/getfattr
        test -x /usr/bin/setfattr
        test -e /usr/lib/libattr.so
        test -s /usr/include/attr/libattr.h
        test -d /usr/share/doc/attr-2.5.2
        printf "Attr 2.5.2 install postconditions passed.\n"
    ' attr-install-resume "$SOURCE_ROOT"

printf '\nFinished: %s\nTEST_RESULT: ENVIRONMENT_SPECIFIC_FAILURE (1/2 PASS; getfattr SELinux label mismatch)\nINSTALL_RESULT: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
