#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=3.11.0
readonly ARCHIVE="libnl-$VERSION.tar.gz"
readonly URL="https://github.com/thom311/libnl/releases/download/libnl3_11_0/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/libnl-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/libnl-$VERSION"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/libnl-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/libnl-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/libnl-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -f /usr/lib/pkgconfig/libnl-3.0.pc ]]' || fail 'make is missing or libnl is already installed.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'LIBNL_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'LIBNL_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
printf 'BLFS 12.4 libnl %s; test suite and checksum calculation skipped.\n' "$VERSION"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$STAGE" "$PACKAGE_LOG" <<'LIBNL_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"; package_log="$5"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/configure" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LIBNL_SOURCE='$source' LIBNL_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$LIBNL_SOURCE"
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make -j4
mkdir -pv "$LIBNL_STAGE"
DESTDIR="$LIBNL_STAGE" make install
[[ -f "$LIBNL_STAGE/usr/lib/libnl-3.so" && -f "$LIBNL_STAGE/usr/include/libnl3/netlink/netlink.h" && -f "$LIBNL_STAGE/usr/lib/pkgconfig/libnl-3.0.pc" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
printf 'LIBNL_STAGE=PASS\n'
LIBNL_BUILD_STAGE
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/libnl-$VERSION-$STAMP.package.log"
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged-paths.list0"
python3 - "$LFS" "$BACKUP/staged-paths.list0" "$BACKUP/preexisting-paths.list0" <<'PY'
import os, sys
root, staged, out = sys.argv[1:]
with open(staged, 'rb') as stream: paths = [p for p in stream.read().split(b'\0') if p]
old = []
for raw in paths:
    rel = os.fsdecode(raw)
    if os.path.isabs(rel) or '..' in rel.split('/'): raise SystemExit(f'Unsafe path: {rel!r}')
    if os.path.lexists(os.path.join(root, rel)): old.append(raw)
with open(out, 'wb') as stream:
    for raw in sorted(set(old)): stream.write(raw + b'\0')
print(f'Staged paths: {len(paths)}; existing target paths: {len(set(old))}')
PY
if [[ -s "$BACKUP/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
    [[ -s "$BACKUP/archive.list" ]] || fail 'libnl pre-install backup is empty.'
else printf 'No existing libnl targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$SOURCE" "$PACKAGE_LOG" <<'LIBNL_FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cd "$source"
make prefix=/usr sysconfdir=/etc install
ldconfig
pkg-config --exists libnl-3.0 libnl-route-3.0 libnl-genl-3.0
[[ "$(pkg-config --modversion libnl-3.0)" == 3.11.0 ]]
[[ -f /usr/lib/libnl-3.so && -f /usr/lib/libnl-route-3.so && -f /usr/include/libnl3/netlink/netlink.h ]]
command -v nl-link-list >/dev/null
printf 'LIBNL_FINAL_INSTALL=PASS\n'
LIBNL_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/libnl-$VERSION-$STAMP.package.log"
printf 'LIBNL_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LOG_DIR/libnl-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/libnl-$VERSION-$STAMP.package.status"
printf 'libnl %s installed; test suite and checksum calculation were skipped.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
