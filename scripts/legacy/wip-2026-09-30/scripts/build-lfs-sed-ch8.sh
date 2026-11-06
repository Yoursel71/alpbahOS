#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/sed-4.9-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/sed-4.9"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/sed-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/sed-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/sed-pass2-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/sed-pass2-files.tar"
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
[[ -r "$LFS/sources/sed-4.9.tar.xz" ]] || fail 'The Sed 4.9 source archive is missing.'
[[ -e "$LFS/usr/bin/sed" ]] || fail 'The existing Pass 2 sed executable is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Sed work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Sed 4.9.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using existing source archive without checksum work, as requested. The Chapter 6 source tree is preserved.\n'
printf 'The official Sed test suite is not being run; build, HTML documentation, and install steps will be performed.\n'

(
    cd "$LFS"
    for path in usr/bin/sed usr/share/doc/sed-4.9; do
        if [[ -e "$path" || -L "$path" ]]; then
            printf '%s\0' "$path"
        fi
    done
) | sort -zu > "$MANIFEST0"
[[ -s "$MANIFEST0" ]] || fail 'The Sed Pass 2 backup manifest is empty.'
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
    -C "$LFS" --null --files-from="$MANIFEST0"
sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
[[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Sed Pass 2 backup archive is empty.'
printf 'Backup file count: %s\nBackup archive size: %s bytes\n' \
    "$(wc -l < "$MANIFEST")" "$(stat -c '%s' "$BACKUP_ARCHIVE")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WORK_ROOT" "$SOURCE_ROOT" "$CHROOT_LOG" <<'CHROOT'
set -Eeuo pipefail
work_root="$1"
source_root="$2"
build_log="$3"
mkdir -pv "$work_root"
exec > >(tee "$build_log") 2>&1

tar -xf /sources/sed-4.9.tar.xz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Sed configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
./configure --prefix=/usr > "$work_root/configure.log" 2>&1

if make > "$work_root/compile.log" 2>&1; then
    printf 'SED_BUILD_RESULT=PASS\n'
else
    status=$?
    printf 'SED_BUILD_RESULT=FAIL exit=%s\n' "$status"
    tail -n 60 "$work_root/compile.log"
    exit "$status"
fi

if make html > "$work_root/html.log" 2>&1; then
    printf 'SED_HTML_RESULT=PASS\n'
else
    status=$?
    printf 'SED_HTML_RESULT=FAIL exit=%s\n' "$status"
    tail -n 60 "$work_root/html.log"
    exit "$status"
fi

make -j1 install
install -d -m755 /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9

/usr/bin/sed --version | head -n 1
[[ -x /usr/bin/sed && -s /usr/share/doc/sed-4.9/sed.html ]]
printf 'SED_FINAL_INSTALL=PASS\nSED_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nSed Chapter 8 build/install completed; test suite was not run.\n'
printf 'Build/install log: %s\nPass 2 backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_ARCHIVE" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
