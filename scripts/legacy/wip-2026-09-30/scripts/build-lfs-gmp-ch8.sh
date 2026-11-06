#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCE=/sources/gmp-6.3.0.tar.xz
readonly MANIFEST=/sources/md5sums
readonly BINUTILS_TEST_LOG="$DATA/logs/lfs-12.4-systemd/binutils-ch8-20260926T212349Z-check.log"
readonly BINUTILS_INSTALL_LOG="$DATA/logs/lfs-12.4-systemd/binutils-ch8-20260926T212831Z-install.log"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
readonly WORK_ROOT="/sources/gmp-6.3.0-ch8-$STAMP"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/gmp-ch8-$STAMP.log}"

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
[[ -r "$LFS/sources/gmp-6.3.0.tar.xz" && -r "$LFS/sources/md5sums" ]] || fail 'GMP source or official LFS source manifest is missing.'
[[ -f "$BINUTILS_TEST_LOG" ]] || fail 'The Chapter 8 Binutils critical test log is missing.'
[[ -f "$BINUTILS_INSTALL_LOG" ]] || fail 'The Chapter 8 Binutils install log is missing.'
rg -q '^HOST_TEST_EXIT=0$' "$BINUTILS_TEST_LOG" || fail 'The Chapter 8 Binutils critical test did not pass.'
rg -q '^INSTALL_EXIT=0$' "$BINUTILS_INSTALL_LOG" || fail 'The Chapter 8 Binutils install did not complete.'
if rg -q '^FAIL:' "$BINUTILS_TEST_LOG"; then
    fail 'The Chapter 8 Binutils test log contains FAIL lines.'
fi
sudo -n chroot "$LFS" /usr/bin/ld --version | head -n 1 | grep -F 'GNU Binutils) 2.45' >/dev/null || fail 'The Chapter 8 Binutils linker is not installed.'
for path in "$LFS/usr/lib/libgmp.so" "$LFS/usr/lib/libgmpxx.so" "$LFS/usr/share/doc/gmp-6.3.0"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "GMP is already installed: $path"
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior GMP work: $WORK_ROOT"
if ps -eo comm= | awk '$1 == "make" || $1 == "runtest" || $1 == "dejagnu" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building and installing LFS Chapter 8 GMP 6.3.0.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    CFLAGS='-O2 -march=x86-64 -mtune=generic' \
    GMP_WORK_ROOT="$WORK_ROOT" \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="${GMP_WORK_ROOT:?}"
        mapfile -t expected < <(awk '\''$2 == "gmp-6.3.0.tar.xz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/gmp-6.3.0.tar.xz -C "$work_root"
        cd "$work_root/gmp-6.3.0"
        sed -i "/long long t1;/,+1s/()/(...)/" configure
        ./configure --prefix=/usr \
                    --enable-fat \
                    --enable-cxx \
                    --disable-static \
                    --docdir=/usr/share/doc/gmp-6.3.0
        grep -Fq -- '-march=x86-64 -mtune=generic' Makefile
        if grep -Fq -- '-march=znver3' Makefile; then
            printf "GMP Makefile unexpectedly targets the build CPU.\\n" >&2
            exit 1
        fi
        make
        make html
        set -o pipefail
        make check 2>&1 | tee gmp-check-log
        passed=$(awk '\''/# PASS:/{total += $3} END {print total + 0}'\'' gmp-check-log)
        printf "GMP_TEST_PASS_COUNT=%s\\n" "$passed"
        test "$passed" -ge 199
        make install
        make install-html
        test -e /usr/lib/libgmp.so
        test -e /usr/lib/libgmpxx.so
        test -d /usr/share/doc/gmp-6.3.0
        printf "Installed GMP 6.3.0; critical check passed with %s PASS tests.\\n" "$passed"
    '

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
