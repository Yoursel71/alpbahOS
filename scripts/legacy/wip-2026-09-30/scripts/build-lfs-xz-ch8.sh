#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly WORK_ROOT=/sources/xz-5.8.1-ch8-20260926T205000Z
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/xz-ch8-20260926T205000Z.log}"

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
[[ -r "$LFS/sources/xz-5.8.1.tar.xz" && -r "$LFS/sources/md5sums" ]] || fail 'Xz source or official LFS source manifest is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Chapter 8 Xz work: $WORK_ROOT"
[[ -x "$LFS/usr/bin/xz" && -L "$LFS/usr/lib/liblzma.so" && -e "$LFS/usr/lib/liblzma.so.5.8.1" ]] || fail 'Expected Chapter 6 Xz bootstrap install is missing.'
[[ "$(sudo -n chroot "$LFS" /usr/bin/xz --version | head -1)" == 'xz (XZ Utils) 5.8.1' ]] || fail 'The existing bootstrap Xz is not version 5.8.1.'
[[ ! -e "$LFS/usr/lib/liblzma.a" ]] || fail 'Unexpected static liblzma archive is present.'
if pgrep -af 'make (check|.*subdir=.*tests|install)' | grep -v '[b]uild-lfs-xz-ch8'; then
    fail 'Another LFS make/check/install process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$(dirname -- "$LOG")"
lfs_acquire_writer_lock "$DATA"
exec >"$LOG" 2>&1

printf 'Replacing Chapter 6 cross-built Xz with the native LFS Chapter 8 Xz 5.8.1 build.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "xz-5.8.1.tar.xz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/xz-5.8.1.tar.xz -C "$work_root"
        cd "$work_root/xz-5.8.1"
        ./configure --prefix=/usr \
                    --disable-static \
                    --docdir=/usr/share/doc/xz-5.8.1
        make -j4
        make install
        printf "Installed Xz 5.8.1.\\n"
    ' xz-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
