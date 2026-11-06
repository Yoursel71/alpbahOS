#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/psmisc-23.7-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/psmisc-23.7"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/psmisc-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/psmisc-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/psmisc-pass2-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/psmisc-pass2-files.tar"
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
[[ -r "$LFS/sources/psmisc-23.7.tar.xz" ]] || fail 'The Psmisc 23.7 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Psmisc work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Psmisc 23.7.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The LFS page lists make check as an optional test-suite command; it is not being run.\n'

(
    cd "$LFS"
    for path in usr/bin/fuser usr/bin/killall usr/bin/peekfd usr/bin/prtstat usr/bin/pslog \
        usr/bin/pstree usr/bin/pstree.x11; do
        if [[ -e "$path" || -L "$path" ]]; then
            printf '%s\0' "$path"
        fi
    done
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Psmisc Pass 2 backup archive is empty.'
    printf 'Existing Pass 2 command backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No Psmisc command files existed in Pass 2; empty manifest preserved.\n' \
        | tee "$BACKUP_DIR/no-preexisting-files.txt"
fi
printf 'Pre-existing command count: %s\n' "$(wc -l < "$MANIFEST")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WORK_ROOT" "$SOURCE_ROOT" "$CHROOT_LOG" <<'CHROOT'
set -Eeuo pipefail
work_root="$1"
source_root="$2"
build_log="$3"
mkdir -pv "$work_root"
exec > >(tee "$build_log") 2>&1

tar -xf /sources/psmisc-23.7.tar.xz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Psmisc configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
./configure --prefix=/usr > "$work_root/configure.log" 2>&1

if make -j4 > "$work_root/compile.log" 2>&1; then
    printf 'PSMISC_BUILD_RESULT=PASS\n'
else
    status=$?
    printf 'PSMISC_BUILD_RESULT=FAIL exit=%s\n' "$status"
    tail -n 60 "$work_root/compile.log"
    exit "$status"
fi

make -j1 install

for program in fuser killall peekfd prtstat pslog pstree pstree.x11; do
    [[ -x "/usr/bin/$program" ]] || { printf 'Missing installed program: %s\n' "$program" >&2; exit 1; }
done
/usr/bin/fuser --version | head -n 1
/usr/bin/pstree --version | head -n 1
printf 'PSMISC_FINAL_INSTALL=PASS\nPSMISC_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nPsmisc Chapter 8 build/install completed; test suite was not run.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
