#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly WORK_ROOT=/sources/flex-2.6.4-ch8-20260926T210200Z
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/flex-ch8-20260926T210200Z.log}"

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
[[ -r "$LFS/sources/flex-2.6.4.tar.gz" && -r "$LFS/sources/md5sums" ]] || fail 'Flex source or official LFS source manifest is missing.'
for path in "$LFS/usr/bin/flex" "$LFS/usr/bin/flex++" "$LFS/usr/bin/lex" "$LFS/usr/share/man/man1/lex.1" "$LFS/usr/lib/libfl.so"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Flex is already installed: $path"
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Flex work: $WORK_ROOT"
if pgrep -af 'make (check|test|.*subdir=.*tests|install)' | grep -v '[b]uild-lfs-flex-ch8'; then
    fail 'Another LFS make/check/test/install process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec >"$LOG" 2>&1

printf 'Building and installing LFS Chapter 8 Flex 2.6.4.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "flex-2.6.4.tar.gz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/flex-2.6.4.tar.gz -C "$work_root"
        cd "$work_root/flex-2.6.4"
        ./configure --prefix=/usr \
                    --docdir=/usr/share/doc/flex-2.6.4 \
                    --disable-static
        make -j4
        make install
        ln -sv flex /usr/bin/lex
        ln -sv flex.1 /usr/share/man/man1/lex.1
        test "$(/usr/bin/flex --version | head -n 1)" = "flex 2.6.4"
        test -e /usr/bin/flex++
        test -e /usr/lib/libfl.so
        test "$(readlink /usr/bin/lex)" = flex
        test "$(readlink /usr/share/man/man1/lex.1)" = flex.1
        test ! -e /usr/lib/libfl.a
        printf "Installed native Flex 2.6.4.\\n"
    ' flex-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
