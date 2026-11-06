#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=2.84.4
readonly ARCHIVE="glib-$VERSION.tar.xz"
readonly URL="https://download.gnome.org/sources/glib/2.84/$ARCHIVE"
readonly WORK="/sources/glib-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/glib-$VERSION"
readonly BUILD="$SOURCE/build"
readonly STAGE="$WORK/stage"
readonly LOGDIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOGDIR/glib-$VERSION-blfs-$STAMP.log"
readonly STATUS="$LOGDIR/glib-$VERSION-blfs-$STAMP.status"
readonly PACKAGE_LOG="$LOGDIR/glib-$VERSION-blfs-$STAMP.package.log"
readonly BACKUP="$DATA/backups/glib-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" ]] || fail 'Chroot /dev is not mounted.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not all mounted.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
  [[ "$(pkg-config --modversion libpcre2-8)" == 10.45 ]]
' || fail 'GLib build dependency PCRE2 10.45 is missing.'
mkdir -p "$LOGDIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_GLIB_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'BLFS_GLIB_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
[[ ! -e "$LFS$WORK" ]] || fail "Refusing to overwrite $WORK"
printf 'Building BLFS 12.4 GLib %s with man pages and introspection disabled. Package tests/checksum calculations skipped.\n' "$VERSION"
if [[ ! -r "$ARCHIVE_PATH" ]]; then
  tmp="$DATA/downloads/$ARCHIVE.part-$STAMP"
  curl --fail --location --retry 3 --output "$tmp" "$URL"
  sudo -n install -o 0 -g 0 -m 0644 "$tmp" "$ARCHIVE_PATH"
  rm -f "$tmp"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" <<'GLIB_BUILD_CHROOT'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"
mkdir -pv "$work"
exec > >(tee "$work/package.log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/meson.build" ]]
mkdir -pv "$build"
meson setup "$build" "$source" --prefix=/usr --buildtype=release -D introspection=disabled -D glib_debug=disabled -D man-pages=disabled -D sysprof=disabled > "$work/configure.log" 2>&1
if ninja -C "$build" -j4 > "$work/compile.log" 2>&1; then
  printf 'GLIB_BUILD=PASS\n'
else
  rc=$?; tail -n 140 "$work/compile.log"; exit "$rc"
fi
mkdir -pv "$stage"
DESTDIR="$stage" ninja -C "$build" install > "$work/staged-install.log" 2>&1
[[ -x "$stage/usr/bin/gdbus" && -f "$stage/usr/lib/libglib-2.0.so" && -f "$stage/usr/include/glib-2.0/glib.h" ]]
printf 'GLIB_STAGED_INSTALL=PASS\n'
GLIB_BUILD_CHROOT
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os, sys
root, staged_path, output_path = sys.argv[1:]
with open(staged_path, "rb") as f: staged = [p for p in f.read().split(b"\0") if p]
existing = []
for raw in staged:
    rel = os.fsdecode(raw)
    if os.path.isabs(rel) or ".." in rel.split("/"): raise SystemExit(f"unsafe path: {rel}")
    if os.path.lexists(os.path.join(root, rel)): existing.append(raw)
with open(output_path, "wb") as f:
    for raw in sorted(set(existing)): f.write(raw + b"\0")
print(f"Staged paths: {len(staged)}; pre-existing targets: {len(set(existing))}")
PY
if [[ -s "$BACKUP/existing.list0" ]]; then
  sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/existing.list0"
  sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
  sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
  [[ -s "$BACKUP/archive.list" ]] || fail 'Pre-install backup archive is empty.'
else
  printf 'No existing GLib targets needed backup.\n' > "$BACKUP/no-preexisting-files.txt"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
  /bin/bash -s -- "$BUILD" "$WORK" <<'GLIB_FINAL_INSTALL'
set -Eeuo pipefail
build="$1"; work="$2"
exec > >(tee -a "$work/package.log") 2>&1
ninja -C "$build" install
ldconfig
for pc in glib-2.0 gobject-2.0 gio-2.0; do [[ "$(pkg-config --modversion "$pc")" == 2.84.4 ]]; done
for program in gapplication gdbus gdbus-codegen gio gio-querymodules glib-compile-resources glib-compile-schemas glib-gettextize glib-mkenums gobject-query gsettings gtester; do command -v "$program" >/dev/null; done
[[ -f /usr/lib/libglib-2.0.so && -f /usr/lib/libgobject-2.0.so && -f /usr/lib/libgio-2.0.so ]]
[[ -f /usr/include/glib-2.0/glib.h && -f /usr/lib/glib-2.0/include/glibconfig.h ]]
[[ -d /usr/share/glib-2.0/schemas && -d /usr/share/man/man1 ]]
readelf -h /usr/bin/gdbus | grep -F 'Advanced Micro Devices X86-64'
ldd /usr/bin/gdbus | grep -E 'libc[.]so[.]6.*[/]usr/lib/'
printf 'GLIB_FINAL_INSTALL=PASS\n'
GLIB_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
printf 'BLFS_GLIB_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$PACKAGE_LOG" "$LFS$WORK" "$BACKUP" > "$STATUS"
printf '\nGLib installed and statically verified; no package tests/checksum calculations ran.\nStatus: %s\nFinished: %s\n' "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
