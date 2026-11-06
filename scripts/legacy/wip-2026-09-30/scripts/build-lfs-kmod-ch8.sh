#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/kmod-34.2-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/kmod-34.2"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/kmod-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/kmod-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/kmod-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/kmod-before-files.tar"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"

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
[[ -r "$LFS/sources/kmod-34.2.tar.xz" ]] || fail 'The Kmod 34.2 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Kmod work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Kmod 34.2.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The LFS test suite requires raw kernel headers unavailable in the book build; it is skipped.\n'

(
    cd "$LFS"
    for path in usr/bin/kmod usr/sbin/depmod usr/sbin/insmod usr/sbin/lsmod \
        usr/sbin/modinfo usr/sbin/modprobe usr/sbin/rmmod \
        usr/include/libkmod.h usr/lib/libkmod.so usr/lib/libkmod.so.2 \
        usr/lib/libkmod.so.2.5.1 usr/lib/pkgconfig/libkmod.pc \
        usr/share/pkgconfig/kmod.pc \
        usr/share/bash-completion/completions/kmod \
        usr/share/bash-completion/completions/insmod \
        usr/share/bash-completion/completions/lsmod \
        usr/share/bash-completion/completions/rmmod \
        usr/share/fish/vendor_functions.d/insmod.fish \
        usr/share/fish/vendor_functions.d/lsmod.fish \
        usr/share/fish/vendor_functions.d/rmmod.fish \
        usr/share/zsh/site-functions/_insmod \
        usr/share/zsh/site-functions/_lsmod \
        usr/share/zsh/site-functions/_rmmod \
        etc/depmod.d etc/modprobe.d usr/lib/depmod.d usr/lib/modprobe.d; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Kmod backup archive is empty.'
    printf 'Existing Kmod-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Kmod files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
fi
printf 'Pre-existing path count: %s\n' "$(wc -l < "$MANIFEST")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WORK_ROOT" "$SOURCE_ROOT" "$CHROOT_LOG" <<'CHROOT'
set -Eeuo pipefail
work_root="$1"
source_root="$2"
build_log="$3"
mkdir -pv "$work_root"
exec > >(tee "$build_log") 2>&1

tar -xJf /sources/kmod-34.2.tar.xz -C "$work_root"
[[ -f "$source_root/meson.build" ]] || { printf 'Kmod meson.build is missing.\n' >&2; exit 1; }
cd "$source_root"
mkdir -p build
cd build
meson setup --prefix=/usr .. --buildtype=release -D manpages=false
ninja
ninja install

/usr/bin/kmod --version
/usr/bin/pkg-config --modversion libkmod
for command in depmod insmod lsmod modinfo modprobe rmmod; do
    [[ -x "/usr/sbin/$command" ]] || { printf 'Missing Kmod command: %s\n' "$command" >&2; exit 1; }
    [[ "$(readlink -e "/usr/sbin/$command")" == /usr/bin/kmod ]] || {
        printf 'Unexpected Kmod command target: %s\n' "$command" >&2
        exit 1
    }
done
[[ -f /usr/include/libkmod.h ]]
[[ -L /usr/lib/libkmod.so ]]
[[ -f /usr/lib/libkmod.so.2.5.1 ]]
[[ -f /usr/lib/pkgconfig/libkmod.pc ]]
[[ -f /usr/share/pkgconfig/kmod.pc ]]
printf 'KMOD_FINAL_INSTALL=PASS\nKMOD_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nKmod Chapter 8 build/install completed; its raw-kernel-header test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
