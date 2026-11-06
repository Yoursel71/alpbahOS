#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=6.9.2
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')" LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qt-svg-tools-$VERSION-$STAMP.log" STATUS="$LOG_DIR/qt-svg-tools-$VERSION-$STAMP.status"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" && "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]]
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]]
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]]
sudo -n true
if ps -eo comm= | awk '$1=="make"||$1=="ninja"||$1=="expect"||$1=="runtest"{f=1} END{exit f?0:1}'; then fail 'Another build/test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '
  [[ "$(cmake --version | head -n1)" == "cmake version 4.1.0" ]]
  [[ -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake ]]
'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads"
exec 9>"$DATA/locks/lfs-build-writer.lock"; flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if ((rc==0)); then printf 'QT_SVG_TOOLS_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'QT_SVG_TOOLS_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
printf 'Build QtSvg and QtTools %s; package suites and source checksum calculations skipped.\n' "$VERSION"

fetch() {
  local archive="$1" url="$2" tmp="$DATA/downloads/$1.partial-$STAMP"
  if ! sudo -n test -r "$LFS/sources/$archive"; then
    curl --fail --location --retry 3 --output "$tmp" "$url"
    sudo -n install -o 0 -g 0 -m 0644 "$tmp" "$LFS/sources/$archive"
  else printf 'Using existing source: %s\n' "$LFS/sources/$archive"; fi
}
build_module() {
  local module="$1" marker="$2" name="$3"
  if sudo -n test -e "$LFS$marker"; then
    printf 'Skipping %s: installed marker exists.\n' "$module"; return
  fi
  local archive="$module-everywhere-src-$VERSION.tar.xz"
  local url="https://download.qt.io/official_releases/qt/6.9/6.9.2/submodules/$archive"
  local work="/sources/$module-$VERSION-blfs-$STAMP"
  local source="/sources/$module-$VERSION-blfs-$STAMP/$module-everywhere-src-$VERSION"
  local build="/sources/$module-$VERSION-blfs-$STAMP/build"
  local stage="/sources/$module-$VERSION-blfs-$STAMP/stage"
  local pkglog="/sources/$module-$VERSION-blfs-$STAMP/package.log"
  local backup="$DATA/backups/$module-$VERSION-before-final-$STAMP"
  fetch "$archive" "$url"; mkdir -p "$backup"
  printf '\n--- %s %s ---\n' "$module" "$VERSION"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/usr MAKEFLAGS=-j4 \
    /bin/bash -s -- "$archive" "$work" "$source" "$build" "$stage" "$pkglog" "$marker" "$module" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; pkglog="$6"; marker="$7"; module="$8"
[[ ! -e "$work" ]] || { printf 'Refusing existing build tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > "$pkglog" 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" ]]
cmake -S "$source" -B "$build" \
  -D CMAKE_INSTALL_PREFIX=/opt/qt6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_BUILD_TYPE=Release \
  -D QT_BUILD_TESTS=OFF \
  -D QT_BUILD_EXAMPLES=OFF > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
cmake --build "$build" --parallel 4 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -pv "$stage"
DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
[[ -e "$stage$marker" ]] || { printf 'Staged marker absent: %s\n' "$stage$marker" >&2; exit 1; }
printf 'QT_MODULE_STAGE=PASS module=%s\n' "$module"
BUILD
  if ! sudo -n test -s "$LFS$pkglog"; then fail "Missing package log for $module"; fi
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOG_DIR/$module-$VERSION-blfs-$STAMP.package.log"
  sudo -n find "$LFS$stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$backup/staged-paths.list0"
  python3 - "$LFS" "$backup/staged-paths.list0" "$backup/preexisting-paths.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
with open(src,'rb') as f: paths=[p for p in f.read().split(b'\0') if p]
existing=[]
for p in paths:
 r=os.fsdecode(p)
 if os.path.isabs(r) or '..' in r.split('/'): raise SystemExit('Unsafe path: '+r)
 if os.path.lexists(os.path.join(root,r)): existing.append(p)
with open(dst,'wb') as f:
 for p in sorted(set(existing)): f.write(p+b'\0')
print(f'Staged paths: {len(paths)}; existing targets: {len(set(existing))}')
PY
  if [[ -s "$backup/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$backup/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$backup/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$backup/preexisting-files.tar"
    sudo -n tar --list -f "$backup/preexisting-files.tar" > "$backup/preexisting-files.list"
    [[ -s "$backup/preexisting-files.list" ]] || fail "Empty $module backup."
  else printf 'No pre-existing paths required backup.\n' > "$backup/no-preexisting-files.txt"; fi
  if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib \
    /bin/bash -s -- "$build" "$pkglog" "$marker" "$module" <<'INSTALL'
set -Eeuo pipefail
build="$1"; pkglog="$2"; marker="$3"; module="$4"
exec >> "$pkglog" 2>&1
cmake --install "$build"
ldconfig
[[ -e "$marker" ]]
if [[ "$module" == qtsvg ]]; then
  [[ -e /opt/qt6/lib/libQt6Svg.so ]]
  readelf -h /opt/qt6/lib/libQt6Svg.so | grep -F 'Advanced Micro Devices X86-64'
else
  [[ -f /opt/qt6/bin/lrelease && -f /opt/qt6/bin/lupdate ]]
  /opt/qt6/bin/lrelease -version | grep -Fq '6.9.2'
fi
printf 'QT_MODULE_INSTALL=PASS module=%s\n' "$module"
INSTALL
  then
    sudo -n tail -n 120 "$LFS$pkglog" || true
    printf 'PACKAGE=%s VERSION=%s RESULT=FAIL LOG=%s\n' "$module" "$VERSION" "$LOG_DIR/$module-$VERSION-blfs-$STAMP.package.log" > "$LOG_DIR/$module-$VERSION.status"
    fail "$module final install failed; staged build and pre-install backup were retained."
  fi
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOG_DIR/$module-$VERSION-blfs-$STAMP.package.log"
  printf 'PACKAGE=%s VERSION=%s RESULT=PASS LOG=%s BACKUP=%s\n' "$module" "$VERSION" "$LOG_DIR/$module-$VERSION-blfs-$STAMP.package.log" "$backup" > "$LOG_DIR/$module-$VERSION.status"
  printf '%s install passed; backup: %s\n' "$module" "$backup"
}
build_module qtsvg /opt/qt6/lib/cmake/Qt6Svg/Qt6SvgConfig.cmake QtSvg
build_module qttools /opt/qt6/lib/cmake/Qt6LinguistTools/Qt6LinguistToolsConfig.cmake QtTools
printf 'QT_SVG_TOOLS_RESULT=PASS\nLOG=%s\nTESTS=SKIPPED\nCHECKSUMS=SKIPPED\n' "$LOG" > "$STATUS"
printf 'QtSvg and QtTools are ready for KF6.\nLog: %s\nStatus: %s\n' "$LOG" "$STATUS"

