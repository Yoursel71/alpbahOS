#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=0.12.0
readonly ARCHIVE="qcoro-$VERSION.tar.gz" STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-qcoro-$VERSION-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qcoro-$VERSION-d34-$STAMP.log"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as regular user.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"; sudo -n true || fail 'Non-interactive sudo unavailable.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/downloads"
lfs_acquire_writer_lock "$DATA"; exec > >(tee "$LOG") 2>&1

readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
  if [[ -r "$DATA/downloads/$ARCHIVE" ]]; then
    sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$ARCHIVE_PATH"
  else
    curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" \
      "https://github.com/danvratil/qcoro/archive/v$VERSION/$ARCHIVE"
    sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"
    mv "$DATA/downloads/$ARCHIVE.part-$STAMP" "$DATA/downloads/$ARCHIVE"
  fi
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb \
  PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6 \
  LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j6 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/qcoro-0.12.0"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -f "$source/CMakeLists.txt" ]]
cmake -S "$source" -B "$build" -D CMAKE_INSTALL_PREFIX=/opt/qt6 \
  -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_BUILD_TYPE=Release \
  -D BUILD_TESTING=OFF -D QCORO_BUILD_EXAMPLES=OFF -D BUILD_SHARED_LIBS=ON \
  -W no-dev > "$work/configure.log" 2>&1 || { tail -n 160 "$work/configure.log"; exit 1; }
cmake --build "$build" --parallel 6 > "$work/compile.log" 2>&1 || { tail -n 160 "$work/compile.log"; exit 1; }
mkdir -p "$stage"; DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1
libdir="$stage/opt/qt6/lib"
for name in Core DBus Network Qml Quick WebSockets; do [[ -e "$libdir/libQCoro6$name.so" ]]; done
[[ -f "$libdir/cmake/QCoro6/QCoro6Config.cmake" ]]
find "$stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$work/staged.list0"
BUILD

python3 - "$LFS" "$LFS$WORK/staged.list0" <<'PY'
import os,sys
root, manifest = sys.argv[1:]
paths=[p for p in open(manifest,'rb').read().split(b'\0') if p]
collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
print(f'QCoro staged paths: {len(paths)}; collisions: {len(collisions)}')
if collisions: raise SystemExit('Refusing to overwrite existing candidate paths: '+repr([os.fsdecode(p) for p in collisions[:20]]))
PY
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb \
  PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6 \
  LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX \
  /bin/bash -c 'cmake --install "$1/build"; ldconfig; test -f /opt/qt6/lib/cmake/QCoro6/QCoro6Config.cmake; for n in Core DBus Network Qml Quick WebSockets; do test -e "/opt/qt6/lib/libQCoro6$n.so"; done' _ "$WORK"
printf 'QCORO_D34_RESULT=PASS\nLOG=%s\n' "$LOG"
