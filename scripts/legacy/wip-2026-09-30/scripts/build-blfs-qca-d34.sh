#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=2.3.10 ARCHIVE=qca-2.3.10.tar.xz
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-qca-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qca-qt6-d34-$STAMP.log" BACKUP="$DATA/backups/qca-qt6-d34-$STAMP"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"; sudo -n true || fail 'Non-interactive sudo unavailable.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"; exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=qca-qt6\nVERSION=%s\nLOG=%s\n' "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=qca-qt6 exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 CMAKE_PREFIX_PATH='/opt/qt6;/usr' LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j4 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" "$VERSION" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; version="$3"; source="$work/qca-$version"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -f "$source/CMakeLists.txt" ]]
cp -p "$source/CMakeLists.txt" "$work/CMakeLists.txt.upstream"
sed -i 's@cert.pem@certs/ca-bundle.crt@' "$source/CMakeLists.txt"
grep -Fq 'certs/ca-bundle.crt' "$source/CMakeLists.txt"
cmake -S "$source" -B "$build" -D CMAKE_INSTALL_PREFIX=/opt/qt6 -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_PREFIX_PATH='/opt/qt6;/usr' -D Qt6_DIR=/opt/qt6/lib/cmake/Qt6 -D QT6=ON -D BUILD_TESTS=OFF -D BUILD_TOOLS=ON \
  -D QCA_INSTALL_IN_QT_PREFIX=ON -D QCA_MAN_INSTALL_DIR:PATH=/usr/share/man > "$work/configure.log" 2>&1 || { tail -n 140 "$work/configure.log"; exit 1; }
cmake --build "$build" --parallel 4 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -p "$stage"; DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1 || { tail -n 100 "$work/staged-install.log"; exit 1; }
[[ -f "$stage/opt/qt6/lib/cmake/Qca-qt6/Qca-qt6Config.cmake" && -x "$stage/opt/qt6/bin/qcatool-qt6" && -x "$stage/opt/qt6/bin/mozcerts-qt6" ]]
find "$stage/opt/qt6/lib" -maxdepth 1 -name 'libqca-qt6.so*' -type f | grep -q .
[[ -d "$stage/opt/qt6/plugins/crypto" ]]
BUILD
sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'MANIFEST'
import os,sys
root,src,dst=sys.argv[1:]; paths=[p for p in open(src,'rb').read().split(b'\0') if p]
existing=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in existing))
print(f'QCA staged paths={len(paths)} existing targets={len(existing)}')
if existing: raise SystemExit(f'Refusing existing QCA targets: {existing[:12]!r}')
MANIFEST
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH='/opt/qt6;/usr' LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX \
  /bin/bash -s -- "$WORK/build" "$VERSION" <<'INSTALL'
set -Eeuo pipefail
build="$1"; version="$2"; cmake --install "$build"; ldconfig
[[ -f /opt/qt6/lib/cmake/Qca-qt6/Qca-qt6Config.cmake ]]
grep -Fq "set(PACKAGE_VERSION \"$version\")" /opt/qt6/lib/cmake/Qca-qt6/Qca-qt6ConfigVersion.cmake
[[ -x /opt/qt6/bin/qcatool-qt6 && -x /opt/qt6/bin/mozcerts-qt6 && -d /opt/qt6/plugins/crypto ]]
find /opt/qt6/lib -maxdepth 1 -type f -name 'libqca-qt6.so*' | grep -q .
INSTALL
printf 'D34_RESULT=PASS PACKAGE=qca-qt6 VERSION=%s LOG=%s\n' "$VERSION" "$LOG"
