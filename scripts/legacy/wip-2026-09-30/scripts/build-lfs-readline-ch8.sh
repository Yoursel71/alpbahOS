#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly WORK_ROOT=/sources/readline-8.3-ch8-20260926T205500Z
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/readline-ch8-20260926T205500Z.log}"

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
[[ -r "$LFS/sources/readline-8.3.tar.gz" && -r "$LFS/sources/md5sums" ]] || fail 'Readline source or official LFS source manifest is missing.'
for path in "$LFS/usr/lib/libreadline.so" "$LFS/usr/lib/libhistory.so"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Readline is already installed: $path"
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Readline work: $WORK_ROOT"
if pgrep -af 'make (check|.*subdir=.*tests|install)' | grep -v '[b]uild-lfs-readline-ch8'; then
    fail 'Another LFS make/check/install process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$(dirname -- "$LOG")"
lfs_acquire_writer_lock "$DATA"
exec >"$LOG" 2>&1

printf 'Building and installing LFS Chapter 8 Readline 8.3.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    READLINE_WORK_ROOT="$WORK_ROOT" \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="${READLINE_WORK_ROOT:?}"
        mapfile -t expected < <(awk '\''$2 == "readline-8.3.tar.gz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/readline-8.3.tar.gz -C "$work_root"
        cd "$work_root/readline-8.3"
        sed -i '\''/MV.*old/d'\'' Makefile.in
        sed -i '\''/{OLDSUFF}/c:'\'' support/shlib-install
        sed -i '\''s/-Wl,-rpath,[^ ]*//'\'' support/shobj-conf
        ./configure --prefix=/usr \
                    --disable-static \
                    --with-curses \
                    --docdir=/usr/share/doc/readline-8.3
        make SHLIB_LIBS="-lncursesw"
        make install
        test -e /usr/lib/libreadline.so
        test -e /usr/lib/libhistory.so
        grep -q '^Requires.private: ncursesw$' /usr/lib/pkgconfig/readline.pc
        printf "Installed Readline 8.3.\\n"
    '

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
