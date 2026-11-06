#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
module="${1:?pass a Qt module name}"
case "$module" in qtshadertools|qtdeclarative|qtwayland|qtsvg|qttools|qtmultimedia|qtspeech|qt5compat|qtsensors|qtpositioning|qtlocation|qtwebsockets) ;; *) echo "Unsupported Qt module: $module" >&2; exit 2 ;; esac
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=6.9.2
readonly ARCHIVE="${module}-everywhere-src-$VERSION.tar.xz" STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
# Keep compile products on the D34 runner's private tmpfs. Only source archives
# and installed payloads should enter the candidate subvolume/send stream.
readonly WORK="/dev/shm/alpbahos-d34-qt-$module-$VERSION-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qt-$module-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/qt-$module-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/qt-$module-$VERSION-d34-$STAMP"
readonly URL="https://download.qt.io/archive/qt/6.9/6.9.2/submodules/$ARCHIVE"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as regular user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"; sudo -n true || fail 'Non-interactive sudo unavailable.'
case "$module" in
  qtshadertools) preflight='[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 && ! -e /opt/qt6/lib/libQt6ShaderTools.so.6 ]]' ;;
  qtdeclarative) preflight='[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 && -e /opt/qt6/lib/libQt6ShaderTools.so.6 && ! -e /opt/qt6/lib/libQt6Quick.so.6 ]]' ;;
  qtwayland) preflight='[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 && -e /opt/qt6/lib/libQt6Quick.so.6 && ! -e /opt/qt6/lib/libQt6WaylandClient.so.6 ]]' ;;
  qtsvg) preflight='[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 && ! -e /opt/qt6/lib/libQt6Svg.so.6 ]]' ;;
  qttools) preflight='[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 && -e /opt/qt6/lib/libQt6Svg.so.6 && ! -e /opt/qt6/lib/cmake/Qt6LinguistTools/Qt6LinguistToolsConfig.cmake ]]' ;;
  qtmultimedia) preflight='[[ -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake && ! -e /opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake ]]' ;;
  qtspeech) preflight='[[ -f /opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake && ! -e /opt/qt6/lib/cmake/Qt6TextToSpeech/Qt6TextToSpeechConfig.cmake ]]' ;;
  qt5compat) preflight='[[ -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake && ! -e /opt/qt6/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfig.cmake ]]' ;;
  qtsensors) preflight='[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 && ! -e /opt/qt6/lib/libQt6Sensors.so.6 ]]' ;;
  qtpositioning) preflight='[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 && ! -e /opt/qt6/lib/cmake/Qt6Positioning/Qt6PositioningConfig.cmake ]]' ;;
  qtlocation) preflight='[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 && -e /opt/qt6/lib/cmake/Qt6Positioning/Qt6PositioningConfig.cmake && ! -e /opt/qt6/lib/cmake/Qt6Location/Qt6LocationConfig.cmake ]]' ;;
  qtwebsockets) preflight='[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 && ! -e /opt/qt6/lib/cmake/Qt6WebSockets/Qt6WebSocketsConfig.cmake ]]' ;;
esac
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX /bin/bash -c "$preflight" || fail "Qt $module preflight failed."
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then fail 'Another build process is active.'; fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"; exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'QT_MODULE_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'QT_MODULE_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
readonly ARCHIVE_PATH="$LFS/sources/qt/$ARCHIVE"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
  sudo -n mkdir -p "$LFS/sources/qt"
  if [[ -r "$DATA/downloads/$ARCHIVE" ]]; then sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$ARCHIVE_PATH"
  else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; mv "$DATA/downloads/$ARCHIVE.part-$STAMP" "$DATA/downloads/$ARCHIVE"; fi
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j6 /bin/bash -s -- "$ARCHIVE" "$WORK" "$module" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; module="$3"; version=6.9.2
source="$work/${module}-everywhere-src-$version"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/qt/$archive" -C "$work"
if [[ ! -d "$source" ]]; then echo "Expected source directory is missing: $source" >&2; exit 1; fi
qt_version="$(qmake6 -query QT_VERSION)" || { echo 'qmake6 -query QT_VERSION failed' >&2; exit 1; }
[[ "$qt_version" == "$version" ]] || { echo "Qt version mismatch: expected $version, got $qt_version" >&2; exit 1; }
mkdir -p "$build"; cd "$build"
if [[ "$module" == qtspeech || "$module" == qtmultimedia ]]; then
  extra_args=()
  if [[ "$module" == qtmultimedia ]]; then
    extra_args=(-D INPUT_ffmpeg=no -D INPUT_gstreamer=no -D INPUT_pulseaudio=no -D INPUT_pipewire=no -D INPUT_alsa=no)
  fi
  cmake -S "$source" -B "$build" -D CMAKE_INSTALL_PREFIX=/opt/qt6 -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_BUILD_TYPE=Release -D QT_BUILD_TESTS=OFF -D QT_BUILD_EXAMPLES=OFF "${extra_args[@]}" > "$work/configure.log" 2>&1 || { tail -n 140 "$work/configure.log"; exit 1; }
else
  qt-configure-module "$source" > "$work/configure.log" 2>&1 || { tail -n 140 "$work/configure.log"; exit 1; }
fi
if [[ "$module" == qtspeech || "$module" == qtmultimedia ]]; then
  cmake --build "$build" --parallel 6 > "$work/compile.log" 2>&1 || { tail -n 160 "$work/compile.log"; exit 1; }
else
  ninja -j6 > "$work/compile.log" 2>&1 || { tail -n 160 "$work/compile.log"; exit 1; }
fi
mkdir -p "$stage"; DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1
case "$module" in
 qtshadertools) [[ -f "$stage/opt/qt6/lib/libQt6ShaderTools.so.6" && -x "$stage/opt/qt6/bin/qsb" ]] ;;
 qtdeclarative) [[ -f "$stage/opt/qt6/lib/libQt6Qml.so.6" && -f "$stage/opt/qt6/lib/libQt6Quick.so.6" ]] ;;
 qtwayland) [[ -f "$stage/opt/qt6/lib/libQt6WaylandClient.so.6" && -f "$stage/opt/qt6/plugins/platforms/libqwayland-egl.so" ]] ;;
 qtsvg) [[ -f "$stage/opt/qt6/lib/libQt6Svg.so.6" && -f "$stage/opt/qt6/plugins/imageformats/libqsvg.so" ]] ;;
 qttools) [[ -f "$stage/opt/qt6/lib/cmake/Qt6LinguistTools/Qt6LinguistToolsConfig.cmake" && -x "$stage/opt/qt6/bin/lrelease" && -x "$stage/opt/qt6/bin/lupdate" ]] ;;
 qtmultimedia) [[ -f "$stage/opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake" && -f "$stage/opt/qt6/lib/libQt6Multimedia.so.6" ]] ;;
 qtspeech) [[ -f "$stage/opt/qt6/lib/cmake/Qt6TextToSpeech/Qt6TextToSpeechConfig.cmake" && -f "$stage/opt/qt6/lib/libQt6TextToSpeech.so.6" ]] ;;
 qt5compat) [[ -f "$stage/opt/qt6/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfig.cmake" && -e "$stage/opt/qt6/lib/libQt6Core5Compat.so" ]] ;;
 qtsensors) [[ -f "$stage/opt/qt6/lib/libQt6Sensors.so.6" && -f "$stage/opt/qt6/lib/cmake/Qt6Sensors/Qt6SensorsConfig.cmake" ]] ;;
 qtpositioning) [[ -f "$stage/opt/qt6/lib/cmake/Qt6Positioning/Qt6PositioningConfig.cmake" && -f "$stage/opt/qt6/lib/libQt6Positioning.so.6" ]] ;;
 qtlocation) [[ -f "$stage/opt/qt6/lib/cmake/Qt6Location/Qt6LocationConfig.cmake" && -f "$stage/opt/qt6/lib/libQt6Location.so.6" ]] ;;
 qtwebsockets) [[ -f "$stage/opt/qt6/lib/cmake/Qt6WebSockets/Qt6WebSocketsConfig.cmake" && -f "$stage/opt/qt6/lib/libQt6WebSockets.so.6" ]] ;;
esac
BUILD
sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]; paths=[p for p in open(src,'rb').read().split(b'\0') if p]; collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in collisions)); print(f'Qt module staged paths: {len(paths)}; collisions: {len(collisions)}')
if collisions: raise SystemExit('Refusing to overwrite existing candidate paths')
PY
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX /bin/bash -s -- "$WORK/build" "$module" <<'INSTALL'
set -Eeuo pipefail
build="$1"; module="$2"; cmake --install "$build"; ldconfig
case "$module" in
 qtshadertools) [[ -f /opt/qt6/lib/libQt6ShaderTools.so.6 && -x /opt/qt6/bin/qsb ]] ;;
 qtdeclarative) [[ -f /opt/qt6/lib/libQt6Qml.so.6 && -f /opt/qt6/lib/libQt6Quick.so.6 && -x /opt/qt6/bin/qml ]] ;;
 qtwayland) [[ -f /opt/qt6/lib/libQt6WaylandClient.so.6 && -f /opt/qt6/plugins/platforms/libqwayland-egl.so ]] ;;
 qtsvg) [[ -f /opt/qt6/lib/libQt6Svg.so.6 && -f /opt/qt6/plugins/imageformats/libqsvg.so && -f /opt/qt6/lib/cmake/Qt6Svg/Qt6SvgConfig.cmake ]] ;;
 qttools) [[ -f /opt/qt6/lib/cmake/Qt6LinguistTools/Qt6LinguistToolsConfig.cmake && -x /opt/qt6/bin/lrelease && -x /opt/qt6/bin/lupdate ]] ;;
 qtmultimedia) [[ -f /opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake && -e /opt/qt6/lib/libQt6Multimedia.so.6 ]] ;;
 qtspeech) [[ -f /opt/qt6/lib/cmake/Qt6TextToSpeech/Qt6TextToSpeechConfig.cmake && -e /opt/qt6/lib/libQt6TextToSpeech.so.6 ]] ;;
 qt5compat) [[ -f /opt/qt6/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfig.cmake && -e /opt/qt6/lib/libQt6Core5Compat.so ]] ;;
 qtsensors) [[ -f /opt/qt6/lib/libQt6Sensors.so.6 && -f /opt/qt6/lib/cmake/Qt6Sensors/Qt6SensorsConfig.cmake ]] ;;
 qtpositioning) [[ -f /opt/qt6/lib/cmake/Qt6Positioning/Qt6PositioningConfig.cmake && -f /opt/qt6/lib/libQt6Positioning.so.6 ]] ;;
 qtlocation) [[ -f /opt/qt6/lib/cmake/Qt6Location/Qt6LocationConfig.cmake && -f /opt/qt6/lib/libQt6Location.so.6 ]] ;;
 qtwebsockets) [[ -f /opt/qt6/lib/cmake/Qt6WebSockets/Qt6WebSocketsConfig.cmake && -f /opt/qt6/lib/libQt6WebSockets.so.6 ]] ;;
esac
INSTALL
printf 'QT_MODULE_RESULT=PASS\nLOG=%s\nVERSION=%s\n' "$LOG" "$VERSION" > "$STATUS"
