#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=5.4.8
readonly ARCHIVE="lua-$VERSION.tar.gz"
readonly PATCH="lua-$VERSION-shared_library-1.patch"
readonly URL="https://www.lua.org/ftp/$ARCHIVE"
readonly PATCH_URL="https://www.linuxfromscratch.org/patches/blfs/12.4/$PATCH"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/lua-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/lua-$VERSION"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/lua-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/lua-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/lua-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly PATCH_PATH="$LFS/sources/$PATCH"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"
readonly PATCH_TEMP_DOWNLOAD="$DATA/downloads/$PATCH.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/liblua.so.5.4 ]]' || fail 'make is missing or Lua is already installed.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'LUA_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'LUA_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'BLFS 12.4 Lua %s with the shared-library patch; package tests and checksum calculation skipped.\nSource: %s\nPatch: %s\n' "$VERSION" "$URL" "$PATCH_URL"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi
if ! sudo -n test -r "$PATCH_PATH"; then
    curl --fail --location --retry 3 --output "$PATCH_TEMP_DOWNLOAD" "$PATCH_URL"
    sudo -n install -o 0 -g 0 -m 0644 "$PATCH_TEMP_DOWNLOAD" "$PATCH_PATH"
else printf 'Using retained patch: %s\n' "$PATCH_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$PATCH" "$WORK" "$SOURCE" "$STAGE" "$PACKAGE_LOG" <<'LUA_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; patch_file="$2"; work="$3"; source="$4"; stage="$5"; package_log="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/Makefile" && -f "/sources/$patch_file" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LUA_SOURCE='$source' LUA_STAGE='$stage' LUA_WORK='$work' LUA_PATCH='/sources/$patch_file' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$LUA_SOURCE"
patch -Np1 -i "$LUA_PATCH"
cat > "$LUA_SOURCE/lua.pc" <<'LUA_PC'
V=5.4
R=5.4.8

prefix=/usr
INSTALL_BIN=${prefix}/bin
INSTALL_INC=${prefix}/include
INSTALL_LIB=${prefix}/lib
INSTALL_MAN=${prefix}/share/man/man1
INSTALL_LMOD=${prefix}/share/lua/${V}
INSTALL_CMOD=${prefix}/lib/lua/${V}
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: Lua
Description: An Extensible Extension Language
Version: ${R}
Requires:
Libs: -L${libdir} -llua -lm -ldl
Cflags: -I${includedir}
LUA_PC
make -j4 linux > "$LUA_WORK/compile.log" 2>&1 || { tail -n 160 "$LUA_WORK/compile.log"; exit 1; }
mkdir -pv "$LUA_STAGE/usr/lib/pkgconfig"
make "INSTALL_TOP=$LUA_STAGE/usr" 'INSTALL_DATA=cp -d' \
    "INSTALL_MAN=$LUA_STAGE/usr/share/man/man1" \
    'TO_LIB=liblua.so liblua.so.5.4 liblua.so.5.4.8' install \
    > "$LUA_WORK/staged-install.log" 2>&1 || { tail -n 160 "$LUA_WORK/staged-install.log"; exit 1; }
mkdir -pv "$LUA_STAGE/usr/share/doc/lua-5.4.8"
cp -v doc/*.{html,css,gif,png} "$LUA_STAGE/usr/share/doc/lua-5.4.8/"
install -v -m 0644 -D "$LUA_SOURCE/lua.pc" "$LUA_STAGE/usr/lib/pkgconfig/lua.pc"
[[ -x "$LUA_STAGE/usr/bin/lua" && -x "$LUA_STAGE/usr/bin/luac" ]]
[[ -e "$LUA_STAGE/usr/lib/liblua.so" && -e "$LUA_STAGE/usr/lib/liblua.so.5.4.8" ]]
[[ -f "$LUA_STAGE/usr/include/lua.h" && -f "$LUA_STAGE/usr/lib/pkgconfig/lua.pc" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
printf 'LUA_STAGE=PASS\n'
LUA_BUILD_STAGE

sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/lua-$VERSION-$STAMP.package.log"
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
    [[ -s "$BACKUP/archive.list" ]] || fail 'Lua pre-install backup is empty.'
else printf 'No existing Lua targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$SOURCE" "$PACKAGE_LOG" <<'LUA_FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"
exec >> "$package_log" 2>&1
cd "$source"
make "INSTALL_TOP=/usr" 'INSTALL_DATA=cp -d' \
    INSTALL_MAN=/usr/share/man/man1 \
    'TO_LIB=liblua.so liblua.so.5.4 liblua.so.5.4.8' install
mkdir -pv /usr/share/doc/lua-5.4.8
cp -v doc/*.{html,css,gif,png} /usr/share/doc/lua-5.4.8/
install -v -m644 -D lua.pc /usr/lib/pkgconfig/lua.pc
ldconfig
[[ -x /usr/bin/lua && -x /usr/bin/luac ]]
[[ -e /usr/lib/liblua.so.5.4 && -e /usr/lib/liblua.so.5.4.8 && -f /usr/include/lua.h ]]
[[ "$(pkg-config --modversion lua)" == 5.4.8 ]]
[[ "$(lua -v 2>&1)" == *'Lua 5.4.8'* ]]
output="$(ldd /usr/lib/liblua.so.5.4)"
printf '%s\n' "$output"
[[ "$output" != *'not found'* && "$output" != *'/sources/'* ]]
printf 'LUA_FINAL_INSTALL=PASS\n'
LUA_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/lua-$VERSION-$STAMP.package.log"
printf 'LUA_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LOG_DIR/lua-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/lua-$VERSION-$STAMP.package.status"
printf 'Lua %s shared library, interpreter, pkg-config file, and docs installed; tests and checksum calculation skipped.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
