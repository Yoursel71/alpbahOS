#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/libtool-2.5.4-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/libtool-2.5.4"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/libtool-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/libtool-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/libtool-pass2-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/libtool-pass2-files.tar"
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
[[ -r "$LFS/sources/libtool-2.5.4.tar.xz" ]] || fail 'The Libtool 2.5.4 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Libtool work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Libtool 2.5.4.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The LFS page lists make check as a test-suite command; it is not being run. The cleanup rm for libltdl.a is also skipped to preserve the installed file.\n'

(
    cd "$LFS"
    for path in usr/bin/libtool usr/bin/libtoolize \
        usr/include/libltdl usr/lib/libltdl.a usr/lib/libltdl.la usr/lib/libltdl.so \
        usr/share/libtool usr/share/doc/libtool-2.5.4 usr/share/info/libtool.info \
        usr/share/man/man1/libtool.1 usr/share/man/man1/libtoolize.1; do
        if [[ -e "$path" || -L "$path" ]]; then
            printf '%s\0' "$path"
        fi
    done
    find usr/lib -maxdepth 1 \( -type f -o -type l \) -name 'libltdl.so*' -print0 2>/dev/null || true
    find usr/share/info -maxdepth 1 -type f -name 'libtool.info*' -print0 2>/dev/null || true
    find usr/share/man/man1 -maxdepth 1 -type f -name 'libtool*.1*' -print0 2>/dev/null || true
    find usr/share/locale -type f -name '*libtool*.mo' -print0 2>/dev/null || true
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Libtool Pass 2 backup archive is empty.'
    printf 'Existing Libtool-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Libtool-path files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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

tar -xf /sources/libtool-2.5.4.tar.xz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Libtool configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
./configure --prefix=/usr > "$work_root/configure.log" 2>&1

if make -j4 > "$work_root/compile.log" 2>&1; then
    printf 'LIBTOOL_BUILD_RESULT=PASS\n'
else
    status=$?
    printf 'LIBTOOL_BUILD_RESULT=FAIL exit=%s\n' "$status"
    tail -n 60 "$work_root/compile.log"
    exit "$status"
fi

make -j1 install

/usr/bin/libtool --version | head -n 1
/usr/bin/libtoolize --version | head -n 1
[[ -x /usr/bin/libtool && -x /usr/bin/libtoolize ]]
[[ -e /usr/lib/libltdl.so && -s /usr/lib/libltdl.a ]]
[[ -d /usr/include/libltdl && -d /usr/share/libtool ]]
printf 'LIBTOOL_FINAL_INSTALL=PASS\nLIBTOOL_STATIC_ARCHIVE_PRESERVED=YES\nLIBTOOL_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nLibtool Chapter 8 build/install completed; test suite was not run and libltdl.a was preserved.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
