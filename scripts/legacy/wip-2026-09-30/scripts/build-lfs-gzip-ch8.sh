#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/gzip-1.14-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/gzip-1.14"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/gzip-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/gzip-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/gzip-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/gzip-before-files.tar"
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
[[ -r "$LFS/sources/gzip-1.14.tar.xz" ]] || fail 'The Gzip 1.14 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Gzip work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Gzip 1.14.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The Gzip test suite is not being run.\n'

(
    cd "$LFS"
    command_names=(
        gunzip gzexe gzip uncompress zcat zcmp zdiff zegrep zfgrep zforce zgrep zless zmore znew
    )
    for name in "${command_names[@]}"; do
        if [[ -e "usr/bin/$name" || -L "usr/bin/$name" ]]; then printf 'usr/bin/%s\0' "$name"; fi
        for man_section in usr/share/man/man[0-9]*; do
            [[ -d "$man_section" ]] || continue
            section_number="${man_section##*/man}"
            path="$man_section/$name.$section_number"
            if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
        done
    done
    for path in usr/share/info/gzip.info usr/share/info/gzip.info-1 usr/share/info/gzip.info.gz \
        usr/share/info/dir usr/share/doc/gzip-1.14; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Gzip backup archive is empty.'
    printf 'Existing Gzip-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Gzip files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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

tar -xJf /sources/gzip-1.14.tar.xz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Gzip configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
./configure --prefix=/usr
make
make install

[[ "$(/usr/bin/gzip --version | sed -n '1p')" == 'gzip 1.14' ]]
for command in gunzip gzexe gzip uncompress zcat zcmp zdiff zegrep zfgrep zforce zgrep zless zmore znew; do
    [[ -x "/usr/bin/$command" ]] || { printf 'Missing Gzip command: %s\n' "$command" >&2; exit 1; }
done
[[ "$(stat -c '%i' /usr/bin/gunzip)" == "$(stat -c '%i' /usr/bin/uncompress)" ]]
[[ -f /usr/share/info/gzip.info ]]
printf 'GZIP_FINAL_INSTALL=PASS\nGZIP_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nGzip Chapter 8 build/install completed; its test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
