#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=6.4.4
readonly PACKAGE="${ALPBAHOS_D34_PACKAGE:?D34 runner must set ALPBAHOS_D34_PACKAGE}"
readonly ARCHIVE="$PACKAGE-$VERSION.tar.xz"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-plasma-$PACKAGE-$VERSION-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/plasma-$PACKAGE-$VERSION-d34-$STAMP.log"
readonly BACKUP="$DATA/backups/plasma-$PACKAGE-$VERSION-d34-$STAMP"

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the D34 candidate.'
python3 - "$PACKAGE" "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/plasma-d34-package-order.json" <<'PY'
import json,sys
if sys.argv[1] not in json.load(open(sys.argv[2], encoding="utf-8")):
    raise SystemExit("package is not in the approved Plasma D34 order")
PY
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo unavailable.'
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT

sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
patches=()
case "$PACKAGE" in
  kwin) patches=(kwin-6.4.4-wayland-only-killer.patch) ;;
  libplasma) patches=(libplasma-wayland-only-1.patch) ;;
  libkscreen) patches=(libkscreen-6.4.4-wayland-only.patch) ;;
  plasma-workspace) patches=(plasma-workspace-6.4.4-wayland-no-x11.patch plasma-workspace-6.4.4-wayland-no-xwayland.patch) ;;
  plasma-integration) patches=(plasma-integration-6.4.4-wayland-no-x11.patch) ;;
  plasma-desktop) patches=(plasma-desktop-6.4.4-wayland-no-netwm.patch plasma-desktop-6.4.4-wayland-no-ksmserver-dbus.patch) ;;
esac
for patch in "${patches[@]}"; do
  [[ -r "$DATA/downloads/$patch" ]] || fail "Missing approved patch: $DATA/downloads/$patch"
  sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$patch" "$LFS/sources/$patch"
done

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
  CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr ECM_DIR=/usr/share/ECM/cmake \
  Qt6_DIR=/opt/qt6/lib/cmake/Qt6 Qt6Svg_DIR=/opt/qt6/lib/cmake/Qt6Svg \
  PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:/opt/kf6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig \
  LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j8 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" "$PACKAGE" "${patches[*]}" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; package="$3"; patch_list="$4"
source="$work/$package-6.4.4"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" ]]
cd "$source"
if [[ -n "$patch_list" ]]; then
  for patch in $patch_list; do patch -Np1 -i "/sources/$patch"; done
fi
args=(
  -D CMAKE_INSTALL_PREFIX=/opt/kf6
  -D CMAKE_INSTALL_LIBDIR=lib
  -D CMAKE_INSTALL_LIBEXECDIR=libexec
  -D CMAKE_BUILD_TYPE=Release
  -D BUILD_TESTING=OFF
  -D CMAKE_SKIP_INSTALL_RPATH=ON
  -D CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr
  -D ECM_DIR=/usr/share/ECM/cmake
  -D Qt6_DIR=/opt/qt6/lib/cmake/Qt6
  -D Qt6Svg_DIR=/opt/qt6/lib/cmake/Qt6Svg
)
case "$package" in
  breeze) args+=( -D BUILD_QT5=OFF -D BUILD_QT6=ON ) ;;
  plasma-integration) args+=( -D BUILD_QT5=OFF -D BUILD_QT6=ON ) ;;
  plasma-desktop) args+=( -D BUILD_KCM_MOUSE_X11=OFF -D BUILD_KCM_TOUCHPAD_X11=OFF ) ;;
  kdecoration|breeze|plasma-activities|kglobalacceld|kwayland|layer-shell-qt|libplasma|libksysguard|plasma5support|plasma-workspace|plasma-integration|plasma-desktop) args+=( -D WITH_X11=OFF ) ;;
  libkscreen) args+=( -D CMAKE_DISABLE_FIND_PACKAGE_XCB=TRUE ) ;;
  kwin) args+=( -D KWIN_BUILD_X11=OFF -D KWIN_BUILD_SCREENLOCKER=OFF ) ;;
esac
cmake -S "$source" -B "$build" "${args[@]}" -W no-dev > "$work/configure.log" 2>&1 || { tail -n 140 "$work/configure.log"; exit 1; }
cmake --build "$build" --parallel 8 > "$work/compile.log" 2>&1 || {
  tail -n 140 "$work/compile.log"
  printf '\n--- compiler and linker diagnostics ---\n'
  grep -inE -C 4 'error:|fatal error:|undefined reference|collect2:|ld: cannot|Error [0-9]+' "$work/compile.log" | tail -n 160 || true
  exit 1
}
mkdir -p "$stage"
DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
[[ -s "$build/install_manifest.txt" ]]
grep -q '^/opt/kf6/' "$build/install_manifest.txt"
find "$stage/opt/kf6" -mindepth 1 -print -quit | grep -q .
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
print(f'{os.environ.get("ALPBAHOS_D34_PACKAGE","plasma")} staged paths={len(paths)} existing targets={len(existing)}')
if existing:
    raise SystemExit(f'Refusing existing Plasma targets: {existing[:12]!r}')
MANIFEST

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/opt/kf6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
  LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib LC_ALL=POSIX \
  /bin/bash -s -- "$WORK/stage" "$PACKAGE" <<'INSTALL'
set -Eeuo pipefail
stage="$1"; package="$2"
cp -a "$stage"/. /
ldconfig
case "$package" in
  kwin) [[ -x /opt/kf6/bin/kwin_wayland ]] ;;
  plasma-workspace) [[ -x /opt/kf6/bin/startplasma-wayland && -x /opt/kf6/bin/plasma_session ]] ;;
  plasma-desktop) [[ -d /opt/kf6/share/plasma ]] ;;
  *) [[ -d /opt/kf6 ]] ;;
esac
INSTALL
printf 'D34_RESULT=PASS PACKAGE=%s VERSION=%s LOG=%s\n' "$PACKAGE" "$VERSION" "$LOG"
