#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly WORK_ROOT=/sources/bzip2-1.0.8-ch8-20260926T204700Z
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/bzip2-ch8-20260926T204700Z.log}"

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
for file in bzip2-1.0.8.tar.gz bzip2-1.0.8-install_docs-1.patch; do
    [[ -r "$LFS/sources/$file" ]] || fail "Required source file is missing: $file"
done
[[ -r "$LFS/sources/md5sums" ]] || fail 'Official LFS source manifest is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Bzip2 work: $WORK_ROOT"
for path in "$LFS/usr/bin/bzip2" "$LFS/usr/lib/libbz2.so" "$LFS/usr/lib/libbz2.a"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Bzip2 is already installed: $path"
done
if pgrep -af 'make (check|.*subdir=.*tests|install)' | grep -v '[b]uild-lfs-bzip2-ch8'; then
    fail 'Another LFS make/check/install process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$(dirname -- "$LOG")"
lfs_acquire_writer_lock "$DATA"
exec >"$LOG" 2>&1

printf 'Building and installing LFS Chapter 8 Bzip2 1.0.8.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        for file in bzip2-1.0.8.tar.gz bzip2-1.0.8-install_docs-1.patch; do
            mapfile -t expected < <(awk -v file="$file" '\''$2 == file { print }'\'' /sources/md5sums)
            test "${#expected[@]}" -eq 1
            printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)
        done

        mkdir -pv "$work_root"
        tar -xf /sources/bzip2-1.0.8.tar.gz -C "$work_root"
        cd "$work_root/bzip2-1.0.8"
        patch -Np1 -i /sources/bzip2-1.0.8-install_docs-1.patch
        sed -i '\''s@\(ln -s -f \)$(PREFIX)/bin/@\1@'\'' Makefile
        sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
        make -f Makefile-libbz2_so
        make clean
        make
        make PREFIX=/usr install
        cp -av libbz2.so.* /usr/lib
        ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so
        cp -v bzip2-shared /usr/bin/bzip2
        for i in /usr/bin/bzcat /usr/bin/bunzip2; do
            ln -sfv bzip2 "$i"
        done
        rm -fv /usr/lib/libbz2.a
        printf "Installed Bzip2 1.0.8.\\n"
    ' bzip2-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
