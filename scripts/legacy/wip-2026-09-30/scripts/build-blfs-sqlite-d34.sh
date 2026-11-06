#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=3.50.4
readonly ARCHIVE=sqlite-autoconf-3500400.tar.gz STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/sqlite-$VERSION-d34-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/sqlite-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/sqlite-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/sqlite-$VERSION-d34-$STAMP"
readonly URL=https://www.sqlite.org/2025/sqlite-autoconf-3500400.tar.gz
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as regular user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"; sudo -n true || fail 'Non-interactive sudo unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v make >/dev/null && command -v cmake >/dev/null && test -e /usr/lib/libsqlite3.so && test ! -e /usr/lib/pkgconfig/sqlite3.pc'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then fail 'Another build process is active.'; fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"; exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'SQLITE_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'SQLITE_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
  if [[ -r "$DATA/downloads/$ARCHIVE" ]]; then sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$ARCHIVE_PATH"
  else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; mv "$DATA/downloads/$ARCHIVE.part-$STAMP" "$DATA/downloads/$ARCHIVE"; fi
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j6 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/sqlite-autoconf-3500400"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; cd "$source"
CPPFLAGS='-D SQLITE_ENABLE_COLUMN_METADATA=1 -D SQLITE_ENABLE_UNLOCK_NOTIFY=1 -D SQLITE_ENABLE_DBSTAT_VTAB=1 -D SQLITE_SECURE_DELETE=1' \
 ./configure --prefix=/usr --disable-static --enable-fts4 --enable-fts5 > "$work/configure.log" 2>&1 || { tail -n 100 "$work/configure.log"; exit 1; }
make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -p "$stage"; make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1
[[ -f "$stage/usr/lib/libsqlite3.so" && -f "$stage/usr/lib/pkgconfig/sqlite3.pc" && -x "$stage/usr/bin/sqlite3" ]]
BUILD
sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]; paths=[p for p in open(src,'rb').read().split(b'\0') if p]; collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in collisions)); print(f'SQLite staged paths: {len(paths)}; collisions: {len(collisions)}')
unexpected=[p for p in collisions if p != b'usr/lib/libsqlite3.so']
if unexpected: raise SystemExit(f'Unexpected pre-existing paths: {unexpected!r}')
PY
if [[ -s "$BACKUP/existing.list0" ]]; then
  sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/existing.list0"
  sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
  sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
  [[ -s "$BACKUP/archive.list" ]] || fail 'SQLite pre-install backup is empty.'
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$WORK/sqlite-autoconf-3500400" <<'INSTALL'
set -Eeuo pipefail
cd "$1"; make install; ldconfig
[[ "$(sqlite3 --version | awk '{print $1}')" == 3.50.4 && "$(pkg-config --modversion sqlite3)" == 3.50.4 ]]
[[ -f /usr/lib/libsqlite3.so && -f /usr/include/sqlite3.h ]]
INSTALL
printf 'SQLITE_RESULT=PASS\nLOG=%s\nVERSION=%s\n' "$LOG" "$VERSION" > "$STATUS"
