#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly ARCHIVE="$LFS/sources/vim-9.1.1629.tar.gz"
readonly WORK_ROOT="/sources/vim-9.1.1629-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/vim-9.1.1629"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/vim-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/vim-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/vim-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/vim-before-files.tar"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"
readonly STATUS="$LOG_DIR/vim-ch8-$STAMP.status"

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
[[ -r "$ARCHIVE" ]] || fail 'The Vim 9.1.1629 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Vim work tree: $WORK_ROOT"
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
        printf 'VIM_SCRIPT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'VIM_SCRIPT_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building LFS Chapter 8 Vim 9.1.1629.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The package test suite is skipped per user preference.\n'

(
    cd "$LFS"
    for name in ex rview rvim vi view vim vimdiff vimtutor xxd; do
        path="usr/bin/$name"
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    for path in usr/share/vim usr/share/doc/vim-9.1.1629 etc/vimrc; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    find usr/share/man \( -type f -o -type l \) -print0 2>/dev/null | while IFS= read -r -d '' path; do
        case "${path##*/}" in
            vim*.1*|vi.1*|ex.1*|view.1*|rvim.1*|rview.1*|evim.1*|eview.1*| \
            vimdiff.1*|vimtutor.1*|gvim.1*|gview.1*|rgvim.1*|rgview.1*|gvimdiff.1*)
                printf '%s\0' "$path" ;;
        esac
    done
    for path in usr/share/icons/hicolor/48x48/apps/gvim.png \
        usr/share/icons/locolor/32x32/apps/gvim.png usr/share/icons/locolor/16x16/apps/gvim.png \
        usr/share/applications/vim.desktop usr/share/applications/gvim.desktop; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    find usr/share/locale -path '*/LC_MESSAGES/vim.mo' -print0 2>/dev/null || true
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Vim backup archive is empty.'
    printf 'Existing Vim-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Vim target files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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

tar -xzf /sources/vim-9.1.1629.tar.gz -C "$work_root"
[[ -f "$source_root/src/feature.h" ]] || { printf 'Vim feature.h is missing.\n' >&2; exit 1; }
if ! grep -Fq '#define SYS_VIMRC_FILE "/etc/vimrc"' "$source_root/src/feature.h"; then
    printf '\n#define SYS_VIMRC_FILE "/etc/vimrc"\n' >> "$source_root/src/feature.h"
fi
grep -Fq '#define SYS_VIMRC_FILE "/etc/vimrc"' "$source_root/src/feature.h"
cd "$source_root"
./configure --prefix=/usr > "$work_root/configure.log" 2>&1

if make -j4 > "$work_root/compile.log" 2>&1; then
    printf 'VIM_BUILD_RESULT=PASS\n'
else
    result=$?
    printf 'VIM_BUILD_RESULT=FAIL exit=%s\n' "$result"
    tail -n 100 "$work_root/compile.log"
    exit "$result"
fi

make -j1 install
ln -sfn vim /usr/bin/vi
for vim_man in /usr/share/man/man1/vim.1 /usr/share/man/*/man1/vim.1; do
    [[ -f "$vim_man" ]] || continue
    ln -sfn vim.1 "$(dirname "$vim_man")/vi.1"
done
mkdir -p /usr/share/doc
ln -sfn ../vim/vim91/doc /usr/share/doc/vim-9.1.1629
cat > /etc/vimrc <<'VIMRC'
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
VIMRC

(/usr/bin/vim --version | grep -Fq 'VIM - Vi IMproved 9.1') || {
    /usr/bin/vim --version | sed -n '1p'
    exit 1
}
(/usr/bin/vim --version | grep -Eq '^Included patches: 1-1629([[:space:]]|$)') || {
    /usr/bin/vim --version | sed -n '1,3p'
    exit 1
}
for command in ex rview rvim view vim vimdiff vimtutor xxd; do
    [[ -x "/usr/bin/$command" ]] || { printf 'Missing Vim command: %s\n' "$command" >&2; exit 1; }
done
[[ -L /usr/bin/vi && "$(readlink /usr/bin/vi)" == vim ]]
[[ -d /usr/share/vim/vim91 && -d /usr/share/vim/vim91/doc ]]
[[ -L /usr/share/doc/vim-9.1.1629 && "$(readlink /usr/share/doc/vim-9.1.1629)" == ../vim/vim91/doc ]]
[[ -f /usr/share/man/man1/vim.1 && -L /usr/share/man/man1/vi.1 ]]
[[ -f /etc/vimrc ]]
grep -Fq 'set nocompatible' /etc/vimrc
grep -Fq 'set mouse=' /etc/vimrc
readelf -h /usr/bin/vim | grep -F 'Advanced Micro Devices X86-64'
ldd /usr/bin/vim | grep -E 'libc[.]so[.]6.*[/]usr/lib/'
printf 'VIM_FINAL_INSTALL=PASS\nVIM_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nVim Chapter 8 build/install completed; the package test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nStatus: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
