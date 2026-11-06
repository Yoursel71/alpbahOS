#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=25.1.8
readonly ARCHIVE="mesa-$VERSION.tar.xz" STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/mesa-$VERSION-d34-$STAMP"
readonly SOURCE="$WORK/mesa-$VERSION"
readonly BUILD="$SOURCE/build" STAGE="$WORK/stage"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/mesa-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/mesa-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/mesa-$VERSION-d34-$STAMP"
readonly URL="https://mesa.freedesktop.org/archive/$ARCHIVE"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as regular user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"; sudo -n true || fail 'Non-interactive sudo unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v meson >/dev/null && command -v ninja >/dev/null && pkg-config --exists wayland-egl wayland-client libdrm yaml-0.1 && python3 -m pip --version >/dev/null && ! -e /usr/lib/libgallium-25.1.8.so'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then fail 'Another build process is active.'; fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"; exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'MESA_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'MESA_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
  if [[ -r "$DATA/downloads/$ARCHIVE" ]]; then sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$ARCHIVE_PATH"
  else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/mesa-25.1.8"; build="$source/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; mkdir -p "$build"
meson setup "$build" "$source" --prefix=/usr --buildtype=release -Dplatforms=wayland -Degl-native-platform=wayland -Dgallium-drivers=softpipe -Dvulkan-drivers=[] -Dglx=disabled -Dllvm=disabled -Dvalgrind=disabled -Dlibunwind=disabled > "$work/configure.log" 2>&1
ninja -C "$build" -j4 > "$work/compile.log" 2>&1 || { tail -n 160 "$work/compile.log"; exit 1; }
mkdir -p "$stage"; DESTDIR="$stage" ninja -C "$build" install > "$work/staged-install.log" 2>&1
mkdir -p "$stage/usr/share/doc/mesa-25.1.8"; cp -a "$source/docs/." "$stage/usr/share/doc/mesa-25.1.8/"
[[ -d "$stage/usr/lib" && -d "$stage/usr/share/doc/mesa-25.1.8" ]]
BUILD
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]; paths=[p for p in open(src,'rb').read().split(b'\0') if p]; collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in collisions)); print(f'Mesa staged paths: {len(paths)}; collisions: {len(collisions)}')
if collisions: raise SystemExit('Refusing to overwrite pre-existing candidate paths')
PY
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$SOURCE" "$BUILD" <<'INSTALL'
set -Eeuo pipefail
source="$1"; build="$2"; ninja -C "$build" install
install -d -m 0755 /usr/share/doc/mesa-25.1.8; cp -a "$source/docs/." /usr/share/doc/mesa-25.1.8/; ldconfig
for file in /usr/lib/libEGL.so.1 /usr/lib/libGLESv2.so.2 /usr/lib/libGLESv1_CM.so.1 /usr/lib/libgbm.so.1 /usr/lib/libgallium-25.1.8.so /usr/lib/gbm/dri_gbm.so; do [[ -f "$file" ]] || { echo "Missing Mesa library: $file" >&2; exit 1; }; done
pkg-config --modversion egl; pkg-config --modversion glesv2
ldd /usr/lib/libEGL.so.1 > "$source/mesa-libEGL-ldd.txt"; ! grep -Fq 'not found' "$source/mesa-libEGL-ldd.txt"
INSTALL
printf 'MESA_RESULT=PASS\nLOG=%s\nVERSION=%s\n' "$LOG" "$VERSION" > "$STATUS"
