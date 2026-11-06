#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly ARCHIVE="$LFS/sources/tar-1.35.tar.xz"
readonly WORK_ROOT="/sources/tar-1.35-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/tar-1.35"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/tar-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/tar-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/tar-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/tar-before-files.tar"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"
readonly STATUS="$LOG_DIR/tar-ch8-$STAMP.status"

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
[[ -r "$ARCHIVE" ]] || fail 'The Tar 1.35 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Tar work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

record_result() {
    local result=$?
    if (( result == 0 )); then
        printf 'TAR_SCRIPT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'TAR_SCRIPT_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building LFS Chapter 8 Tar 1.35.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The LFS page documents a known capability-test issue; package tests are skipped per user preference.\n'

(
    cd "$LFS"
    for path in usr/bin/tar usr/libexec/rmt usr/share/info/dir usr/share/info/tar.info \
        usr/share/man/man1/tar.1 usr/share/man/man8/rmt.8 usr/share/doc/tar-1.35; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    find usr/share/info -maxdepth 1 \( -type f -o -type l \) -name 'tar.info*' -print0 2>/dev/null || true
    find usr/share/man/man1 -maxdepth 1 \( -type f -o -type l \) -name 'tar.1*' -print0 2>/dev/null || true
    find usr/share/locale -path '*/LC_MESSAGES/tar.mo' -print0 2>/dev/null || true
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Tar backup archive is empty.'
    printf 'Existing Tar-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Tar target files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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

tar -xJf /sources/tar-1.35.tar.xz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Tar configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr > "$work_root/configure.log" 2>&1

if make -j4 > "$work_root/compile.log" 2>&1; then
    printf 'TAR_BUILD_RESULT=PASS\n'
else
    result=$?
    printf 'TAR_BUILD_RESULT=FAIL exit=%s\n' "$result"
    tail -n 80 "$work_root/compile.log"
    exit "$result"
fi

make -j1 install
make -C doc install-html docdir=/usr/share/doc/tar-1.35

[[ "$(/usr/bin/tar --version | sed -n '1p')" == 'tar (GNU tar) 1.35' ]]
[[ -x /usr/bin/tar ]]
[[ -f /usr/share/man/man1/tar.1 ]]
[[ -f /usr/share/info/tar.info ]]
[[ -f /usr/share/info/dir ]]
[[ -d /usr/share/doc/tar-1.35 ]]
[[ -n "$(find /usr/share/doc/tar-1.35 -type f -name '*.html' -print -quit)" ]]
readelf -h /usr/bin/tar | grep -F 'Advanced Micro Devices X86-64'
ldd /usr/bin/tar | grep -E 'libc[.]so[.]6.*[/]usr/lib/'
printf 'TAR_FINAL_INSTALL=PASS\nTAR_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nTar Chapter 8 build/install completed; the package test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nStatus: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
