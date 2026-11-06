#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=10.45
readonly ARCHIVE="pcre2-$VERSION.tar.bz2"
readonly URL="https://github.com/PCRE2Project/pcre2/releases/download/$VERSION/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/pcre2-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/pcre2-$VERSION"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/pcre2-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/pcre2-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/pcre2-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -f /usr/lib/pkgconfig/libpcre2-8.pc ]]' || fail 'make is missing or PCRE2 is already installed.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'PCRE2_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'PCRE2_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'BLFS 12.4 PCRE2 %s with Unicode, JIT, 16/32-bit libraries and compression integrations; tests and checksum calculations skipped.\n' "$VERSION"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$STAGE" "$PACKAGE_LOG" <<'PCRE2_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"; package_log="$5"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/configure" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin PCRE2_SOURCE='$source' PCRE2_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$PCRE2_SOURCE"
./configure --prefix=/usr --libdir=/usr/lib --docdir=/usr/share/doc/pcre2-10.45 \
    --enable-unicode --enable-jit --enable-pcre2-16 --enable-pcre2-32 \
    --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-pcre2test-libreadline \
    --disable-static > "$PCRE2_SOURCE/configure.log" 2>&1 || { tail -n 160 "$PCRE2_SOURCE/configure.log"; exit 1; }
make -j4 > "$PCRE2_SOURCE/compile.log" 2>&1 || { tail -n 180 "$PCRE2_SOURCE/compile.log"; exit 1; }
mkdir -pv "$PCRE2_STAGE"
DESTDIR="$PCRE2_STAGE" make install > "$PCRE2_SOURCE/staged-install.log" 2>&1 || { tail -n 160 "$PCRE2_SOURCE/staged-install.log"; exit 1; }
[[ -e "$PCRE2_STAGE/usr/lib/libpcre2-8.so" && -e "$PCRE2_STAGE/usr/lib/libpcre2-16.so" && -e "$PCRE2_STAGE/usr/lib/libpcre2-32.so" ]]
[[ -f "$PCRE2_STAGE/usr/lib/pkgconfig/libpcre2-8.pc" && -f "$PCRE2_STAGE/usr/include/pcre2.h" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
printf 'PCRE2_STAGE=PASS\n'
PCRE2_BUILD_STAGE

sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/pcre2-$VERSION-$STAMP.package.log"
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
    [[ -s "$BACKUP/archive.list" ]] || fail 'PCRE2 pre-install backup is empty.'
else printf 'No existing PCRE2 targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$SOURCE" "$PACKAGE_LOG" <<'PCRE2_FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"
exec >> "$package_log" 2>&1
cd "$source"
make install
ldconfig
[[ "$(pkg-config --modversion libpcre2-8)" == 10.45 ]]
for library in /usr/lib/libpcre2-8.so /usr/lib/libpcre2-16.so /usr/lib/libpcre2-32.so; do [[ -e "$library" ]]; done
[[ -f /usr/include/pcre2.h && -x /usr/bin/pcre2grep && -x /usr/bin/pcre2test ]]
printf 'PCRE2_FINAL_INSTALL=PASS\n'
PCRE2_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/pcre2-$VERSION-$STAMP.package.log"
printf 'PCRE2_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LOG_DIR/pcre2-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/pcre2-$VERSION-$STAMP.package.status"
printf 'PCRE2 %s installed with JIT, 16/32-bit libraries, and compression integrations; tests and checksum calculations skipped.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
