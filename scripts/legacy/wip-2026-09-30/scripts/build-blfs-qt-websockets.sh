#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly VERSION=6.9.2
readonly ARCHIVE="qtwebsockets-everywhere-src-$VERSION.tar.xz"
readonly URL="https://download.qt.io/official_releases/qt/6.9/6.9.2/submodules/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/qtwebsockets-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/qtwebsockets-everywhere-src-$VERSION"
readonly BUILD="$WORK/build"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qtwebsockets-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/qtwebsockets-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/qtwebsockets-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/qt/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the expected HDD directory.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX /bin/bash -c '
    [[ "$(qmake6 -query QT_VERSION)" == 6.9.2 ]]
    [[ -x /opt/qt6/bin/qt-configure-module && -x /usr/bin/ninja ]]
    [[ -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake && -f /opt/qt6/lib/cmake/Qt6Network/Qt6NetworkConfig.cmake ]]
    [[ ! -e /opt/qt6/lib/cmake/Qt6WebSockets/Qt6WebSocketsConfig.cmake ]]
' || fail 'Qt 6.9.2 WebSockets prerequisites are missing or the module already exists.'

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$LFS/sources/qt" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'QT_WEBSOCKETS_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'QT_WEBSOCKETS_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'Building Qt WebSockets %s against the installed /opt/qt6 profile; package test suites and checksum calculations skipped.\n' "$VERSION"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 CMAKE_PREFIX_PATH=/opt/qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" "$PACKAGE_LOG" <<'QT_WEBSOCKETS_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; package_log="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/qt/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" && "$(qmake6 -query QT_VERSION)" == 6.9.2 ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 CMAKE_PREFIX_PATH=/opt/qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib QT_MODULE_SOURCE='$source' QT_MODULE_BUILD='$build' QT_MODULE_STAGE='$stage' QT_MODULE_WORK='$work' /bin/bash -s" <<'UNPRIVILEGED_QT_BUILD'
set -Eeuo pipefail
mkdir -pv "$QT_MODULE_BUILD"
cd "$QT_MODULE_BUILD"
qt-configure-module "$QT_MODULE_SOURCE" > "$QT_MODULE_WORK/configure.log" 2>&1 || { tail -n 140 "$QT_MODULE_WORK/configure.log"; exit 1; }
ninja -j4 > "$QT_MODULE_WORK/compile.log" 2>&1 || { tail -n 160 "$QT_MODULE_WORK/compile.log"; exit 1; }
mkdir -pv "$QT_MODULE_STAGE"
DESTDIR="$QT_MODULE_STAGE" cmake --install . > "$QT_MODULE_WORK/staged-install.log" 2>&1 || { tail -n 120 "$QT_MODULE_WORK/staged-install.log"; exit 1; }
[[ -e "$QT_MODULE_STAGE/opt/qt6/lib/libQt6WebSockets.so.6" ]]
[[ -f "$QT_MODULE_STAGE/opt/qt6/lib/cmake/Qt6WebSockets/Qt6WebSocketsConfig.cmake" ]]
UNPRIVILEGED_QT_BUILD
chown -R 0:0 "$stage"
printf 'QT_WEBSOCKETS_STAGE=PASS\n'
QT_WEBSOCKETS_STAGE

sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/qtwebsockets-$VERSION-$STAMP.package.log"
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged-paths.list0"
python3 - "$LFS" "$BACKUP/staged-paths.list0" "$BACKUP/preexisting-paths.list0" <<'PY'
import os, sys
root, staged, out = sys.argv[1:]
with open(staged, 'rb') as stream: paths = [p for p in stream.read().split(b'\0') if p]
old = []
for raw in paths:
    rel = os.fsdecode(raw)
    if os.path.isabs(rel) or '..' in rel.split('/'): raise SystemExit(f'Unsafe path: {rel!r}')
    if os.path.lexists(os.path.join(root, rel)): old.append(raw)
with open(out, 'wb') as stream:
    for raw in sorted(set(old)): stream.write(raw + b'\0')
print(f'Staged paths: {len(paths)}; existing target paths: {len(set(old))}')
PY
if [[ -s "$BACKUP/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
    [[ -s "$BACKUP/archive.list" ]] || fail 'Qt WebSockets pre-install backup is empty.'
else printf 'No existing Qt WebSockets targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX \
    /bin/bash -s -- "$BUILD" "$PACKAGE_LOG" <<'QT_WEBSOCKETS_INSTALL'
set -Eeuo pipefail
build="$1"; package_log="$2"
exec >> "$package_log" 2>&1
cmake --install "$build"
ldconfig
[[ -f /opt/qt6/lib/cmake/Qt6WebSockets/Qt6WebSocketsConfig.cmake ]]
[[ -e /opt/qt6/lib/libQt6WebSockets.so.6 ]]
readelf -h /opt/qt6/lib/libQt6WebSockets.so.6 | grep -F 'Advanced Micro Devices X86-64'
ldd_output="$(ldd /opt/qt6/lib/libQt6WebSockets.so.6)"
printf '%s\n' "$ldd_output"
[[ "$ldd_output" != *'not found'* && "$ldd_output" != *'/sources/'* ]]
printf 'QT_WEBSOCKETS_INSTALL=PASS\n'
QT_WEBSOCKETS_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/qtwebsockets-$VERSION-$STAMP.package.log"
printf 'QT_WEBSOCKETS_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LOG_DIR/qtwebsockets-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/qtwebsockets-$VERSION-$STAMP.package.status"
printf 'Qt WebSockets %s installed; no package test suite or checksum calculation was run.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
