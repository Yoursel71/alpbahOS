#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/bash-5.3-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/bash-5.3"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/bash-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/bash-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/bash-pass2-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/bash-pass2-files.tar"
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
[[ -r "$LFS/sources/bash-5.3.tar.gz" ]] || fail 'The Bash 5.3 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Bash work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Bash 5.3.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The LFS Bash test suite requires a non-root tester attached to a pseudo-terminal; it is not being run.\n'

(
    cd "$LFS"
    for path in usr/bin/bash usr/bin/bashbug usr/bin/sh \
        usr/include/bash usr/lib/bash usr/share/doc/bash-5.3 \
        usr/share/info/bash.info usr/share/man/man1/bash.1 usr/share/man/man1/bashbug.1; do
        if [[ -e "$path" || -L "$path" ]]; then
            printf '%s\0' "$path"
        fi
    done
    find usr/share/info -maxdepth 1 -type f -name 'bash.info*' -print0 2>/dev/null || true
    find usr/share/man/man1 -maxdepth 1 -type f -name 'bash*.1*' -print0 2>/dev/null || true
    find usr/share/locale -type f -name '*bash*.mo' -print0 2>/dev/null || true
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Bash Pass 2 backup archive is empty.'
    printf 'Existing Bash-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Bash-path files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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

tar -xf /sources/bash-5.3.tar.gz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Bash configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
./configure --prefix=/usr --without-bash-malloc --with-installed-readline \
    --docdir=/usr/share/doc/bash-5.3 > "$work_root/configure.log" 2>&1

if make -j4 > "$work_root/compile.log" 2>&1; then
    printf 'BASH_BUILD_RESULT=PASS\n'
else
    status=$?
    printf 'BASH_BUILD_RESULT=FAIL exit=%s\n' "$status"
    tail -n 60 "$work_root/compile.log"
    exit "$status"
fi

make -j1 install

/usr/bin/bash --version | head -n 1
/usr/bin/bash --noprofile --norc -c '[[ "$BASH_VERSION" == 5.3.* ]]'
[[ -x /usr/bin/bash && -x /usr/bin/bashbug ]]
[[ -d /usr/share/doc/bash-5.3 ]]
[[ "$(readlink /usr/bin/sh)" == bash ]]
printf 'BASH_FINAL_INSTALL=PASS\nBASH_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nBash Chapter 8 build/install completed; test suite was not run.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
