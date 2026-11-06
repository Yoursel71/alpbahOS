#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=1.2.14
readonly ARCHIVE="alsa-lib-$VERSION.tar.bz2"
readonly UCM_ARCHIVE="alsa-ucm-conf-$VERSION.tar.bz2"
readonly URL="https://www.alsa-project.org/files/pub/lib/$ARCHIVE"
readonly UCM_URL="https://www.alsa-project.org/files/pub/lib/$UCM_ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/alsa-lib-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/alsa-lib-$VERSION"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/alsa-lib-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/alsa-lib-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/alsa-lib-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly UCM_ARCHIVE_PATH="$LFS/sources/$UCM_ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"
readonly UCM_TEMP_DOWNLOAD="$DATA/downloads/$UCM_ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libasound.so.2 ]]' || fail 'make is missing or ALSA-lib is already installed.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'ALSA_LIB_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'ALSA_LIB_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'BLFS 12.4 ALSA-lib %s plus recommended UCM profiles; package tests and checksum calculation skipped.\nSource: %s\nUCM: %s\n' "$VERSION" "$URL" "$UCM_URL"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi
if ! sudo -n test -r "$UCM_ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$UCM_TEMP_DOWNLOAD" "$UCM_URL"
    sudo -n install -o 0 -g 0 -m 0644 "$UCM_TEMP_DOWNLOAD" "$UCM_ARCHIVE_PATH"
else printf 'Using retained UCM archive: %s\n' "$UCM_ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$UCM_ARCHIVE" "$WORK" "$SOURCE" "$STAGE" "$PACKAGE_LOG" <<'ALSA_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; ucm_archive="$2"; work="$3"; source="$4"; stage="$5"; package_log="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
tar -xf "/sources/$ucm_archive" -C "$work"
[[ -f "$source/configure" && -d "$work/alsa-ucm-conf-1.2.14/ucm2" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin ALSA_SOURCE='$source' ALSA_STAGE='$stage' ALSA_WORK='$work' ALSA_UCM_ARCHIVE='/sources/$ucm_archive' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$ALSA_SOURCE"
./configure --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc \
    > "$ALSA_WORK/configure.log" 2>&1 || { tail -n 160 "$ALSA_WORK/configure.log"; exit 1; }
make -j4 > "$ALSA_WORK/compile.log" 2>&1 || { tail -n 180 "$ALSA_WORK/compile.log"; exit 1; }
mkdir -pv "$ALSA_STAGE/usr/share/alsa"
DESTDIR="$ALSA_STAGE" make install > "$ALSA_WORK/staged-install.log" 2>&1 || { tail -n 140 "$ALSA_WORK/staged-install.log"; exit 1; }
tar -xf "$ALSA_UCM_ARCHIVE" -C "$ALSA_STAGE/usr/share/alsa" --strip-components=1
[[ -e "$ALSA_STAGE/usr/lib/libasound.so" && -e "$ALSA_STAGE/usr/lib/libatopology.so" ]]
[[ -f "$ALSA_STAGE/usr/share/alsa/alsa.conf" && -d "$ALSA_STAGE/usr/share/alsa/ucm2" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
printf 'ALSA_LIB_STAGE=PASS\n'
ALSA_BUILD_STAGE

sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/alsa-lib-$VERSION-$STAMP.package.log"
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
    [[ -s "$BACKUP/archive.list" ]] || fail 'ALSA-lib pre-install backup is empty.'
else printf 'No existing ALSA-lib/UCM targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$SOURCE" "$PACKAGE_LOG" <<'ALSA_FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"
exec >> "$package_log" 2>&1
cd "$source"
make prefix=/usr libdir=/usr/lib sysconfdir=/etc install
tar -xf /sources/alsa-ucm-conf-1.2.14.tar.bz2 -C /usr/share/alsa --strip-components=1
ldconfig
[[ -e /usr/lib/libasound.so && -e /usr/lib/libasound.so.2 && -e /usr/lib/libatopology.so ]]
[[ -f /usr/share/alsa/alsa.conf && -d /usr/share/alsa/ucm2 ]]
if pkg-config --exists alsa; then [[ "$(pkg-config --modversion alsa)" == 1.2.14 ]]; fi
for library in /usr/lib/libasound.so.2 /usr/lib/libatopology.so.2; do
    ldd_output="$(ldd "$library")"
    printf '%s\n' "$ldd_output"
    [[ "$ldd_output" != *'not found'* && "$ldd_output" != *'/sources/'* ]]
done
printf 'ALSA_LIB_FINAL_INSTALL=PASS\n'
ALSA_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/alsa-lib-$VERSION-$STAMP.package.log"
printf 'ALSA_LIB_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LOG_DIR/alsa-lib-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/alsa-lib-$VERSION-$STAMP.package.status"
printf 'ALSA-lib %s and UCM profiles installed; package tests and checksum calculation skipped.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
