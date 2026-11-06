#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=1.18.0
readonly PACKAGE=plasma-wayland-protocols
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly ARCHIVE="$PACKAGE-$VERSION.tar.xz"
readonly WORK="/dev/shm/alpbahos-d34-$PACKAGE-$VERSION-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/$PACKAGE-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/$PACKAGE-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/$PACKAGE-d34-$STAMP"
readonly URL="https://download.kde.org/stable/plasma-wayland-protocols/$ARCHIVE"

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular host user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -c '[[ -f /usr/share/ECM/cmake/ECMConfig.cmake ]] && [[ "$(cmake --version | head -n1)" == "cmake version 4.1.0" ]]' \
    || fail 'ECM 6.17.0 and CMake 4.1.0 are required.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another package build is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=%s\nLOG=%s\n' "$PACKAGE" "$LOG" > "$STATUS"; else printf 'D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

archive_path="$DATA/downloads/$ARCHIVE"
if [[ ! -r "$archive_path" ]]; then
    temp="$archive_path.part-$STAMP"
    curl --fail --location --retry 3 --output "$temp" "$URL"
    mv -- "$temp" "$archive_path"
fi
sudo -n install -o 0 -g 0 -m 0644 "$archive_path" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    CMAKE_PREFIX_PATH=/usr:/usr/share/ECM ECM_DIR=/usr/share/ECM/cmake LC_ALL=POSIX MAKEFLAGS=-j8 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/plasma-wayland-protocols-1.18.0"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" ]]
cmake -S "$source" -B "$build" -D CMAKE_INSTALL_PREFIX=/usr -D ECM_DIR=/usr/share/ECM/cmake \
    -D CMAKE_PREFIX_PATH=/usr/share/ECM -D CMAKE_BUILD_TYPE=Release -W no-dev > "$work/configure.log" 2>&1 \
    || { tail -n 100 "$work/configure.log"; exit 1; }
cmake --build "$build" --parallel 8 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -p "$stage"
DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1 || { tail -n 100 "$work/staged-install.log"; exit 1; }
[[ -d "$stage/usr/share/plasma-wayland-protocols" && -f "$stage/usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake" ]]
BUILD

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(collisions))
print(f"Plasma Wayland Protocols staged paths={len(paths)} collisions={len(collisions)}")
if collisions: raise SystemExit("Refusing to overwrite existing candidate paths")
PY
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/usr:/usr/share/ECM \
    ECM_DIR=/usr/share/ECM/cmake LC_ALL=POSIX /bin/bash -s -- "$WORK/build" <<'INSTALL'
set -Eeuo pipefail
cmake --install "$1"
[[ -f /usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake ]]
(( $(find /usr/share/plasma-wayland-protocols -type f | wc -l) >= 10 ))
INSTALL
printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$STATUS"
