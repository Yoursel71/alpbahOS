#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/gawk-5.3.2-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/gawk-5.3.2"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/gawk-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/gawk-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/gawk-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/gawk-before-files.tar"
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
[[ -r "$LFS/sources/gawk-5.3.2.tar.xz" ]] || fail 'The Gawk 5.3.2 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Gawk work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Gawk 5.3.2.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The Gawk test suite is not being run. Optional package documentation will be installed.\n'

(
    cd "$LFS"
    for path in usr/bin/awk usr/bin/gawk usr/bin/gawk-5.3.2 usr/bin/gawkbug \
        usr/share/man/man1/awk.1 usr/share/man/man1/gawk.1 usr/share/man/man1/gawkbug.1 \
        usr/share/info/gawk.info usr/share/info/gawk.info.gz usr/share/info/dir \
        usr/lib/gawk usr/libexec/awk usr/share/awk usr/share/doc/gawk-5.3.2; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    find usr/share/locale \( -type f -o -type l \) -path '*/LC_MESSAGES/gawk.mo' -print0
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Gawk backup archive is empty.'
    printf 'Existing Gawk-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Gawk files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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

tar -xJf /sources/gawk-5.3.2.tar.xz -C "$work_root"
[[ -f "$source_root/Makefile.in" ]] || { printf 'Gawk Makefile.in is missing.\n' >&2; exit 1; }
cd "$source_root"
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make

# The LFS recipe removes this earlier-pass hard link so installation recreates it.
rm -f /usr/bin/gawk-5.3.2
make install
if [[ -e /usr/share/man/man1/awk.1 || -L /usr/share/man/man1/awk.1 ]]; then
    [[ "$(readlink /usr/share/man/man1/awk.1)" == gawk.1 ]] || {
        printf 'Existing awk man-page path is not the expected symlink.\n' >&2
        exit 1
    }
else
    ln -sv gawk.1 /usr/share/man/man1/awk.1
fi
install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.3.2

[[ "$(/usr/bin/gawk --version | sed -n '1p')" == 'GNU Awk 5.3.2,'* ]]
[[ "$(/usr/bin/gawk-5.3.2 --version | sed -n '1p')" == 'GNU Awk 5.3.2,'* ]]
[[ "$(readlink /usr/bin/awk)" == gawk ]]
[[ "$(stat -c '%i' /usr/bin/gawk)" == "$(stat -c '%i' /usr/bin/gawk-5.3.2)" ]]
for module in filefuncs fnmatch inplace revoutput time; do
    [[ -f "/usr/lib/gawk/$module.so" ]] || { printf 'Missing Gawk module: %s\n' "$module" >&2; exit 1; }
done
[[ -d /usr/share/awk && -f /usr/share/awk/assert.awk && -f /usr/share/info/gawk.info ]]
[[ -L /usr/share/man/man1/awk.1 && -f /usr/share/doc/gawk-5.3.2/awkforai.txt ]]
printf 'GAWK_FINAL_INSTALL=PASS\nGAWK_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nGawk Chapter 8 build/install completed; its test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
