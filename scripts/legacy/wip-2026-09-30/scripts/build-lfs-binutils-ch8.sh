#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly WORK_ROOT=/sources/binutils-2.45-ch8-20260926T210900Z
readonly BUILD_DIR="$WORK_ROOT/binutils-2.45/build"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/binutils-ch8-20260926T210900Z-build.log}"

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
[[ -r "$LFS/sources/binutils-2.45.tar.xz" && -r "$LFS/sources/md5sums" ]] || fail 'Binutils source or official LFS source manifest is missing.'
[[ -x "$LFS/usr/bin/ld" ]] || fail 'Expected Chapter 6 Binutils installation is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Binutils work: $WORK_ROOT"
if pgrep -af 'make (check|test|.*subdir=.*tests|install)' | grep -v '[b]uild-lfs-binutils-ch8'; then
    fail 'Another LFS make/check/test/install process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec >"$LOG" 2>&1

printf 'Building, critically testing, and installing LFS Chapter 8 Binutils 2.45.\n'
printf 'LFS root: %s\nBuild directory: %s\nStarted: %s\n\n' "$LFS" "$BUILD_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "binutils-2.45.tar.xz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/binutils-2.45.tar.xz -C "$work_root"
        cd "$work_root/binutils-2.45"
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
        make tooldir=/usr -j4
        if make -k check; then
            test_status=0
        else
            test_status=$?
        fi
        printf "BINUTILS_MAKE_CHECK_EXIT=%s\\n" "$test_status"
        test "$test_status" -eq 0
        mapfile -t test_logs < <(find . -type f -name "*.log" -print)
        if ((${#test_logs[@]})) && grep -H "^FAIL:" "${test_logs[@]}"; then
            printf "ERROR: Binutils check log contains FAIL diagnostics.\\n" >&2
            exit 1
        else
            grep_status=$?
            test "$grep_status" -eq 1
        fi
        printf "BINUTILS_CRITICAL_TEST_SUITE=passed\\n"
        make tooldir=/usr install
        test "$(/usr/bin/ld --version | head -n 1)" = "GNU ld (GNU Binutils) 2.45"
        test "$(/usr/bin/as --version | head -n 1)" = "GNU assembler (GNU Binutils) 2.45"
        test -e /usr/lib/libbfd.so
        test -e /usr/lib/libopcodes.so
        printf "Installed and verified Chapter 8 Binutils 2.45.\\n"
    ' binutils-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
