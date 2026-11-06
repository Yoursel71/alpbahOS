#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly PACKAGE="${ALPBAHOS_D34_PACKAGE:?D34 runner must set ALPBAHOS_D34_PACKAGE}"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly WORK="/dev/shm/alpbahos-d34-$PACKAGE-$STAMP"
readonly STAGE="$WORK/stage"
case "$PACKAGE" in
  libogg) readonly VERSION=1.3.6 ARCHIVE=libogg-1.3.6.tar.xz ;;
  libvorbis) readonly VERSION=1.3.7 ARCHIVE=libvorbis-1.3.7.tar.xz ;;
  libcanberra) readonly VERSION=0.30 ARCHIVE=libcanberra-0.30.tar.xz PATCH=libcanberra-0.30-wayland-1.patch ;;
  *) printf 'Unsupported notification audio prerequisite: %s\n' "$PACKAGE" >&2; exit 2 ;;
esac
readonly LOG="$LOG_DIR/$PACKAGE-d34-$STAMP.log"
readonly BACKUP="$DATA/backups/$PACKAGE-d34-$STAMP"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as the regular user against the D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
if [[ "$PACKAGE" == libcanberra ]]; then
  [[ -r "$DATA/downloads/$PATCH" ]] || fail "Missing BLFS patch: $DATA/downloads/$PATCH"
  sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$PATCH" "$LFS/sources/$PATCH"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin \
  PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig LD_LIBRARY_PATH=/usr/lib LC_ALL=POSIX MAKEFLAGS=-j8 \
  /bin/bash -s -- "$PACKAGE" "$VERSION" "$ARCHIVE" "${PATCH:-}" "$WORK" <<'BUILD'
set -Eeuo pipefail
package="$1"; version="$2"; archive="$3"; patch_file="$4"; work="$5"
stage="$work/stage"; source="$work/$package-$version"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite work tree: $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -x "$source/configure" ]]
cd "$source"
case "$package" in
  libogg) ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/libogg-1.3.6 > "$work/configure.log" 2>&1 || { tail -n 100 "$work/configure.log"; exit 1; } ;;
  libvorbis) ./configure --prefix=/usr --disable-static > "$work/configure.log" 2>&1 || { tail -n 100 "$work/configure.log"; exit 1; } ;;
  libcanberra)
    patch -Np1 -i "/sources/$patch_file"
    ./configure --prefix=/usr --disable-oss --disable-gtk3 > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
    ;;
esac
make -j8 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -p "$stage"
make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 100 "$work/staged-install.log"; exit 1; }
case "$package" in
  libogg) [[ -f "$stage/usr/lib/libogg.so" && -f "$stage/usr/include/ogg/ogg.h" ]] ;;
  libvorbis) [[ -f "$stage/usr/lib/libvorbis.so" && -f "$stage/usr/include/vorbis/codec.h" ]] ;;
  libcanberra) [[ -f "$stage/usr/lib/libcanberra.so" && -f "$stage/usr/include/canberra.h" ]] ;;
esac
BUILD
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$PACKAGE" "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
package,root,src,dst=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
existing=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in existing))
print(f'{package} staged paths={len(paths)} existing targets={len(existing)}')
if existing: raise SystemExit(f'Refusing existing candidate paths: {existing[:12]!r}')
PY
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin \
  PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig LD_LIBRARY_PATH=/usr/lib LC_ALL=POSIX \
  /bin/bash -s -- "$STAGE" "$PACKAGE" "$VERSION" <<'INSTALL'
set -Eeuo pipefail
stage="$1"; package="$2"; version="$3"
cp -a "$stage/." /
ldconfig
case "$package" in
  libogg) [[ "$(pkg-config --modversion ogg)" == "$version" ]] ;;
  libvorbis) [[ "$(pkg-config --modversion vorbis)" == "$version" ]] ;;
  libcanberra)
    [[ "$(pkg-config --modversion libcanberra)" == "$version" ]]
    ;;
esac
INSTALL
printf 'D34_RESULT=PASS PACKAGE=%s VERSION=%s LOG=%s\n' "$PACKAGE" "$VERSION" "$LOG"
