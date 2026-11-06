#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build LOGDIR=/mnt/alpbahOS-data/alpbahOS-build/logs/blfs-12.4-systemd VERSION=6.9.2
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG="$LOGDIR/qt-multimedia-speech-6.9.2-$STAMP.log" STATUS="$LOGDIR/qt-multimedia-speech-6.9.2-$STAMP.status"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" && -d "$DATA/lfs" && "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail 'Expected ext4 LFS target is unavailable.'
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not the expected HDD bind mount.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1=="make"||$1=="ninja"||$1=="expect"||$1=="runtest"{f=1} END{exit f?0:1}'; then fail 'Another build/test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '[[ -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake && -f /opt/qt6/lib/cmake/Qt6ShaderTools/Qt6ShaderToolsConfig.cmake ]]'
mkdir -p "$LOGDIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads"
exec 9>"$DATA/locks/lfs-build-writer.lock"; flock -n 9 || fail 'Another LFS writer holds the lock.'
exec > >(tee "$LOG") 2>&1
CURRENT=initial
record_result() { local rc=$?; if ((rc==0)); then printf 'QT_MULTIMEDIA_SPEECH_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'QT_MULTIMEDIA_SPEECH_RESULT=FAIL module=%s exit=%s\nLOG=%s\n' "$CURRENT" "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
printf 'Qt Multimedia and Qt Speech %s for /opt/qt6; module tests and manual checksums skipped.\n' "$VERSION"
fetch() { local a="$1" u="$2" t="$DATA/downloads/$1.partial-$STAMP"; if ! sudo -n test -r "$LFS/sources/$a"; then curl --fail --location --retry 3 --output "$t" "$u"; sudo -n install -o 0 -g 0 -m 0644 "$t" "$LFS/sources/$a"; else printf 'Using cached source %s\n' "$a"; fi; }
backup_stage() {
  local stage="$1" backup="$2"
  sudo -n find "$LFS$stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$backup/staged.list0"
  python3 - "$LFS" "$backup/staged.list0" "$backup/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
with open(src,'rb') as f: paths=[p for p in f.read().split(b'\0') if p]
old=[]
for p in paths:
 r=os.fsdecode(p)
 if os.path.isabs(r) or '..' in r.split('/'): raise SystemExit('Unsafe staged path')
 if os.path.lexists(os.path.join(root,r)): old.append(p)
with open(dst,'wb') as f:
 for p in sorted(set(old)): f.write(p+b'\0')
print('staged',len(paths),'existing',len(set(old)))
PY
  if [[ -s "$backup/existing.list0" ]]; then
    sudo -n tar -c --numeric-owner --acls --xattrs -f "$backup/preexisting.tar" -C "$LFS" --null -T "$backup/existing.list0"
    sudo -n chown "$(id -u):$(id -g)" "$backup/preexisting.tar"
    sudo -n tar -tf "$backup/preexisting.tar" > "$backup/preexisting.list"
    [[ -s "$backup/preexisting.list" ]] || fail 'Pre-install backup archive is empty.'
  else printf 'No pre-existing target paths.\n' > "$backup/no-preexisting.txt"; fi
}
build_module() {
  local module="$1" marker="$2"; CURRENT="$module"
  if sudo -n test -e "$LFS$marker"; then printf '%s already installed; skip.\n' "$module"; return; fi
  local archive="$module-everywhere-src-$VERSION.tar.xz"
  local work="/sources/$module-$VERSION-blfs-$STAMP"
  local source="$work/$module-everywhere-src-$VERSION" build="$work/build" stage="$work/stage" pkglog="$work/package.log"
  local backup="$DATA/backups/$module-$VERSION-before-final-$STAMP"
  fetch "$archive" "https://download.qt.io/official_releases/qt/6.9/$VERSION/submodules/$archive"
  mkdir -p "$backup"; printf '\n--- %s ---\n' "$module"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/usr MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$source" "$build" "$stage" "$pkglog" "$marker" "$module" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; pkglog="$6"; marker="$7"; module="$8"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -pv "$work"; exec > "$pkglog" 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" ]]
if [[ "$module" == qtmultimedia ]]; then
  cmake -S "$source" -B "$build" -D CMAKE_INSTALL_PREFIX=/opt/qt6 -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_BUILD_TYPE=Release -D QT_BUILD_TESTS=OFF -D QT_BUILD_EXAMPLES=OFF -D INPUT_ffmpeg=no -D INPUT_gstreamer=no -D INPUT_pulseaudio=no -D INPUT_pipewire=no -D INPUT_alsa=no > "$work/configure.log" 2>&1 || { tail -n 140 "$work/configure.log"; exit 1; }
else
  cmake -S "$source" -B "$build" -D CMAKE_INSTALL_PREFIX=/opt/qt6 -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_BUILD_TYPE=Release -D QT_BUILD_TESTS=OFF -D QT_BUILD_EXAMPLES=OFF > "$work/configure.log" 2>&1 || { tail -n 140 "$work/configure.log"; exit 1; }
fi
cmake --build "$build" --parallel 4 > "$work/compile.log" 2>&1 || { tail -n 160 "$work/compile.log"; exit 1; }
mkdir -pv "$stage"; DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
[[ -e "$stage$marker" ]] || { echo "Staged marker absent: $marker" >&2; exit 1; }
printf 'QT_MODULE_STAGE=PASS module=%s\n' "$module"
BUILD
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOGDIR/$module-$VERSION-$STAMP.package.log"
  backup_stage "$stage" "$backup"
  if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib /bin/bash -s -- "$build" "$pkglog" "$marker" "$module" <<'INSTALL'
set -Eeuo pipefail
build="$1"; pkglog="$2"; marker="$3"; module="$4"; exec >> "$pkglog" 2>&1
cmake --install "$build"; ldconfig; [[ -e "$marker" ]]
case "$module" in qtmultimedia) [[ -e /opt/qt6/lib/libQt6Multimedia.so ]] ;; qtspeech) [[ -e /opt/qt6/lib/libQt6TextToSpeech.so ]] ;; esac
printf 'QT_MODULE_INSTALL=PASS module=%s\n' "$module"
INSTALL
  then
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOGDIR/$module-$VERSION-$STAMP.package.log"
    sudo -n tail -n 120 "$LFS$pkglog" || true
    printf 'MODULE=%s VERSION=%s RESULT=FAIL BACKUP=%s\n' "$module" "$VERSION" "$backup" > "$LOGDIR/$module-$VERSION.status"
    fail "$module final install failed; backup retained."
  fi
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOGDIR/$module-$VERSION-$STAMP.package.log"
  printf 'MODULE=%s VERSION=%s RESULT=PASS BACKUP=%s\n' "$module" "$VERSION" "$backup" > "$LOGDIR/$module-$VERSION.status"
  printf '%s installed.\n' "$module"
}
build_module qtmultimedia /opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake
build_module qtspeech /opt/qt6/lib/cmake/Qt6TextToSpeech/Qt6TextToSpeechConfig.cmake
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '[[ -f /opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake && -f /opt/qt6/lib/cmake/Qt6TextToSpeech/Qt6TextToSpeechConfig.cmake && -e /opt/qt6/lib/libQt6Multimedia.so && -e /opt/qt6/lib/libQt6TextToSpeech.so ]]'
printf 'QT_MULTIMEDIA_SPEECH_RESULT=PASS\nLOG=%s\nTESTS=SKIPPED\nCHECKSUMS=SKIPPED\nBACKENDS=NONE_EXTERNAL\n' "$LOG" > "$STATUS"
printf 'Qt Multimedia and Qt Speech modules are ready.\nLog: %s\nStatus: %s\n' "$LOG" "$STATUS"
