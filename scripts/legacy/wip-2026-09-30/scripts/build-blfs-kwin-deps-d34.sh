#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly PACKAGE="${ALPBAHOS_D34_PACKAGE:?D34 runner must set ALPBAHOS_D34_PACKAGE}"
case "$PACKAGE" in
  libepoxy) VERSION=1.5.10; ARCHIVE=libepoxy-1.5.10.tar.xz; METHOD=meson; SOURCE_DIR=libepoxy-1.5.10 ;;
  libevdev) VERSION=1.13.4; ARCHIVE=libevdev-1.13.4.tar.xz; METHOD=meson; SOURCE_DIR=libevdev-1.13.4 ;;
  mtdev) VERSION=1.1.7; ARCHIVE=mtdev-1.1.7.tar.bz2; METHOD=autotools; SOURCE_DIR=mtdev-1.1.7 ;;
  libinput) VERSION=1.29.1; ARCHIVE=libinput-1.29.1.tar.gz; METHOD=meson; SOURCE_DIR=libinput-1.29.1 ;;
  libxcvt) VERSION=0.1.3; ARCHIVE=libxcvt-0.1.3.tar.xz; METHOD=meson; SOURCE_DIR=libxcvt-0.1.3 ;;
  lcms2) VERSION=2.17; ARCHIVE=lcms2-2.17.tar.gz; METHOD=autotools; SOURCE_DIR=lcms2-2.17 ;;
  xcb-proto) VERSION=1.17.0; ARCHIVE=xcb-proto-1.17.0.tar.xz; METHOD=autotools; SOURCE_DIR=xcb-proto-1.17.0 ;;
  util-macros) VERSION=1.20.2; ARCHIVE=util-macros-1.20.2.tar.xz; METHOD=autotools; SOURCE_DIR=util-macros-1.20.2 ;;
  xorgproto) VERSION=2024.1; ARCHIVE=xorgproto-2024.1.tar.xz; METHOD=autotools; SOURCE_DIR=xorgproto-2024.1 ;;
  libXau) VERSION=1.0.12; ARCHIVE=libXau-1.0.12.tar.xz; METHOD=autotools; SOURCE_DIR=libXau-1.0.12 ;;
  libxcb) VERSION=1.17.0; ARCHIVE=libxcb-1.17.0.tar.xz; METHOD=autotools; SOURCE_DIR=libxcb-1.17.0 ;;
  libgudev) VERSION=238; ARCHIVE=libgudev-238.tar.xz; METHOD=meson; SOURCE_DIR=libgudev-238 ;;
  libwacom) VERSION=2.16.1; ARCHIVE=libwacom-2.16.1.tar.xz; METHOD=meson; SOURCE_DIR=libwacom-2.16.1 ;;
  *) printf 'Unsupported KWin dependency: %s\n' "$PACKAGE" >&2; exit 2 ;;
esac
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-$PACKAGE-$VERSION-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/$PACKAGE-$VERSION-d34-$STAMP.log"
readonly BACKUP="$DATA/backups/$PACKAGE-$VERSION-d34-$STAMP"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the D34 candidate.'
python3 - "$PACKAGE" "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/plasma-d34-package-order.json" <<'PY'
import json,sys
if sys.argv[1] not in json.load(open(sys.argv[2], encoding="utf-8")):
    raise SystemExit("package is not in the approved Plasma D34 order")
PY
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo unavailable.'
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT

sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
  LC_ALL=POSIX MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" "$PACKAGE" "$VERSION" "$METHOD" "$SOURCE_DIR" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; package="$3"; version="$4"; method="$5"; source_dir="$6"
source="$work/$source_dir"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"
tar -xf "/sources/$archive" -C "$work"
[[ -d "$source" ]]
case "$method" in
  meson)
    options=(--prefix=/usr --libdir=lib --buildtype=release)
    case "$package" in
      libepoxy) options+=(-Dtests=false -Dglx=no -Dx11=false) ;;
      libevdev) options+=(-Dtests=disabled -Dtools=disabled -Ddocumentation=disabled) ;;
      libwacom) options+=(-Dtests=disabled) ;;
      libinput) options+=(-Dtests=false -Ddocumentation=false -Ddebug-gui=false -Dlibwacom=false -Dudev-dir=/usr/lib/udev) ;;
    esac
    meson setup "$build" "$source" "${options[@]}" > "$work/configure.log" 2>&1 || { tail -n 140 "$work/configure.log"; exit 1; }
    ninja -C "$build" -j8 > "$work/compile.log" 2>&1 || { tail -n 160 "$work/compile.log"; exit 1; }
    mkdir -p "$stage"
    DESTDIR="$stage" ninja -C "$build" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    ;;
  autotools)
    [[ -x "$source/configure" ]]
    (cd "$source" && ./configure --prefix=/usr --libdir=/usr/lib --disable-static > "$work/configure.log" 2>&1) || { tail -n 140 "$work/configure.log"; exit 1; }
    make -C "$source" -j8 > "$work/compile.log" 2>&1 || { tail -n 160 "$work/compile.log"; exit 1; }
    mkdir -p "$stage"
    make -C "$source" DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 120 "$work/staged-install.log"; exit 1; }
    ;;
esac
case "$package" in
  libepoxy) test -s "$stage/usr/lib/pkgconfig/epoxy.pc"; test -s "$stage/usr/include/epoxy/gl.h" ;;
  libevdev) test -s "$stage/usr/lib/pkgconfig/libevdev.pc"; test -s "$stage/usr/include/libevdev-1.0/libevdev/libevdev.h" ;;
  mtdev) test -s "$stage/usr/lib/libmtdev.so"; test -s "$stage/usr/include/mtdev.h" ;;
  libinput) test -s "$stage/usr/lib/pkgconfig/libinput.pc"; test -s "$stage/usr/include/libinput.h" ;;
  libxcvt) test -s "$stage/usr/lib/pkgconfig/libxcvt.pc"; test -s "$stage/usr/include/libxcvt/libxcvt.h" ;;
  lcms2) test -s "$stage/usr/lib/pkgconfig/lcms2.pc"; test -s "$stage/usr/include/lcms2.h" ;;
  xcb-proto) test -s "$stage/usr/share/pkgconfig/xcb-proto.pc" ;;
  util-macros) test -s "$stage/usr/share/aclocal/xorg-macros.m4" ;;
  xorgproto) test -s "$stage/usr/share/pkgconfig/xproto.pc"; test -s "$stage/usr/include/X11/Xproto.h" ;;
  libXau) test -s "$stage/usr/lib/pkgconfig/xau.pc"; test -s "$stage/usr/include/X11/Xauth.h" ;;
  libxcb) test -s "$stage/usr/lib/pkgconfig/xcb.pc"; test -s "$stage/usr/include/xcb/xcb.h" ;;
  libgudev) test -s "$stage/usr/lib/pkgconfig/gudev-1.0.pc"; test -s "$stage/usr/include/gudev-1.0/gudev/gudev.h" ;;
  libwacom) test -s "$stage/usr/lib/pkgconfig/libwacom.pc"; test -s "$stage/usr/include/libwacom-1.0/libwacom/libwacom.h" ;;
esac
BUILD

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" "$PACKAGE" <<'MANIFEST'
import os,sys
root,src,dst,package=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
existing=[]
for path in paths:
    rel=os.fsdecode(path)
    if os.path.isabs(rel) or '..' in rel.split('/'):
        raise SystemExit(f'unsafe staged path: {rel}')
    if os.path.lexists(os.path.join(root,rel)):
        existing.append(path)
open(dst,'wb').write(b''.join(path+b'\0' for path in existing))
print(f'{package}: {len(paths)} staged paths; {len(existing)} existing')
if existing:
    raise SystemExit(f'Refusing existing targets: {existing[:12]!r}')
MANIFEST

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
  /bin/bash -s -- "$WORK/stage" "$PACKAGE" <<'INSTALL'
set -Eeuo pipefail
stage="$1"; package="$2"
cp -a "$stage"/. /
ldconfig
case "$package" in
  libepoxy) pkg-config --exists epoxy; test -e /usr/lib/libepoxy.so ;;
  libevdev) pkg-config --exists libevdev; test -e /usr/lib/libevdev.so ;;
  mtdev) test -e /usr/lib/libmtdev.so ;;
  libinput) pkg-config --exists libinput; test -e /usr/lib/libinput.so ;;
  libxcvt) pkg-config --exists libxcvt; test -e /usr/lib/libxcvt.so ;;
  lcms2) pkg-config --exists lcms2; test -e /usr/lib/liblcms2.so ;;
  xcb-proto) pkg-config --exists xcb-proto ;;
  util-macros) test -s /usr/share/aclocal/xorg-macros.m4 ;;
  xorgproto) pkg-config --exists xproto; test -s /usr/include/X11/Xproto.h ;;
  libXau) pkg-config --exists xau; test -e /usr/lib/libXau.so ;;
  libxcb) pkg-config --exists xcb; test -e /usr/lib/libxcb.so ;;
  libgudev) pkg-config --exists gudev-1.0; test -e /usr/lib/libgudev-1.0.so ;;
  libwacom) pkg-config --exists libwacom; test -e /usr/lib/libwacom.so ;;
esac
INSTALL
printf 'D34_RESULT=PASS PACKAGE=%s VERSION=%s LOG=%s\n' "$PACKAGE" "$VERSION" "$LOG"
