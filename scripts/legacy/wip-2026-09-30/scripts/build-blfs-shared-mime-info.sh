#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=2.4
readonly ARCHIVE="shared-mime-info-$VERSION.tar.gz"
readonly URL="https://gitlab.freedesktop.org/xdg/shared-mime-info/-/archive/$VERSION/$ARCHIVE"
readonly WORK="/sources/shared-mime-info-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/shared-mime-info-$VERSION"
readonly BUILD="$SOURCE/build"
readonly STAGE="$WORK/stage"
readonly LOGDIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOGDIR/shared-mime-info-$VERSION-blfs-$STAMP.log"
readonly STATUS="$LOGDIR/shared-mime-info-$VERSION-blfs-$STAMP.status"
readonly PACKAGE_LOG="$LOGDIR/shared-mime-info-$VERSION-blfs-$STAMP.package.log"
readonly BACKUP="$DATA/backups/shared-mime-info-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the HDD build directory.'
[[ -c "$LFS/dev/null" ]] || fail 'Chroot /dev is not mounted.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not all mounted.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
  [[ "$(pkg-config --modversion glib-2.0)" == 2.84.4 ]]
  [[ "$(pkg-config --modversion libxml-2.0)" == 2.14.5 ]]
' || fail 'GLib 2.84.4 and libxml2 2.14.5 must be installed.'
mkdir -p "$LOGDIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_SHARED_MIME_INFO_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'BLFS_SHARED_MIME_INFO_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
[[ ! -e "$LFS$WORK" ]] || fail "Refusing to overwrite $WORK"
printf 'Building BLFS 12.4 shared-mime-info %s. Install-time MIME database generation enabled after final install. Package tests/checksum calculations skipped.\n' "$VERSION"
if [[ ! -r "$ARCHIVE_PATH" ]]; then
  tmp="$DATA/downloads/$ARCHIVE.part-$STAMP"
  curl --fail --location --retry 3 --output "$tmp" "$URL"
  sudo -n install -o 0 -g 0 -m 0644 "$tmp" "$ARCHIVE_PATH"
  rm -f "$tmp"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" <<'SHARED_MIME_BUILD_CHROOT'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"
mkdir -pv "$work"
exec > >(tee "$work/package.log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/meson.build" ]]
mkdir -pv "$build"
meson setup "$build" "$source" --prefix=/usr --buildtype=release -D update-mimedb=false > "$work/configure.log" 2>&1
if ninja -C "$build" -j4 > "$work/compile.log" 2>&1; then printf 'SHARED_MIME_INFO_BUILD=PASS\n'; else rc=$?; tail -n 120 "$work/compile.log"; exit "$rc"; fi
mkdir -pv "$stage"
DESTDIR="$stage" ninja -C "$build" install > "$work/staged-install.log" 2>&1
[[ -x "$stage/usr/bin/update-mime-database" && -f "$stage/usr/share/mime/packages/freedesktop.org.xml" ]]
printf 'SHARED_MIME_INFO_STAGE=PASS\n'
SHARED_MIME_BUILD_CHROOT
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
mime = b"usr/share/mime"
if os.path.lexists(os.path.join(root, os.fsdecode(mime))):
    existing = [p for p in existing if p != mime and not p.startswith(mime + b"/")]
    existing.append(mime)
with open(output_path, "wb") as f:
    for raw in sorted(set(existing)): f.write(raw + b"\0")
print(f"Staged paths: {len(staged)}; existing targets after MIME tree capture: {len(set(existing))}")
PY
if [[ -s "$BACKUP/existing.list0" ]]; then
  sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/existing.list0"
  sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
  sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
  [[ -s "$BACKUP/archive.list" ]] || fail 'Pre-install backup archive is empty.'
else
  printf 'No existing shared-mime-info or MIME database paths needed backup.\n' > "$BACKUP/no-preexisting-files.txt"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
  /bin/bash -s -- "$BUILD" "$WORK" <<'SHARED_MIME_FINAL_INSTALL'
set -Eeuo pipefail
build="$1"; work="$2"
exec > >(tee -a "$work/package.log") 2>&1
ninja -C "$build" install
/usr/bin/update-mime-database /usr/share/mime
[[ -x /usr/bin/update-mime-database ]]
[[ -f /usr/share/mime/mime.cache && -f /usr/share/mime/packages/freedesktop.org.xml ]]
[[ -d /usr/share/mime/application && -d /usr/share/mime/image ]]
readelf -h /usr/bin/update-mime-database | grep -F 'Advanced Micro Devices X86-64'
ldd /usr/bin/update-mime-database | grep -E 'libc[.]so[.]6.*/usr/lib/'
printf 'SHARED_MIME_INFO_FINAL_INSTALL=PASS\n'
SHARED_MIME_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
printf 'BLFS_SHARED_MIME_INFO_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$PACKAGE_LOG" "$LFS$WORK" "$BACKUP" > "$STATUS"
printf '\nshared-mime-info installed; package tests/checksum calculations skipped.\nStatus: %s\nFinished: %s\n' "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

