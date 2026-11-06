#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/ncurses-6.5-20250809-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/ncurses-6.5-20250809"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/ncurses-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/ncurses-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/ncurses-pass2-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/ncurses-pass2-files.tar"
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
[[ -r "$LFS/sources/ncurses-6.5-20250809.tgz" ]] || fail 'The Ncurses 6.5-20250809 source archive is missing.'
[[ -r "$LFS/sources/md5sums" ]] || fail 'The LFS source manifest is missing.'
[[ -e "$LFS/usr/lib/libncursesw.so.6.5" ]] || fail 'The existing Pass 2 wide Ncurses library is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Ncurses work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Ncurses 6.5-20250809.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested. The older Chapter 6 source tree is preserved.\n'
printf 'Backing up currently installed Pass 2 Ncurses files to %s before overlay.\n' "$BACKUP_ARCHIVE"

(
    cd "$LFS"
    for path in \
        usr/include/curses.h usr/include/ncurses.h usr/include/ncursesw \
        usr/include/term.h usr/include/termcap.h usr/include/unctrl.h \
        usr/share/tabset usr/share/terminfo usr/share/doc/ncurses-6.5-20250809 \
        usr/bin/captoinfo usr/bin/clear usr/bin/infocmp usr/bin/infotocap \
        usr/bin/ncursesw6-config usr/bin/reset usr/bin/tabs usr/bin/tic \
        usr/bin/toe usr/bin/tput usr/bin/tset; do
        if [[ -e "$path" || -L "$path" ]]; then
            printf '%s\0' "$path"
        fi
    done
    find usr/lib -maxdepth 1 \( -type f -o -type l \) \
        \( -name 'libncurses*' -o -name 'libcurses*' -o -name 'libform*' \
        -o -name 'libpanel*' -o -name 'libmenu*' \) -printf '%p\0'
    if [[ -d usr/lib/pkgconfig ]]; then
        find usr/lib/pkgconfig -maxdepth 1 \( -type f -o -type l \) \
            \( -iname '*ncurses*' -o -iname 'form*.pc' -o -iname 'panel*.pc' -o -iname 'menu*.pc' \) \
            -printf '%p\0'
    fi
) | sort -zu > "$MANIFEST0"
[[ -s "$MANIFEST0" ]] || fail 'The Ncurses Pass 2 backup manifest is empty.'
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
    -C "$LFS" --null --files-from="$MANIFEST0"
sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
[[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Ncurses Pass 2 backup archive is empty.'
printf 'Backup file count: %s\nBackup archive size: %s bytes\n' \
    "$(wc -l < "$MANIFEST")" "$(stat -c '%s' "$BACKUP_ARCHIVE")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WORK_ROOT" "$SOURCE_ROOT" "$CHROOT_LOG" "$STAMP" <<'CHROOT'
set -Eeuo pipefail
work_root="$1"
source_root="$2"
build_log="$3"
stamp="$4"
mkdir -pv "$work_root" "$work_root/ncurses-logs"
exec > >(tee "$build_log") 2>&1

tar -xf /sources/ncurses-6.5-20250809.tgz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Ncurses configure script is missing.\n' >&2; exit 1; }
cd "$source_root"

./configure --prefix=/usr \
            --mandir=/usr/share/man \
            --with-shared \
            --without-debug \
            --without-normal \
            --with-cxx-shared \
            --enable-pc-files \
            --with-pkg-config-libdir=/usr/lib/pkgconfig \
            > "$work_root/ncurses-logs/configure.log" 2>&1

if make > "$work_root/ncurses-logs/compile.log" 2>&1; then
    printf 'NCURSES_BUILD_RESULT=PASS\n'
else
    status=$?
    printf 'NCURSES_BUILD_RESULT=FAIL exit=%s\n' "$status"
    tail -n 60 "$work_root/ncurses-logs/compile.log"
    exit "$status"
fi

mkdir -pv dest "$work_root/ncurses-stage-preserved"
make DESTDIR="$PWD/dest" install
[[ -f dest/usr/lib/libncursesw.so.6.5 ]] || { printf 'DESTDIR wide Ncurses library is missing.\n' >&2; exit 1; }
[[ -f dest/usr/include/curses.h ]] || { printf 'DESTDIR curses.h is missing.\n' >&2; exit 1; }
cp -av dest/usr/include/curses.h "$work_root/ncurses-stage-preserved/curses.h.before-wide-abi"

# Replace the installed shared library atomically before copying the remaining staged tree.
install -vm755 dest/usr/lib/libncursesw.so.6.5 /usr/lib
mv -v dest/usr/lib/libncursesw.so.6.5 "$work_root/ncurses-stage-preserved/libncursesw.so.6.5.destdir-copy"
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i dest/usr/include/curses.h
cp -av dest/* /

for lib in ncurses form panel menu; do
    ln -sfv "lib${lib}w.so" "/usr/lib/lib${lib}.so"
    ln -sfv "${lib}w.pc" "/usr/lib/pkgconfig/${lib}.pc"
done
ln -sfv libncursesw.so /usr/lib/libcurses.so
cp -v -R doc -T /usr/share/doc/ncurses-6.5-20250809

printf 'NCURSES_CONFIG_VERSION='; /usr/bin/tic -V
printf 'NCURSESW_PKGCONFIG='; /usr/bin/pkg-config --modversion ncursesw
printf 'NCURSES_FINAL_INSTALL=PASS\nNCURSES_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nNcurses Chapter 8 build and install completed; upstream test suite was not run because LFS does not require it here.\n'
printf 'Build/install log: %s\nPass 2 backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_ARCHIVE" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
