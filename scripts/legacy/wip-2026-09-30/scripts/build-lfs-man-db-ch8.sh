#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly ARCHIVE="$LFS/sources/man-db-2.13.1.tar.xz"
readonly WORK_ROOT="/sources/man-db-2.13.1-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/man-db-2.13.1"
readonly STAGE_ROOT="$WORK_ROOT/stage"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/man-db-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/man-db-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/man-db-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/man-db-before-files.tar"
readonly STAGED_PATHS0="$BACKUP_DIR/staged-paths.list0"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"
readonly STATUS="$LOG_DIR/man-db-ch8-$STAMP.status"

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
[[ -r "$ARCHIVE" ]] || fail 'The Man-DB 2.13.1 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Man-DB work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/ninja/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

record_result() {
    local result=$?
    if (( result == 0 )); then
        printf 'MAN_DB_SCRIPT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'MAN_DB_SCRIPT_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building LFS Chapter 8 Man-DB 2.13.1.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work. The make check suite is skipped per user preference.\n'

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WORK_ROOT" "$SOURCE_ROOT" "$STAGE_ROOT" "$CHROOT_LOG" <<'CHROOT'
set -Eeuo pipefail
work_root="$1"
source_root="$2"
stage_root="$3"
build_log="$4"
mkdir -pv "$work_root"
exec > >(tee "$build_log") 2>&1

tar -xJf /sources/man-db-2.13.1.tar.xz -C "$work_root"
[[ -x "$source_root/configure" ]] || { printf 'Man-DB configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
./configure --prefix=/usr \
    --docdir=/usr/share/doc/man-db-2.13.1 \
    --sysconfdir=/etc \
    --disable-setuid \
    --enable-cache-owner=bin \
    --with-browser=/usr/bin/lynx \
    --with-vgrind=/usr/bin/vgrind \
    --with-grap=/usr/bin/grap > "$work_root/configure.log" 2>&1
if make -j4 > "$work_root/compile.log" 2>&1; then
    printf 'MAN_DB_BUILD_RESULT=PASS\n'
else
    result=$?
    printf 'MAN_DB_BUILD_RESULT=FAIL exit=%s\n' "$result"
    tail -n 100 "$work_root/compile.log"
    exit "$result"
fi
mkdir -pv "$stage_root"
make -j1 DESTDIR="$stage_root" install > "$work_root/staged-install.log" 2>&1
[[ -d "$stage_root/usr/bin" ]]
printf 'MAN_DB_STAGED_INSTALL=PASS\n'
CHROOT

sudo -n find "$LFS$STAGE_ROOT" \( -type f -o -type l \) -printf '%P\0' \
    | sort -zu > "$STAGED_PATHS0"
python3 - "$LFS" "$STAGED_PATHS0" "$MANIFEST0" <<'PY'
import os
import sys

root, staged_path, output_path = sys.argv[1:]
with open(staged_path, "rb") as stream:
    staged = stream.read().split(b"\0")
existing = []
for raw in staged:
    if not raw:
        continue
    relative = os.fsdecode(raw)
    if os.path.isabs(relative) or ".." in relative.split("/"):
        raise SystemExit(f"Unsafe staged package path: {relative!r}")
    target = os.path.join(root, relative)
    if os.path.lexists(target):
        existing.append(relative)

# Man-DB may refresh its on-disk index cache as part of installation.
for relative in ("var/cache/man", "var/lib/man-db"):
    if os.path.lexists(os.path.join(root, relative)):
        existing.append(relative)

with open(output_path, "wb") as stream:
    for relative in sorted(set(existing)):
        stream.write(os.fsencode(relative) + b"\0")
print(f"Staged files/symlinks: {len(staged) - staged.count(b'')}; pre-existing targets to archive: {len(set(existing))}")
PY
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Man-DB pre-install backup archive is empty.'
    printf 'Existing Man-DB-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Man-DB install targets were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
fi
printf 'Pre-existing path count: %s\n' "$(wc -l < "$MANIFEST")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$SOURCE_ROOT" "$STAGE_ROOT" "$CHROOT_LOG" <<'INSTALL'
set -Eeuo pipefail
source_root="$1"
stage_root="$2"
build_log="$3"
exec > >(tee -a "$build_log") 2>&1
cd "$source_root"
make -j1 install

[[ "$(/usr/bin/man --version | sed -n '1p')" == *'2.13.1'* ]]
[[ "$(/usr/bin/mandb --version | sed -n '1p')" == *'2.13.1'* ]]
for command in apropos catman lexgrog man man-recode mandb manpath whatis; do
    [[ -x "/usr/bin/$command" ]] || { printf 'Missing Man-DB command: %s\n' "$command" >&2; exit 1; }
done
[[ -x /usr/sbin/accessdb || -x /usr/bin/accessdb ]]
[[ -f /usr/lib/man-db/libman.so && -f /usr/lib/man-db/libmandb.so ]]
[[ -x /usr/libexec/man-db/zsoelim || -x /usr/bin/zsoelim ]]
[[ -f /etc/man_db.conf ]]
[[ -d /usr/share/doc/man-db-2.13.1 ]]
readelf -h /usr/bin/man | grep -F 'Advanced Micro Devices X86-64'
ldd /usr/bin/man | grep -E 'libc[.]so[.]6.*[/]usr/lib/'
printf 'MAN_DB_FINAL_INSTALL=PASS\n'
INSTALL

printf '\nMan-DB Chapter 8 build/install completed; the package test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nStatus: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
