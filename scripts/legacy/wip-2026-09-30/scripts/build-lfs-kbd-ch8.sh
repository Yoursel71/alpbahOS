#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/kbd-2.8.0-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/kbd-2.8.0"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/kbd-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/kbd-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/kbd-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/kbd-before-files.tar"
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
[[ -r "$LFS/sources/kbd-2.8.0.tar.xz" ]] || fail 'The Kbd 2.8.0 source archive is missing.'
[[ -r "$LFS/sources/kbd-2.8.0-backspace-1.patch" ]] || fail 'The LFS Kbd backspace patch is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Kbd work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Kbd 2.8.0.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive and LFS backspace patch without checksum work, as requested.\n'
printf 'Kbd tests require valgrind and are documented to fail in the chroot; they are skipped.\n'
printf 'The resizecons source and manpage are preserved while the LFS build rules omit them.\n'

(
    cd "$LFS"
    command_names=(
        chvt deallocvt dumpkeys fgconsole getkeycodes kbdinfo kbd_mode kbdrate loadkeys loadunimap mapscrn openvt
        psfaddtable psfgettable psfstriptable psfxtable setfont setkeycodes setleds setmetamode setvtrgb
        showconsolefont showkey unicode_start unicode_stop
    )
    for name in "${command_names[@]}"; do
        for bindir in usr/bin usr/sbin; do
            path="$bindir/$name"
            if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
        done
    done
    while IFS= read -r source_file; do
        case "$source_file" in
            kbd-2.8.0/docs/man/man[1-9]/*.[1-9])
                relative_path="${source_file#kbd-2.8.0/docs/man/}"
                target_path="usr/share/man/$relative_path"
                if [[ -e "$target_path" || -L "$target_path" ]]; then printf '%s\0' "$target_path"; fi
                ;;
        esac
    done < <(tar -tJf "$LFS/sources/kbd-2.8.0.tar.xz")
    for path in usr/share/consolefonts usr/share/consoletrans usr/share/keymaps usr/share/unimaps \
        usr/share/doc/kbd-2.8.0 usr/share/info/dir; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    find usr/share/locale \( -type f -o -type l \) -path '*/LC_MESSAGES/kbd.mo' -print0
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Kbd backup archive is empty.'
    printf 'Existing Kbd-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Kbd files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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

tar -xJf /sources/kbd-2.8.0.tar.xz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Kbd configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
patch -Np1 -i /sources/kbd-2.8.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-vlock
make
make install
cp -R -v docs/doc -T /usr/share/doc/kbd-2.8.0

for command in chvt deallocvt dumpkeys fgconsole getkeycodes kbdinfo kbd_mode kbdrate loadkeys loadunimap mapscrn openvt \
    psfaddtable psfgettable psfstriptable psfxtable setfont setkeycodes setleds setmetamode setvtrgb \
    showconsolefont showkey unicode_start unicode_stop; do
    [[ -x "/usr/bin/$command" ]] || { printf 'Missing Kbd command: %s\n' "$command" >&2; exit 1; }
done
[[ "$(readlink /usr/bin/psfaddtable)" == psfxtable ]]
[[ -d /usr/share/consolefonts && -d /usr/share/consoletrans && -d /usr/share/keymaps && -d /usr/share/unimaps ]]
[[ -f /usr/share/doc/kbd-2.8.0/cp1252.txt ]]
[[ -f docs/man/man8/resizecons.8 ]]
printf 'KBD_FINAL_INSTALL=PASS\nKBD_WORK_TREE=%s\nRESIZECONS_SOURCE_PRESERVED=YES\n' "$source_root"
CHROOT

printf '\nKbd Chapter 8 build/install completed; its valgrind-dependent test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
