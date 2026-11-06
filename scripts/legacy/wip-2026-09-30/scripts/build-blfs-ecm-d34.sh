#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=6.17.0
readonly ARCHIVE="extra-cmake-modules-$VERSION.tar.xz"
readonly PATCH="extra-cmake-modules-$VERSION-upstream_fix-1.patch"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-ecm-$VERSION-$STAMP"
readonly BUILD="$WORK/build" STAGE="$WORK/stage"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/extra-cmake-modules-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/extra-cmake-modules-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/extra-cmake-modules-d34-$STAMP"

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular host user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig CMAKE_PREFIX_PATH=/opt/qt6 LC_ALL=POSIX \
    /bin/bash -c '[[ "$(cmake --version | sed -n "1s/^cmake version //p")" == 4.1.0 && -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake && ! -e /usr/share/ECM/cmake/ECMConfig.cmake ]]' \
    || fail 'ECM requires CMake 4.1.0 and Qt 6.9.2; existing ECM paths must be absent.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another package build is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'ECM_D34_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'ECM_D34_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

ensure_source(){
    local name="$1" url="$2" path="$DATA/downloads/$1"
    if [[ ! -r "$path" ]]; then
        local temp="$path.part-$STAMP"
        curl --fail --location --retry 3 --output "$temp" "$url"
        mv -- "$temp" "$path"
    fi
    sudo -n install -o 0 -g 0 -m 0644 "$path" "$LFS/sources/$name"
}
ensure_source "$ARCHIVE" "https://download.kde.org/stable/frameworks/6.17/$ARCHIVE"
ensure_source "$PATCH" "https://www.linuxfromscratch.org/patches/blfs/12.4/$PATCH"

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig CMAKE_PREFIX_PATH=/opt/qt6 \
    QT6DIR=/opt/qt6 LC_ALL=POSIX MAKEFLAGS=-j6 \
    /bin/bash -s -- "$ARCHIVE" "$PATCH" "$WORK" "$BUILD" "$STAGE" <<'BUILD'
set -Eeuo pipefail
archive="$1"; patch="$2"; work="$3"; build="$4"; stage="$5"
source="$work/extra-cmake-modules-6.17.0"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" ]]
cd "$source"
patch -Np1 -i "/sources/$patch"
sed -i '/"lib64"/s/64//' kde-modules/KDEInstallDirsCommon.cmake
sed -e '/PACKAGE_INIT/i set(SAVE_PACKAGE_PREFIX_DIR "${PACKAGE_PREFIX_DIR}")' \
    -e '/^include/a set(PACKAGE_PREFIX_DIR "${SAVE_PACKAGE_PREFIX_DIR}")' \
    -i ECMConfig.cmake.in
cmake -S . -B "$build" \
    -D CMAKE_INSTALL_PREFIX=/usr \
    -D BUILD_WITH_QT6=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
cmake --build "$build" --parallel 6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -p "$stage"
DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1
[[ -f "$stage/usr/share/ECM/cmake/ECMConfig.cmake" ]]
BUILD

sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in collisions))
print(f'ECM staged files/symlinks={len(paths)} collisions={len(collisions)}')
if collisions: raise SystemExit('Refusing to overwrite existing candidate paths')
PY

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    CMAKE_PREFIX_PATH=/opt/qt6 LC_ALL=POSIX /bin/bash -s -- "$BUILD" <<'INSTALL'
set -Eeuo pipefail
cmake --install "$1"
[[ -f /usr/share/ECM/cmake/ECMConfig.cmake ]]
[[ -f /usr/share/ECM/modules/ECMFindModuleHelpers.cmake ]]
[[ "$(cmake --version | sed -n '1s/^cmake version //p')" == 4.1.0 ]]
INSTALL
printf 'ECM_D34_RESULT=PASS\nLOG=%s\nVERSION=%s\n' "$LOG" "$VERSION" > "$STATUS"
