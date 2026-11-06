#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly VERSION=0.200.0
readonly ARCHIVE="polkit-qt-1-$VERSION.tar.xz"
readonly URL="https://download.kde.org/stable/polkit-qt-1/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/polkit-qt-1-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/polkit-qt-1-$VERSION"
readonly BUILD="$WORK/build"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/polkit-qt-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/polkit-qt-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/polkit-qt-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the expected HDD directory.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX /bin/bash -s <<'POLKIT_QT_PREFLIGHT'
set -Eeuo pipefail
[[ "$(cmake --version | head -n1)" == 'cmake version 4.1.0' ]]
for file in /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake /opt/qt6/lib/cmake/Qt6Core/Qt6CoreConfig.cmake /opt/qt6/lib/cmake/Qt6DBus/Qt6DBusConfig.cmake /opt/qt6/lib/cmake/Qt6Widgets/Qt6WidgetsConfig.cmake; do [[ -f "$file" ]]; done
grep -Fq 'set(PACKAGE_VERSION "6.9.2")' /opt/qt6/lib/cmake/Qt6Core/Qt6CoreConfigVersionImpl.cmake
[[ "$(pkg-config --modversion polkit-agent-1)" == 126 && "$(pkg-config --modversion polkit-gobject-1)" == 126 ]]
[[ -f /usr/lib/cmake/ECM/ECMConfig.cmake || -f /usr/share/ECM/cmake/ECMConfig.cmake ]]
[[ ! -e /usr/lib/cmake/PolkitQt6-1/PolkitQt6-1Config.cmake ]]
POLKIT_QT_PREFLIGHT

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'POLKIT_QT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'POLKIT_QT_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'BLFS 12.4 Polkit-Qt %s; package has no test suite; checksum calculation skipped.\n' "$VERSION"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else
    printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" "$PACKAGE_LOG" <<'POLKIT_QT_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; package_log="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior build tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib POLKIT_SOURCE='$source' POLKIT_BUILD='$build' POLKIT_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
mkdir -pv "$POLKIT_BUILD"
cmake -S "$POLKIT_SOURCE" -B "$POLKIT_BUILD" \
    -D CMAKE_INSTALL_PREFIX=/usr \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_PREFIX_PATH='/opt/qt6;/usr' \
    -D Qt6_DIR=/opt/qt6/lib/cmake/Qt6 \
    -D QT_MAJOR_VERSION=6 \
    -D BUILD_TESTING=OFF \
    -W no-dev > "$POLKIT_BUILD/configure.log" 2>&1 || { tail -n 100 "$POLKIT_BUILD/configure.log"; exit 1; }
cmake --build "$POLKIT_BUILD" --parallel 4 > "$POLKIT_BUILD/compile.log" 2>&1 || { tail -n 120 "$POLKIT_BUILD/compile.log"; exit 1; }
mkdir -pv "$POLKIT_STAGE"
DESTDIR="$POLKIT_STAGE" cmake --install "$POLKIT_BUILD" > "$POLKIT_BUILD/staged-install.log" 2>&1 || { tail -n 100 "$POLKIT_BUILD/staged-install.log"; exit 1; }
[[ -f "$POLKIT_STAGE/usr/lib/cmake/PolkitQt6-1/PolkitQt6-1Config.cmake" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
[[ -n "$(find "$stage" \( -type f -o -type l \) -print -quit)" ]]
printf 'POLKIT_QT_STAGE=PASS\n'
POLKIT_QT_BUILD_STAGE
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/polkit-qt-$VERSION-$STAMP.package.log"

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
    [[ -s "$BACKUP/archive.list" ]] || fail 'Polkit-Qt pre-install backup is empty.'
else
    printf 'No existing Polkit-Qt files required an archive.\n' > "$BACKUP/no-preexisting-files.txt"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
    CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$BUILD" "$PACKAGE_LOG" <<'POLKIT_QT_FINAL_INSTALL'
set -Eeuo pipefail
build="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cmake --install "$build"
ldconfig
[[ -f /usr/lib/cmake/PolkitQt6-1/PolkitQt6-1Config.cmake ]]
for library in libpolkit-qt6-agent-1.so libpolkit-qt6-core-1.so libpolkit-qt6-gui-1.so; do [[ -e "/usr/lib/$library" ]]; done
find /usr/lib -maxdepth 1 -name 'libpolkit-qt6-*.so*' -type f | while read -r library; do ldd "$library" | grep -E 'libQt6[^ ]*[.]so[.]6.*[/]opt/qt6/lib/' >/dev/null; done
! ldd /usr/lib/libpolkit-qt6-core-1.so | grep -F 'not found'
printf 'POLKIT_QT_FINAL_INSTALL=PASS\n'
POLKIT_QT_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/polkit-qt-$VERSION-$STAMP.package.log"
printf 'POLKIT_QT_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' \
    "$LOG" "$LOG_DIR/polkit-qt-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/polkit-qt-$VERSION-$STAMP.package.status"
printf 'Polkit-Qt %s installed. No test suite or checksum calculation was run.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
