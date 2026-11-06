#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=3.0.20
readonly ARCHIVE="libical-$VERSION.tar.gz"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-libical-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/libical-d34-$STAMP.log"
readonly BACKUP="$DATA/backups/libical-d34-$STAMP"

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo unavailable.'
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=libical\nVERSION=%s\nLOG=%s\n' "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=libical exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT

sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/libical-3.0.20"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"
tar -xzf "/sources/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" ]]
cmake -S "$source" -B "$build" \
  -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_BUILD_TYPE=Release -D SHARED_ONLY=yes \
  -D ICAL_BUILD_DOCS=false -D GOBJECT_INTROSPECTION=false \
  -D ICAL_GLIB_VAPI=false -D USE_BUILTIN_TZDATA=yes \
  -W no-dev > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
cmake --build "$build" --parallel 8 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -p "$stage"
DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1 || { tail -n 100 "$work/staged-install.log"; exit 1; }
[[ -f "$stage/usr/lib/libical.so" ]]
[[ -f "$stage/usr/lib/pkgconfig/libical.pc" || -f "$stage/usr/lib/pkgconfig/ical.pc" ]]
BUILD

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'MANIFEST'
import os,sys
root,src,dst=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
existing=[]
for path in paths:
    rel=os.fsdecode(path)
    if os.path.isabs(rel) or '..' in rel.split('/'):
        raise SystemExit(f'unsafe staged path: {rel}')
    if os.path.lexists(os.path.join(root,rel)):
        existing.append(path)
open(dst,'wb').write(b''.join(path+b'\0' for path in existing))
print(f'libical staged paths={len(paths)} existing targets={len(existing)}')
if existing:
    raise SystemExit(f'Refusing existing libical targets: {existing[:12]!r}')
MANIFEST

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
  /bin/bash -s -- "$WORK/stage" <<'INSTALL'
set -Eeuo pipefail
stage="$1"
cp -a "$stage"/. /
ldconfig
[[ -f /usr/lib/libical.so && -f /usr/include/libical/ical.h ]]
[[ -f /usr/lib/pkgconfig/libical.pc || -f /usr/lib/pkgconfig/ical.pc ]]
[[ "$(pkg-config --modversion libical)" == 3.0.20 || "$(pkg-config --modversion ical)" == 3.0.20 ]]
INSTALL
printf 'D34_RESULT=PASS PACKAGE=libical VERSION=%s LOG=%s\n' "$VERSION" "$LOG"
