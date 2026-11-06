#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/groff-1.23.0-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/groff-1.23.0"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/groff-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/groff-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/groff-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/groff-before-files.tar"
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
[[ -r "$LFS/sources/groff-1.23.0.tar.gz" ]] || fail 'The Groff 1.23.0 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Groff work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Groff 1.23.0 with A4 as the default paper size.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The Groff test suite is not being run.\n'

(
    cd "$LFS"
    command_names=(
        addftinfo afmtodit chem eqn eqn2graph gdiffmk glilypond gperl gpinyin grap2graph grn grodvi groff groffer grog
        grolbp grolj4 gropdf grops grotty hpftodit indxbib lkbib lookbib mmroff neqn nroff pdfmom pdfroff pfbtops pic
        pic2graph post-grohtml preconv pre-grohtml refer roff2dvi roff2html roff2pdf roff2ps roff2text roff2x soelim
        tbl tfmtodit troff
    )
    for name in "${command_names[@]}"; do
        if [[ -e "usr/bin/$name" || -L "usr/bin/$name" ]]; then printf 'usr/bin/%s\0' "$name"; fi
        for man_section in usr/share/man/man[0-9]*; do
            [[ -d "$man_section" ]] || continue
            section_number="${man_section##*/man}"
            path="$man_section/$name.$section_number"
            if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
        done
    done
    for path in usr/lib/groff usr/share/groff usr/share/doc/groff-1.23.0 usr/share/info/groff.info \
        usr/share/info/groff.info.gz usr/share/info/dir; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Groff backup archive is empty.'
    printf 'Existing Groff-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Groff files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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

tar -xzf /sources/groff-1.23.0.tar.gz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Groff configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
PAGE=A4 ./configure --prefix=/usr
make
make install

/usr/bin/groff --version
[[ "$(/usr/bin/groff --version | sed -n '1p')" == 'GNU groff version 1.23.0' ]]
for command in groff nroff troff eqn tbl soelim; do
    [[ -x "/usr/bin/$command" ]] || { printf 'Missing Groff command: %s\n' "$command" >&2; exit 1; }
done
[[ -d /usr/lib/groff && -d /usr/share/groff && -d /usr/share/doc/groff-1.23.0 ]]
[[ -f /usr/share/groff/1.23.0/font/devpdf/DESC ]]
printf 'GROFF_FINAL_INSTALL=PASS\nGROFF_WORK_TREE=%s\nGROFF_DEFAULT_PAGE=A4\n' "$source_root"
CHROOT

printf '\nGroff Chapter 8 build/install completed with A4 default; its test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
