#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly LFS_DATA="$DATA/lfs"
readonly SOURCE_REL=/sources/glibc-2.42-ch8-20260926T183002Z/glibc-2.42
readonly BUILD_REL="$SOURCE_REL/build"
readonly RUN_ID="${1:-$(date -u +%Y%m%dT%H%M%SZ)}"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="$LOG_DIR/glibc-ch8-check-resume-$RUN_ID.log"
readonly STATUS="$LOG_DIR/glibc-ch8-check-resume-$RUN_ID.status"

readonly -a COMPLETED_SUBDIRS=(
    csu iconv locale localedata iconvdata assert ctype intl catgets math
    setjmp signal stdlib stdio-common libio dlfcn nptl rt malloc
)

readonly -a ALL_SUBDIRS=(
    csu iconv locale localedata iconvdata assert ctype intl catgets math
    setjmp signal stdlib stdio-common libio dlfcn nptl rt malloc string
    wcsmbs timezone time dirent posix io termios resource misc socket sysvipc
    gmon gnulib wctype manual po argp conform debug mathvec support nptl_db
    inet resolv nss hesiod sunrpc nis nscd login elf
)

readonly -a REMAINING_SUBDIRS=(
    string wcsmbs timezone time dirent posix io termios resource misc socket
    sysvipc gmon gnulib wctype manual po argp conform debug mathvec support
    nptl_db inet resolv nss hesiod sunrpc nis nscd login elf
)

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$LFS_DATA" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$LFS_DATA")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'

readonly SOURCE="$LFS$SOURCE_REL"
readonly BUILD="$LFS$BUILD_REL"
[[ -f "$SOURCE/Makefile" && -f "$BUILD/config.status" ]] || fail 'The existing configured Glibc Chapter 8 build tree is missing.'
[[ -x "$SOURCE/scripts/merge-test-results.sh" ]] || fail 'Glibc test-result merger is missing.'

for dir in "${COMPLETED_SUBDIRS[@]}"; do
    summary="$BUILD/$dir/subdir-tests.sum"
    [[ -s "$summary" ]] || fail "Previously completed test summary is missing: $dir"
    if grep -Eq '^(FAIL|ERROR|UNRESOLVED|XPASS):' "$summary"; then
        fail "The existing test summary for $dir contains a failing or unresolved result."
    fi
done
if grep -hE '^(FAIL|ERROR|UNRESOLVED|XPASS):' "$BUILD"/*.test-result 2>/dev/null; then
    fail 'A prior top-level Glibc result is failing or unresolved.'
fi

if pgrep -af 'make (check|.*subdir=.*tests)' | grep -v '[r]esume-lfs-glibc-ch8-check'; then
    fail 'Another make check/tests process is already active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
[[ ! -e "$STATUS" ]] || fail "Refusing to overwrite an existing run status: $STATUS"
exec >"$LOG" 2>&1

printf 'Resuming Glibc 2.42 make check at string; earlier test summaries are retained.\n'
printf 'LFS root: %s\nSource tree: %s\nBuild tree: %s\n' "$LFS" "$SOURCE_REL" "$BUILD_REL"
printf 'Run ID: %s\nStarted: %s\n' "$RUN_ID" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Completed subdirectories with prior passing summaries: %s\n' "${COMPLETED_SUBDIRS[*]}"
printf 'Subdirectories to finish: %s\n\n' "${REMAINING_SUBDIRS[*]}"

CHECK_RC=0
sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        unset MAKEFLAGS TESTSUITEFLAGS
        cd "$1/build"
        make check "subdirs=$2"
    ' glibc-check-resume "$SOURCE_REL" "${REMAINING_SUBDIRS[*]}" || CHECK_RC=$?

if (( CHECK_RC != 0 )); then
    printf 'Resumed make check failed with exit %d.\n' "$CHECK_RC"
    printf 'exit=%d\n' "$CHECK_RC" > "$STATUS"
    exit "$CHECK_RC"
fi

AGGREGATE_RC=0
sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        source_root="$1"
        build_root="$1/build"
        shift
        for dir in "$@"; do
            test -s "$build_root/$dir/subdir-tests.sum" || {
                printf "ERROR: missing test summary for %s\\n" "$dir" >&2
                exit 2
            }
        done
        "$source_root/scripts/merge-test-results.sh" -t "$build_root/" subdir-tests.sum "$@" . > "$build_root/tests.sum"
        if grep -E "^[A-Z]+:" "$build_root/tests.sum" | grep -E -q -v "^(X?PASS|XFAIL|UNSUPPORTED):"; then
            printf "ERROR: full Glibc test summary contains a failing or unresolved result.\\n" >&2
            exit 1
        fi
        result_count=$(grep -Ec "^(PASS|XFAIL|UNSUPPORTED):" "$build_root/tests.sum" || true)
        test "$result_count" -gt 0
        printf "Full Glibc summary results: %s\\n" "$result_count"
        sed -e "/:.*/!d" -e "s/:.*//" "$build_root/tests.sum" | sort | uniq -c
    ' glibc-check-aggregate "$SOURCE_REL" "${ALL_SUBDIRS[@]}" || AGGREGATE_RC=$?

if (( AGGREGATE_RC != 0 )); then
    printf 'Full Glibc test-summary aggregation failed with exit %d.\n' "$AGGREGATE_RC"
    printf 'exit=%d\n' "$AGGREGATE_RC" > "$STATUS"
    exit "$AGGREGATE_RC"
fi

printf 'PASS\n' > "$STATUS"
printf '\nFull Glibc 2.42 test suite summary passed.\n'
printf 'Finished: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Status: %s\nLog: %s\n' "$STATUS" "$LOG"
