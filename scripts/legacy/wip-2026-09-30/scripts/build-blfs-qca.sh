#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=2.3.10
readonly ARCHIVE="qca-$VERSION.tar.xz"
readonly URL="https://download.kde.org/stable/qca/$VERSION/$ARCHIVE"
readonly WORK="/sources/qca-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/qca-$VERSION"
readonly BUILD="$WORK/build"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qca-$VERSION-blfs-$STAMP.log"
readonly STATUS="$LOG_DIR/qca-$VERSION-blfs-$STAMP.status"
readonly BACKUP="$DATA/backups/qca-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'Another package build or test process is active.'; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -ec '
      [[ "$(cmake --version | head -n1)" == "cmake version 4.1.0" ]]
      [[ -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake ]]
      [[ -f /opt/qt6/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfig.cmake ]]
      grep -Fq "set(PACKAGE_VERSION \"6.9.2\")" /opt/qt6/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfigVersionImpl.cmake
      [[ "$(which --version | head -n1)" == *"GNU which v2.23"* ]]
      [[ "$(/usr/sbin/make-ca --version | head -n1)" == *"make-ca 1.16.1"* ]]
      [[ -s /etc/pki/tls/certs/ca-bundle.crt ]]
      [[ -f /usr/lib/pkgconfig/p11-kit-1.pc && -f /usr/lib/pkgconfig/libgcrypt.pc ]]
      [[ -f /usr/lib/libssl.so && -f /usr/lib/libcrypto.so ]]
      [[ ! -f /opt/qt6/lib/cmake/Qca-qt6/Qca-qt6Config.cmake ]]
    ' || fail 'QCA prerequisites are missing or QCA is already installed.'

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_QCA_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'BLFS_QCA_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'Building BLFS 12.4 QCA %s against the alpbahOS Qt 6.9.2 prefix. Package tests and source checksums are skipped.\n' "$VERSION"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    temporary="$DATA/downloads/$ARCHIVE.partial-$STAMP"
    curl --fail --location --retry 3 --output "$temporary" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$temporary" "$ARCHIVE_PATH"
fi
[[ ! -e "$LFS$WORK" ]] || fail "Refusing to overwrite existing isolated work tree $WORK"

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" "$PACKAGE_LOG" <<'BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; package_log="$6"
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" ]]
cp -p "$source/CMakeLists.txt" "$work/CMakeLists.txt.upstream"
sed -i 's@cert.pem@certs/ca-bundle.crt@' "$source/CMakeLists.txt"
grep -Fq 'certs/ca-bundle.crt' "$source/CMakeLists.txt"
cmake -S "$source" -B "$build" \
  -D CMAKE_INSTALL_PREFIX=/opt/qt6 \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_PREFIX_PATH='/opt/qt6;/usr' \
  -D Qt6_DIR=/opt/qt6/lib/cmake/Qt6 \
  -D QT6=ON \
  -D BUILD_TESTS=OFF \
  -D BUILD_TOOLS=ON \
  -D QCA_INSTALL_IN_QT_PREFIX=ON \
  -D QCA_MAN_INSTALL_DIR:PATH=/usr/share/man > "$work/configure.log" 2>&1
if cmake --build "$build" --parallel 4 > "$work/compile.log" 2>&1; then printf 'QCA_BUILD=PASS\n'; else rc=$?; tail -n 120 "$work/compile.log"; exit "$rc"; fi
mkdir -pv "$stage"
DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1
[[ -f "$stage/opt/qt6/lib/cmake/Qca-qt6/Qca-qt6Config.cmake" ]]
[[ -x "$stage/opt/qt6/bin/qcatool-qt6" && -x "$stage/opt/qt6/bin/mozcerts-qt6" ]]
find "$stage/opt/qt6/lib" -maxdepth 1 -name 'libqca-qt6.so*' -type f | grep -q .
printf 'QCA_STAGED_INSTALL=PASS\n'
find "$stage/opt/qt6/plugins/crypto" -maxdepth 1 -type f -name 'libqca-*.so*' -printf '%f\n' | sort > "$work/staged-qca-providers.txt"
[[ -s "$work/staged-qca-providers.txt" ]]
BUILD_STAGE
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/qca-$VERSION-blfs-$STAMP.package.log"

sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged-paths.list0"
python3 - "$LFS" "$BACKUP/staged-paths.list0" "$BACKUP/preexisting-paths.list0" <<'PY'
import os, sys
root, staged_path, existing_path = sys.argv[1:]
with open(staged_path, 'rb') as stream:
    staged = [path for path in stream.read().split(b'\0') if path]
existing = []
for raw in staged:
    relative = os.fsdecode(raw)
    if os.path.isabs(relative) or '..' in relative.split('/'):
        raise SystemExit(f'Unsafe staged path: {relative!r}')
    if os.path.lexists(os.path.join(root, relative)):
        existing.append(raw)
with open(existing_path, 'wb') as stream:
    for raw in sorted(set(existing)):
        stream.write(raw + b'\0')
print(f'Staged paths: {len(staged)}; pre-existing targets: {len(set(existing))}')
PY
if [[ -s "$BACKUP/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/preexisting-files.list"
    [[ -s "$BACKUP/preexisting-files.list" ]] || fail 'QCA pre-install archive is empty.'
else
    printf 'No pre-existing QCA targets required backup.\n' > "$BACKUP/no-preexisting-files.txt"
fi

if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$BUILD" "$PACKAGE_LOG" <<'FINAL_INSTALL'
set -Eeuo pipefail
build="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cmake --install "$build"
ldconfig
[[ -f /opt/qt6/lib/cmake/Qca-qt6/Qca-qt6Config.cmake ]]
grep -Fq 'set(PACKAGE_VERSION "2.3.10")' /opt/qt6/lib/cmake/Qca-qt6/Qca-qt6ConfigVersion.cmake
[[ -x /opt/qt6/bin/qcatool-qt6 && -x /opt/qt6/bin/mozcerts-qt6 ]]
find /opt/qt6/lib -maxdepth 1 -type f -name 'libqca-qt6.so*' | grep -q .
[[ -d /opt/qt6/plugins/crypto ]]
readelf -h /opt/qt6/bin/qcatool-qt6 | grep -F 'Advanced Micro Devices X86-64'
ldd /opt/qt6/bin/qcatool-qt6 | grep -E 'libQt6Core[.]so[.]6.*/opt/qt6/lib/'
readelf -h /opt/qt6/lib/libqca-qt6.so | grep -F 'Advanced Micro Devices X86-64'
printf 'QCA_FINAL_INSTALL=PASS\n'
printf 'QCA_PROVIDER_LIBRARIES:\n'
find /opt/qt6/plugins/crypto -maxdepth 1 -type f -name 'libqca-*.so*' -printf '%f\n' | sort
FINAL_INSTALL
then
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/qca-$VERSION-blfs-$STAMP.package.log"
    fail 'QCA final install or static verification failed.'
fi
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/qca-$VERSION-blfs-$STAMP.package.log"
printf 'BLFS_QCA_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\nTESTS=SKIPPED\nCHECKSUMS=SKIPPED\n' \
    "$LOG" "$LOG_DIR/qca-$VERSION-blfs-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$STATUS"
printf 'QCA %s installed. Tests/checksums skipped.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
