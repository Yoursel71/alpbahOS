#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=6.9.2
readonly ARCHIVE="qtbase-everywhere-src-$VERSION.tar.xz" STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/qtbase-$VERSION-d34-$STAMP"
readonly SOURCE="$WORK/qtbase-everywhere-src-$VERSION"
readonly BUILD="$WORK/build" STAGE="$WORK/stage"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qtbase-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/qtbase-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/qtbase-$VERSION-d34-$STAMP"
readonly URL="https://download.qt.io/archive/qt/6.9/6.9.2/submodules/$ARCHIVE"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as regular user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"; sudo -n true || fail 'Non-interactive sudo unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v cmake >/dev/null && command -v ninja >/dev/null && pkg-config --exists freetype2 harfbuzz fontconfig libpng16 dbus-1 openssl sqlite3 && test ! -e /opt/qt6/lib/libQt6Core.so.6'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then fail 'Another build process is active.'; fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"; exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'QTBASE_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'QTBASE_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
  if [[ -r "$DATA/downloads/$ARCHIVE" ]]; then sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$ARCHIVE_PATH"
  else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; mv "$DATA/downloads/$ARCHIVE.part-$STAMP" "$DATA/downloads/$ARCHIVE"; fi
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/qtbase-everywhere-src-6.9.2"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -x "$source/configure" ]]
mkdir -p "$build"; cd "$build"
"$source/configure" -opensource -confirm-license -prefix /opt/qt6 -sysconfdir /etc/xdg \
  -dbus-linked -openssl-linked -system-sqlite -journald -nomake examples -no-rpath -no-sbom -no-xcb \
  > "$work/configure.log" 2>&1 || { tail -n 160 "$work/configure.log"; exit 1; }
ninja -j8 > "$work/compile.log" 2>&1 || { tail -n 180 "$work/compile.log"; exit 1; }
mkdir -p "$stage"; DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1
[[ -x "$stage/opt/qt6/bin/qmake6" && -f "$stage/opt/qt6/lib/libQt6Core.so.6" && -f "$stage/opt/qt6/lib/libQt6Gui.so.6" && -f "$stage/opt/qt6/lib/libQt6DBus.so.6" ]]
mkdir -p "$stage/etc/ld.so.conf.d" "$stage/etc/profile.d"
printf '/opt/qt6/lib\n' > "$stage/etc/ld.so.conf.d/qt6.conf"
cat > "$stage/etc/profile.d/qt6.sh" <<'EOF'
QT6DIR=/opt/qt6
export QT6DIR
PATH="$QT6DIR/bin:$PATH"
PKG_CONFIG_PATH="$QT6DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PATH PKG_CONFIG_PATH
EOF
BUILD
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]; paths=[p for p in open(src,'rb').read().split(b'\0') if p]; collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in collisions)); print(f'QtBase staged paths: {len(paths)}; collisions: {len(collisions)}')
if collisions: raise SystemExit('Refusing to overwrite existing candidate paths')
PY
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$STAGE" <<'INSTALL'
set -Eeuo pipefail
cp -a "$1/." /
ldconfig
[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -f /opt/qt6/lib/libQt6Core.so.6 && -f /opt/qt6/lib/libQt6Gui.so.6 && -f /opt/qt6/lib/libQt6DBus.so.6 && -f /opt/qt6/lib/libQt6Sql.so.6 ]]
printf 'QtBase install verified: %s\n' "$(qmake6 -query QT_VERSION)"
INSTALL
printf 'QTBASE_RESULT=PASS\nLOG=%s\nVERSION=%s\n' "$LOG" "$VERSION" > "$STATUS"
