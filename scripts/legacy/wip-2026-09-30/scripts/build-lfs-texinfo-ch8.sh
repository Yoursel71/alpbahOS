#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly ARCHIVE="$LFS/sources/texinfo-7.2.tar.xz"
readonly WORK_ROOT="/sources/texinfo-7.2-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/texinfo-7.2"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/texinfo-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/texinfo-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/texinfo-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/texinfo-before-files.tar"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"
readonly STATUS="$LOG_DIR/texinfo-ch8-$STAMP.status"

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
[[ -r "$ARCHIVE" ]] || fail 'The Texinfo 7.2 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Texinfo work tree: $WORK_ROOT"
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
        printf 'TEXINFO_SCRIPT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'TEXINFO_SCRIPT_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building LFS Chapter 8 Texinfo 7.2.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The LFS page lists make check; package tests are skipped per user preference.\n'
printf 'Optional install-tex is skipped because the target does not include a TeX installation.\n'

(
    cd "$LFS"
    for name in info install-info makeinfo pdftexi2dvi pod2texi texi2any texi2dvi texi2pdf texindex; do
        path="usr/bin/$name"
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    for path in usr/lib/texi2any usr/share/texi2any usr/share/texinfo usr/share/info/dir; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    find usr/share/info -maxdepth 1 \( -type f -o -type l \) \
        \( -name 'texinfo.info*' -o -name 'info.info*' -o -name 'info-stnd.info' \
           -o -name 'texi2any_api.info' -o -name 'texi2any_internals.info' \) -print0 2>/dev/null || true
    find usr/share/man -maxdepth 2 \( -type f -o -type l \) \
        \( -name 'info.1*' -o -name 'install-info.1*' -o -name 'makeinfo.1*' \
           -o -name 'pdftexi2dvi.1*' -o -name 'pod2texi.1*' -o -name 'texi2any.1*' \
           -o -name 'texi2dvi.1*' -o -name 'texi2pdf.1*' -o -name 'texindex.1*' \
           -o -name 'info.5*' -o -name 'texinfo.5*' \) -print0 2>/dev/null || true
    find usr/share/doc -mindepth 1 -maxdepth 1 \( -type f -o -type d -o -type l \) -name 'texinfo*' -print0 2>/dev/null || true
    find usr/share/locale \( -type f -o -type l \) -path '*/LC_MESSAGES/texinfo*.mo' -print0 2>/dev/null || true
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Texinfo backup archive is empty.'
    printf 'Existing Texinfo-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Texinfo target files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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

tar -xJf /sources/texinfo-7.2.tar.xz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Texinfo configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
if ! grep -Fq '! $output_file eq' tp/Texinfo/Convert/*.pm; then
    printf 'LFS Perl-5.42 warning fix pattern was not found.\n' >&2
    exit 1
fi
sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm
if grep -Fq '! $output_file eq' tp/Texinfo/Convert/*.pm; then
    printf 'LFS Perl-5.42 warning fix did not apply.\n' >&2
    exit 1
fi
./configure --prefix=/usr > "$work_root/configure.log" 2>&1

if make -j4 > "$work_root/compile.log" 2>&1; then
    printf 'TEXINFO_BUILD_RESULT=PASS\n'
else
    result=$?
    printf 'TEXINFO_BUILD_RESULT=FAIL exit=%s\n' "$result"
    tail -n 100 "$work_root/compile.log"
    exit "$result"
fi

make -j1 install

[[ "$(/usr/bin/texi2any --version | sed -n '1p')" == 'texi2any (GNU texinfo) 7.2' ]]
[[ "$(readlink /usr/bin/makeinfo)" == texi2any ]]
for command in info install-info makeinfo pdftexi2dvi pod2texi texi2any texi2dvi texi2pdf texindex; do
    [[ -x "/usr/bin/$command" ]] || { printf 'Missing Texinfo command: %s\n' "$command" >&2; exit 1; }
done
[[ -d /usr/lib/texi2any && -d /usr/share/texi2any && -d /usr/share/texinfo ]]
for module in MiscXS.so Parsetexi.so XSParagraph.so; do
    [[ -f "/usr/lib/texi2any/$module" ]] || { printf 'Missing Texinfo module: %s\n' "$module" >&2; exit 1; }
done
[[ -f /usr/share/info/texinfo.info && -f /usr/share/info/info-stnd.info ]]
[[ -f /usr/share/info/texi2any_api.info && -f /usr/share/info/texi2any_internals.info ]]
[[ -f /usr/share/info/dir ]]
printf 'TEXINFO_FINAL_INSTALL=PASS\nTEXINFO_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nTexinfo Chapter 8 build/install completed; package tests and optional install-tex were skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nStatus: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
