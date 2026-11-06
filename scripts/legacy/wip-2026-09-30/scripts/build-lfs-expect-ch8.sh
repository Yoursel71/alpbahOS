#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly WORK_ROOT=/sources/expect5.45.4-ch8-20260926T210600Z
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/expect-ch8-20260926T210600Z.log}"

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
[[ -r "$LFS/sources/expect5.45.4.tar.gz" && -r "$LFS/sources/expect-5.45.4-gcc15-1.patch" && -r "$LFS/sources/md5sums" ]] || fail 'Expect sources, GCC 15 patch, or official LFS source manifest is missing.'
[[ -r "$LFS/usr/lib/tclConfig.sh" && -r "$LFS/usr/include/tcl.h" ]] || fail 'Native Tcl library configuration or headers are missing.'
for path in "$LFS/usr/bin/expect" "$LFS/usr/lib/libexpect5.45.4.so" "$LFS/usr/lib/expect5.45.4/libexpect5.45.4.so"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Expect is already installed: $path"
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Expect work: $WORK_ROOT"
if pgrep -af 'make (check|test|.*subdir=.*tests|install)' | grep -v '[b]uild-lfs-expect-ch8'; then
    fail 'Another LFS make/check/test/install process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec >"$LOG" 2>&1

printf 'Building and installing LFS Chapter 8 Expect 5.45.4 with the LFS GCC 15 patch.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected_src < <(awk '\''$2 == "expect5.45.4.tar.gz" { print }'\'' /sources/md5sums)
        mapfile -t expected_patch < <(awk '\''$2 == "expect-5.45.4-gcc15-1.patch" { print }'\'' /sources/md5sums)
        test "${#expected_src[@]}" -eq 1
        test "${#expected_patch[@]}" -eq 1
        printf "%s\\n" "${expected_src[0]}" "${expected_patch[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/expect5.45.4.tar.gz -C "$work_root"
        cd "$work_root/expect5.45.4"
        patch -Np1 -i /sources/expect-5.45.4-gcc15-1.patch
        ./configure --prefix=/usr \
                    --with-tcl=/usr/lib \
                    --enable-shared \
                    --disable-rpath \
                    --mandir=/usr/share/man \
                    --with-tclinclude=/usr/include
        make -j4
        make install
        ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
        test -x /usr/bin/expect
        test -e /usr/lib/expect5.45.4/libexpect5.45.4.so
        test "$(readlink /usr/lib/libexpect5.45.4.so)" = expect5.45.4/libexpect5.45.4.so
        printf "Installed native Expect 5.45.4.\\n"
    ' expect-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
