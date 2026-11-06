#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=6.17.0
readonly PACKAGE="${ALPBAHOS_D34_PACKAGE:?D34 runner must set ALPBAHOS_D34_PACKAGE}"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly ARCHIVE="$PACKAGE-$VERSION.tar.xz"
readonly WORK="/dev/shm/alpbahos-d34-kf6-$PACKAGE-$VERSION-$STAMP"
readonly SOURCE="$WORK/$PACKAGE-$VERSION" BUILD="$WORK/build" STAGE="$WORK/stage"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/kf6-$PACKAGE-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/kf6-$PACKAGE-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/kf6-$PACKAGE-$VERSION-d34-$STAMP"
readonly URL="https://download.kde.org/stable/frameworks/6.17/$ARCHIVE"

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular host user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
python3 - "$PACKAGE" "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/kf6-d34-package-order.json" <<'PY'
import json,sys
if sys.argv[1] != "breeze-icons" and sys.argv[1] not in json.load(open(sys.argv[2], encoding="utf-8")):
    raise SystemExit("package is not in the approved KF6 D34 order or Breeze Icons prerequisite")
PY
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
    CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr ECM_DIR=/usr/share/ECM/cmake \
    Qt6_DIR=/opt/qt6/lib/cmake/Qt6 Qt6Svg_DIR=/opt/qt6/lib/cmake/Qt6Svg \
    PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:/opt/kf6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig \
    LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib LC_ALL=POSIX \
    /bin/bash -c '[[ "$(cmake --version | sed -n "1s/^cmake version //p")" == 4.1.0 && -f /usr/share/ECM/cmake/ECMConfig.cmake && -f /opt/qt6/lib/cmake/Qt6Svg/Qt6SvgConfig.cmake && -f /opt/qt6/lib/cmake/Qt6Qml/Qt6QmlConfig.cmake ]]' \
    || fail 'KF6 requires CMake 4.1.0, ECM, Qt SVG and Qt QML.'
if [[ "$PACKAGE" == networkmanager-qt ]] && ! sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX pkg-config --exists libnm; then
    fail 'networkmanager-qt requires the D34 libnm development files.'
fi
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another package build is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'KF6_D34_RESULT=PASS\nPACKAGE=%s\nLOG=%s\n' "$PACKAGE" "$LOG" > "$STATUS"; else printf 'KF6_D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

archive_path="$DATA/downloads/$ARCHIVE"
if [[ ! -r "$archive_path" ]]; then
    temp="$archive_path.part-$STAMP"
    curl --fail --location --retry 3 --output "$temp" "$URL"
    mv -- "$temp" "$archive_path"
fi
sudo -n install -o 0 -g 0 -m 0644 "$archive_path" "$LFS/sources/$ARCHIVE"

opts=''
case "$PACKAGE" in
    kdbusaddons|kguiaddons|kidletime|kcrash|kglobalaccel|kjobwidgets|kio|kwallet) opts='-D WITH_X11=OFF' ;;
    kwindowsystem)
        if [[ "${ALPBAHOS_D34_KWINDOWSYSTEM_X11:-0}" == 1 ]]; then
            opts='-D KWINDOWSYSTEM_X11=ON -D KWINDOWSYSTEM_WAYLAND=ON'
        else
            opts='-D KWINDOWSYSTEM_X11=OFF'
        fi
        ;;
    breeze-icons) opts='-D CMAKE_INSTALL_PREFIX=/usr' ;;
esac
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
    CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr ECM_DIR=/usr/share/ECM/cmake \
    Qt6_DIR=/opt/qt6/lib/cmake/Qt6 Qt6LinguistTools_DIR=/opt/qt6/lib/cmake/Qt6LinguistTools \
    Qt6Svg_DIR=/opt/qt6/lib/cmake/Qt6Svg PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:/opt/kf6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig \
    LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j8 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$PACKAGE" "$opts" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; package="$3"; opts="$4"
source="$work/$package-6.17.0"; build="$work/build"; stage="$work/stage"
prefix=/opt/kf6
[[ "$package" != breeze-icons ]] || prefix=/usr
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" ]]
cmake -S "$source" -B "$build" \
    -D CMAKE_INSTALL_PREFIX="$prefix" \
    -D CMAKE_INSTALL_LIBEXECDIR=libexec \
    -D CMAKE_INSTALL_LIBDIR=lib \
    -D CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr \
    -D ECM_DIR=/usr/share/ECM/cmake \
    -D Qt6_DIR=/opt/qt6/lib/cmake/Qt6 \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF \
    -D BUILD_PYTHON_BINDINGS=OFF \
    $opts -W no-dev > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
cmake --build "$build" --parallel 8 > "$work/compile.log" 2>&1 || { tail -n 140 "$work/compile.log"; exit 1; }
mkdir -p "$stage"
DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1 || { tail -n 100 "$work/staged-install.log"; exit 1; }
[[ -s "$build/install_manifest.txt" ]]
grep -q "^$prefix/" "$build/install_manifest.txt"
find "$stage$prefix" -mindepth 1 -print -quit | grep -q .
BUILD

sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" "$PACKAGE" "$ALPBAHOS_D34_CANDIDATE_PATH" "${ALPBAHOS_D34_KWINDOWSYSTEM_X11:-0}" <<'PY'
import json,os,sys
root,src,dst,package,candidate,x11_overlay=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in collisions))
print(f"KF6 staged paths={len(paths)} collisions={len(collisions)}")
if collisions:
    if package != "kwindowsystem" or x11_overlay != "1":
        raise SystemExit("Refusing to overwrite existing candidate paths")
    ledger_path=os.path.join(os.path.dirname(candidate),"d34-ownership-ledger.json")
    ledger=json.load(open(ledger_path,encoding="utf-8"))
    if ledger.get("result") != "COMPLETE":
        raise SystemExit("Refusing KWindowSystem overlay without a COMPLETE ownership ledger")
    owners=ledger.get("final_system_path_owners",{})
    wrong=[os.fsdecode(p) for p in collisions if owners.get(os.fsdecode(p)) != "kwindowsystem"]
    if wrong:
        raise SystemExit("Refusing KWindowSystem X11 overlay; collisions not owned by kwindowsystem: "+repr(wrong[:12]))
    print(f"KWindowSystem X11 overlay may replace {len(collisions)} package-owned paths")
PY
if [[ -s "$BACKUP/existing.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-kwindowsystem-files.tar" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$BACKUP/existing.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-kwindowsystem-files.tar"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
    CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr ECM_DIR=/usr/share/ECM/cmake \
    Qt6_DIR=/opt/qt6/lib/cmake/Qt6 Qt6Svg_DIR=/opt/qt6/lib/cmake/Qt6Svg \
    LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib LC_ALL=POSIX \
    /bin/bash -s -- "$BUILD" <<'INSTALL'
set -Eeuo pipefail
cmake --install "$1"
[[ -s "$1/install_manifest.txt" ]]
while IFS= read -r path; do [[ -e "$path" || -L "$path" ]] || { echo "Missing installed path: $path" >&2; exit 1; }; done < "$1/install_manifest.txt"
INSTALL
printf 'KF6_D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$STATUS"
