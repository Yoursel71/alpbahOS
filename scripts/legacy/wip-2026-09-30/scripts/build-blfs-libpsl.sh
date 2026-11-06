#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=0.21.5
readonly ARCHIVE="libpsl-$VERSION.tar.gz"
readonly URL="https://github.com/rockdaboot/libpsl/releases/download/$VERSION/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/libpsl-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/libpsl-$VERSION"
readonly STAGE="$WORK/stage"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/libpsl-$VERSION-$STAMP.log"
readonly PACKAGE_LOG="$LOG_DIR/libpsl-$VERSION-$STAMP.package.log"
readonly STATUS="$LOG_DIR/libpsl-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/libpsl-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libpsl.so ]]' || fail 'make is missing or libpsl already exists in the target.'
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ "$(pkg-config --modversion libidn2)" == 2.3.8 ]]' || fail 'libpsl dependency libidn2 2.3.8 is missing.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'BLFS_LIBPSL_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'BLFS_LIBPSL_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

printf 'BLFS 12.4 libpsl %s; package tests and checksum calculation skipped.\nSource: %s\n' "$VERSION" "$URL"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$STAGE" <<'BUILD_AND_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$work/package.log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/meson.build" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin PACKAGE_SOURCE='$source' PACKAGE_STAGE='$stage' PACKAGE_WORK='$work' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
mkdir -pv "$PACKAGE_WORK/build"
meson setup "$PACKAGE_WORK/build" "$PACKAGE_SOURCE" --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback -Dtests=false -Ddocs=false -Druntime=libidn2 > "$PACKAGE_WORK/configure.log" 2>&1 || { tail -n 180 "$PACKAGE_WORK/configure.log"; exit 1; }
ninja -C "$PACKAGE_WORK/build" -j4 > "$PACKAGE_WORK/compile.log" 2>&1 || { tail -n 200 "$PACKAGE_WORK/compile.log"; exit 1; }
mkdir -pv "$PACKAGE_STAGE"
DESTDIR="$PACKAGE_STAGE" ninja -C "$PACKAGE_WORK/build" install > "$PACKAGE_WORK/staged-install.log" 2>&1 || { tail -n 180 "$PACKAGE_WORK/staged-install.log"; exit 1; }
[[ -e "$PACKAGE_STAGE/usr/lib/libpsl.so" ]]
[[ -x "$PACKAGE_STAGE/usr/bin/psl" && -f "$PACKAGE_STAGE/usr/include/libpsl.h" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
printf 'LIBPSL_BUILD_STAGE=PASS\n'
BUILD_AND_STAGE

sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged-paths.list0"
python3 - "$LFS" "$BACKUP/staged-paths.list0" "$BACKUP/preexisting-paths.list0" <<'PY'
import os, sys
root, staged, out = sys.argv[1:]
with open(staged, 'rb') as stream:
    paths = [path for path in stream.read().split(b'\0') if path]
existing = []
for raw in paths:
    rel = os.fsdecode(raw)
    if os.path.isabs(rel) or '..' in rel.split('/'):
        raise SystemExit(f'Unsafe staged path: {rel!r}')
    if os.path.lexists(os.path.join(root, rel)):
        existing.append(raw)
with open(out, 'wb') as stream:
    for raw in sorted(set(existing)):
        stream.write(raw + b'\0')
print(f'Staged file/link paths: {len(paths)}; existing target paths: {len(set(existing))}')
PY
if [[ -s "$BACKUP/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
    [[ -s "$BACKUP/archive.list" ]] || fail 'Pre-install libpsl archive is empty.'
else printf 'No pre-existing libpsl target files required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$SOURCE" "$WORK" <<'FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; work="$2"
exec > >(tee -a "$work/package.log") 2>&1
cd "$source"
ninja -C "$work/build" install
ldconfig
[[ -e /usr/lib/libpsl.so && -x /usr/bin/psl && -f /usr/include/libpsl.h ]]
[[ "$(pkg-config --modversion libpsl)" == 0.21.5 ]]
ldd_output="$(ldd /usr/lib/libpsl.so)"
printf '%s\n' "$ldd_output"
[[ "$ldd_output" != *'not found'* && "$ldd_output" != *'/sources/'* ]]
printf 'LIBPSL_FINAL_INSTALL=PASS\n'
FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
printf 'BLFS_LIBPSL_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$PACKAGE_LOG" "$LFS$WORK" "$BACKUP" > "$STATUS"
printf 'libpsl %s installed; package tests and checksum calculation skipped.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
