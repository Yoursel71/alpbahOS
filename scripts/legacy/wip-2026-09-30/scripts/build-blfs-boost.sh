#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly VERSION=1.89.0
readonly ARCHIVE="boost-$VERSION-b2-nodocs.tar.xz"
readonly URL="https://github.com/boostorg/boost/releases/download/boost-$VERSION/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/boost-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/boost-$VERSION"
readonly INSTALL_STAGE="$WORK/target-stage"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/boost-$VERSION-$STAMP.log"
readonly PACKAGE_LOG="$LOG_DIR/boost-$VERSION-$STAMP.package.log"
readonly STATUS="$LOG_DIR/boost-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/boost-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the expected HDD directory.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "b2" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '
  set -e
  [[ -x /usr/bin/make && -x /usr/bin/python3-config && ! -e /usr/include/boost ]]
  shopt -s nullglob
  old=(/usr/lib/libboost_*)
  [[ ${#old[@]} -eq 0 ]]
' || fail 'Boost prerequisites are missing, or an older Boost install requires an explicit upgrade plan.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'BLFS_BOOST_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'BLFS_BOOST_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

printf 'BLFS 12.4 Boost %s; shared libraries, Python 3 bindings, package tests skipped; checksum calculation skipped.\nSource: %s\n' "$VERSION" "$URL"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$INSTALL_STAGE" <<'BUILD_AND_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$work/package.log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/bootstrap.sh" && -f "$source/boost/version.hpp" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin BOOST_SOURCE='$source' BOOST_STAGE='$stage' BOOST_WORK='$work' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$BOOST_SOURCE"
./bootstrap.sh --prefix=/usr --with-python=python3 > "$BOOST_WORK/bootstrap.log" 2>&1 || { tail -n 180 "$BOOST_WORK/bootstrap.log"; exit 1; }
./b2 stage -j4 threading=multi link=shared > "$BOOST_WORK/compile.log" 2>&1 || { tail -n 240 "$BOOST_WORK/compile.log"; exit 1; }
mkdir -pv "$BOOST_STAGE"
DESTDIR="$BOOST_STAGE" ./b2 install -j4 threading=multi link=shared > "$BOOST_WORK/staged-install.log" 2>&1 || { tail -n 220 "$BOOST_WORK/staged-install.log"; exit 1; }
[[ -f "$BOOST_STAGE/usr/include/boost/version.hpp" ]]
[[ -e "$BOOST_STAGE/usr/lib/libboost_filesystem.so" && -e "$BOOST_STAGE/usr/lib/libboost_thread.so" ]]
[[ -d "$BOOST_STAGE/usr/share/boost_predef" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
printf 'BOOST_BUILD_STAGE=PASS\n'
BUILD_AND_STAGE

sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
sudo -n find "$LFS$INSTALL_STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged-paths.list0"
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
    [[ -s "$BACKUP/archive.list" ]] || fail 'Pre-install Boost archive is empty.'
else printf 'No pre-existing Boost target files required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$SOURCE" "$WORK" <<'FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; work="$2"
exec > >(tee -a "$work/package.log") 2>&1
cd "$source"
./b2 install -j4 threading=multi link=shared
ldconfig
[[ -f /usr/include/boost/version.hpp && -d /usr/share/boost_predef ]]
grep -Fq '#define BOOST_LIB_VERSION "1_89"' /usr/include/boost/version.hpp
[[ -e /usr/lib/libboost_filesystem.so && -e /usr/lib/libboost_thread.so ]]
ldd_output="$(ldd /usr/lib/libboost_filesystem.so)"
printf '%s\n' "$ldd_output"
[[ "$ldd_output" != *'not found'* && "$ldd_output" != *'/sources/'* ]]
printf 'BOOST_FINAL_INSTALL=PASS\n'
FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
printf 'BLFS_BOOST_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$PACKAGE_LOG" "$LFS$WORK" "$BACKUP" > "$STATUS"
printf 'Boost %s installed; tests and checksum calculation skipped.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
