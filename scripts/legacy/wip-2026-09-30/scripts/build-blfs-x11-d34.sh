#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly PACKAGE="${ALPBAHOS_D34_PACKAGE:?D34 runner must set ALPBAHOS_D34_PACKAGE}"
case "$PACKAGE" in
  xtrans) VERSION=1.6.0; ARCHIVE="xtrans-$VERSION.tar.xz"; SOURCE="xtrans-$VERSION" ;;
  libX11) VERSION=1.8.12; ARCHIVE="libX11-$VERSION.tar.xz"; SOURCE="libX11-$VERSION" ;;
  xcb-util-keysyms) VERSION=0.4.1; ARCHIVE="xcb-util-keysyms-$VERSION.tar.xz"; SOURCE="xcb-util-keysyms-$VERSION" ;;
  xcb-util-wm) VERSION=0.4.2; ARCHIVE="xcb-util-wm-$VERSION.tar.xz"; SOURCE="xcb-util-wm-$VERSION" ;;
  libXfixes) VERSION=6.0.1; ARCHIVE="libXfixes-$VERSION.tar.xz"; SOURCE="libXfixes-$VERSION" ;;
  libXcursor) VERSION=1.2.3; ARCHIVE="libXcursor-$VERSION.tar.xz"; SOURCE="libXcursor-$VERSION" ;;
  libxkbfile) VERSION=1.1.3; ARCHIVE="libxkbfile-$VERSION.tar.xz"; SOURCE="libxkbfile-$VERSION" ;;
  libXrender) VERSION=0.9.12; ARCHIVE="libXrender-$VERSION.tar.xz"; SOURCE="libXrender-$VERSION" ;;
  xcb-util) VERSION=0.4.1; ARCHIVE="xcb-util-$VERSION.tar.xz"; SOURCE="xcb-util-$VERSION" ;;
  xcb-util-image) VERSION=0.4.1; ARCHIVE="xcb-util-image-$VERSION.tar.xz"; SOURCE="xcb-util-image-$VERSION" ;;
  xcb-util-renderutil) VERSION=0.3.10; ARCHIVE="xcb-util-renderutil-$VERSION.tar.xz"; SOURCE="xcb-util-renderutil-$VERSION" ;;
  xcb-util-cursor) VERSION=0.1.6; ARCHIVE="xcb-util-cursor-$VERSION.tar.xz"; SOURCE="xcb-util-cursor-$VERSION" ;;
  *) echo "Unsupported X11 D34 package: $PACKAGE" >&2; exit 2 ;;
esac
readonly VERSION ARCHIVE SOURCE STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-$PACKAGE-$VERSION-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/$PACKAGE-$VERSION-d34-$STAMP.log"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
printf 'D34 X11 builder starting: package=%s version=%s\n' "$PACKAGE" "$VERSION"
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the private D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"; sudo -n true || fail 'Non-interactive sudo unavailable.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/downloads"
lfs_acquire_writer_lock "$DATA"; exec > >(tee "$LOG") 2>&1
printf 'D34 target verified; source archive=%s\n' "$ARCHIVE"

readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
  if [[ ! -r "$DATA/downloads/$ARCHIVE" ]]; then
    case "$PACKAGE" in
      xcb-util-keysyms|xcb-util-wm|libXfixes|libXrender|libXcursor|libxkbfile|xcb-util|xcb-util-image|xcb-util-renderutil|xcb-util-cursor) URL="https://xorg.freedesktop.org/archive/individual/lib/$ARCHIVE" ;;
      *) fail "Source archive is missing: $ARCHIVE" ;;
    esac
    curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"
    mv "$DATA/downloads/$ARCHIVE.part-$STAMP" "$DATA/downloads/$ARCHIVE"
  fi
  sudo -n install -D -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$ARCHIVE_PATH"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
  MAKEFLAGS=-j6 LC_ALL=POSIX /bin/bash -s -- "$PACKAGE" "$ARCHIVE" "$SOURCE" "$WORK" <<'BUILD'
set -Eeuo pipefail
package="$1"; archive="$2"; source_name="$3"; work="$4"
source="$work/$source_name"; stage="$work/stage"
printf 'Extracting %s and configuring %s\n' "$archive" "$package"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -d "$source" ]]
cd "$source"
case "$package" in
  xtrans)
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var > "$work/configure.log" 2>&1 || { tail -n 100 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 100 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 100 "$work/staged-install.log"; exit 1; }
    find "$stage/usr/include/X11" -maxdepth 2 -type d -print
    [[ -d "$stage/usr/include/X11/Xtrans" ]]
    ;;
  libX11)
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --disable-static --enable-shared > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    [[ -e "$stage/usr/lib/libX11.so.6" && -f "$stage/usr/include/X11/Xlib.h" ]]
    ;;
  xcb-util-keysyms)
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --disable-static --enable-shared > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    [[ -e "$stage/usr/lib/libxcb-keysyms.so.1" && -f "$stage/usr/include/xcb/xcb_keysyms.h" ]]
    ;;
  xcb-util-wm)
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --disable-static --enable-shared > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    [[ -e "$stage/usr/lib/libxcb-ewmh.so.2" && -e "$stage/usr/lib/libxcb-icccm.so.4" ]]
    [[ -f "$stage/usr/include/xcb/xcb_ewmh.h" && -f "$stage/usr/include/xcb/xcb_icccm.h" ]]
    ;;
  libXfixes)
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --disable-static --enable-shared > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    [[ -e "$stage/usr/lib/libXfixes.so.3" && -f "$stage/usr/include/X11/extensions/Xfixes.h" ]]
    ;;
  libXrender)
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --disable-static --enable-shared > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    [[ -e "$stage/usr/lib/libXrender.so.1" && -f "$stage/usr/include/X11/extensions/Xrender.h" ]]
    ;;
  libXcursor)
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --disable-static --enable-shared > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    [[ -e "$stage/usr/lib/libXcursor.so.1" && -f "$stage/usr/include/X11/Xcursor/Xcursor.h" ]]
    ;;
  libxkbfile)
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --disable-static --enable-shared > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    [[ -e "$stage/usr/lib/libxkbfile.so.1" && -f "$stage/usr/include/X11/extensions/XKBfile.h" ]]
    ;;
  xcb-util)
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --disable-static --enable-shared > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    [[ -e "$stage/usr/lib/libxcb-util.so.1" && -f "$stage/usr/include/xcb/xcb_aux.h" ]]
    ;;
  xcb-util-image|xcb-util-renderutil)
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --disable-static --enable-shared > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    if [[ "$package" == xcb-util-image ]]; then
      [[ -e "$stage/usr/lib/libxcb-image.so.0" && -f "$stage/usr/include/xcb/xcb_image.h" ]]
    else
      [[ -e "$stage/usr/lib/libxcb-render-util.so.0" && -f "$stage/usr/include/xcb/xcb_renderutil.h" ]]
    fi
    ;;
  xcb-util-cursor)
    ./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --disable-static --enable-shared > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    make -j6 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
    make DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    [[ -e "$stage/usr/lib/libxcb-cursor.so.0" && -f "$stage/usr/include/xcb/xcb_cursor.h" ]]
    ;;
esac
    find "$stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$work/staged.list0"
printf 'X11 staged manifest prepared.\n'
BUILD

python3 - "$LFS" "$LFS$WORK/staged.list0" <<'PY'
import os,sys
root,manifest=sys.argv[1:]
paths=[p for p in open(manifest,'rb').read().split(b'\0') if p]
collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
print(f'X11 staged paths: {len(paths)}; existing candidate paths: {len(collisions)}')
if collisions: raise SystemExit('Refusing to overwrite existing candidate paths: '+repr([os.fsdecode(p) for p in collisions[:20]]))
PY
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH=/usr/lib LC_ALL=POSIX \
  /bin/bash -s -- "$WORK" "$PACKAGE" <<'INSTALL'
set -Eeuo pipefail
work="$1"; package="$2"
cp -a "$work/stage"/. /
ldconfig
case "$package" in
  xtrans) test -d /usr/include/X11/Xtrans ;;
  libX11) test -e /usr/lib/libX11.so.6 && test -f /usr/include/X11/Xlib.h ;;
  xcb-util-keysyms) test -e /usr/lib/libxcb-keysyms.so.1 && test -f /usr/include/xcb/xcb_keysyms.h ;;
  xcb-util-wm) test -e /usr/lib/libxcb-ewmh.so.2 && test -e /usr/lib/libxcb-icccm.so.4 ;;
  libXfixes) test -e /usr/lib/libXfixes.so.3 && test -f /usr/include/X11/extensions/Xfixes.h ;;
  libXrender) test -e /usr/lib/libXrender.so.1 && test -f /usr/include/X11/extensions/Xrender.h ;;
  libXcursor) test -e /usr/lib/libXcursor.so.1 && test -f /usr/include/X11/Xcursor/Xcursor.h ;;
  libxkbfile) test -e /usr/lib/libxkbfile.so.1 && test -f /usr/include/X11/extensions/XKBfile.h ;;
  xcb-util) test -e /usr/lib/libxcb-util.so.1 && test -f /usr/include/xcb/xcb_aux.h ;;
  xcb-util-image) test -e /usr/lib/libxcb-image.so.0 && test -f /usr/include/xcb/xcb_image.h ;;
  xcb-util-renderutil) test -e /usr/lib/libxcb-render-util.so.0 && test -f /usr/include/xcb/xcb_renderutil.h ;;
  xcb-util-cursor) test -e /usr/lib/libxcb-cursor.so.0 && test -f /usr/include/xcb/xcb_cursor.h ;;
esac
INSTALL
printf 'X11_D34_RESULT=PASS package=%s log=%s\n' "$PACKAGE" "$LOG"
