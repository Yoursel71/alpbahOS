#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=0.60.8.1
readonly PACKAGE=aspell ARCHIVE=aspell-0.60.8.1.tar.gz
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-$PACKAGE-$VERSION-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/$PACKAGE-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/$PACKAGE-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/$PACKAGE-d34-$STAMP"

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular host user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another package build is active.'
fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$STATUS"; else printf 'D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

archive_path="$DATA/downloads/$ARCHIVE"
if [[ ! -r "$archive_path" ]]; then
    temp="$archive_path.part-$STAMP"
    curl --fail --location --retry 3 --output "$temp" "https://ftp.gnu.org/gnu/aspell/$ARCHIVE"
    mv -- "$temp" "$archive_path"
fi
sudo -n install -o 0 -g 0 -m 0644 "$archive_path" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    LC_ALL=POSIX MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/aspell-0.60.8.1"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"
tar -xf "/sources/$archive" -C "$work"
[[ -x "$source/configure" && -f "$source/modules/speller/default/vector_hash-t.hpp" ]]
cd "$source"
sed -e 's/; i.*size)/, e = end(); i != e; ++i, ++size_)/' -i modules/speller/default/vector_hash-t.hpp
./configure --prefix=/usr > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
make -j8 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -p "$stage"
make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 100 "$work/staged-install.log"; exit 1; }
[[ -x "$stage/usr/bin/aspell" && -f "$stage/usr/include/aspell.h" && -f "$stage/usr/lib/libaspell.so" ]]
BUILD

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(collisions))
print(f"Aspell staged paths={len(paths)} collisions={len(collisions)}")
unexpected=[p for p in collisions if p != b'usr/share/info/dir']
if unexpected: raise SystemExit(f"Refusing unexpected existing candidate paths: {unexpected!r}")
PY
if [[ -s "$BACKUP/existing.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$BACKUP/existing.list0"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/preexisting-files.list"
    [[ -s "$BACKUP/preexisting-files.list" ]] || fail 'Aspell pre-install index backup is empty.'
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$WORK/aspell-0.60.8.1" <<'INSTALL'
set -Eeuo pipefail
make -C "$1" install
ldconfig
aspell --version | head -n1 | grep -Fq '0.60.8.1'
[[ -f /usr/include/aspell.h && -e /usr/lib/libaspell.so && -x /usr/bin/aspell ]]
INSTALL
printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$STATUS"
