#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly VERSION=2.10.3
readonly ARCHIVE="cracklib-$VERSION.tar.xz"
readonly WORDS_ARCHIVE="cracklib-words-$VERSION.xz"
readonly URL="https://github.com/cracklib/cracklib/releases/download/v$VERSION/$ARCHIVE"
readonly WORDS_URL="https://github.com/cracklib/cracklib/releases/download/v$VERSION/$WORDS_ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/cracklib-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/cracklib-$VERSION"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/cracklib-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/cracklib-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/cracklib-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly WORDS_ARCHIVE_PATH="$LFS/sources/$WORDS_ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"
readonly WORDS_TEMP_DOWNLOAD="$DATA/downloads/$WORDS_ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the expected HDD directory.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '
    [[ -x /usr/bin/make && -x /usr/bin/xzcat && -x /usr/bin/python3 && -f /usr/include/python3.13/Python.h ]]
    [[ ! -e /usr/lib/libcrack.so && ! -e /usr/lib/cracklib/pw_dict.pwd ]]
    [[ ! -e /usr/share/dict/cracklib-words && ! -e /usr/share/dict/words ]]
' || fail 'CrackLib prerequisites are missing or a target path is already occupied.'

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'CRACKLIB_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'CRACKLIB_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'BLFS 12.4 CrackLib %s; password wordlist baseline included; package tests and checksum calculations skipped.\n' "$VERSION"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi
if ! sudo -n test -r "$WORDS_ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$WORDS_TEMP_DOWNLOAD" "$WORDS_URL"
    sudo -n install -o 0 -g 0 -m 0644 "$WORDS_TEMP_DOWNLOAD" "$WORDS_ARCHIVE_PATH"
else printf 'Using retained wordlist archive: %s\n' "$WORDS_ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORDS_ARCHIVE" "$WORK" "$SOURCE" "$STAGE" "$PACKAGE_LOG" <<'CRACKLIB_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; words_archive="$2"; work="$3"; source="$4"; stage="$5"; package_log="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
cp "/sources/$words_archive" "$work/$words_archive"
[[ -f "$source/configure" && -f "$source/Makefile.in" && -s "$work/$words_archive" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin CRACKLIB_SOURCE='$source' CRACKLIB_WORK='$work' CRACKLIB_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$CRACKLIB_SOURCE"
CPPFLAGS='-I/usr/include/python3.13' ./configure \
    --prefix=/usr \
    --disable-static \
    --with-default-dict=/usr/lib/cracklib/pw_dict > "$CRACKLIB_WORK/configure.log" 2>&1 || { tail -n 100 "$CRACKLIB_WORK/configure.log"; exit 1; }
make -j4 > "$CRACKLIB_WORK/compile.log" 2>&1 || { tail -n 120 "$CRACKLIB_WORK/compile.log"; exit 1; }
mkdir -pv "$CRACKLIB_STAGE"
DESTDIR="$CRACKLIB_STAGE" make install > "$CRACKLIB_WORK/staged-install.log" 2>&1 || { tail -n 100 "$CRACKLIB_WORK/staged-install.log"; exit 1; }
install -d "$CRACKLIB_STAGE/usr/share/dict"
xzcat "$CRACKLIB_WORK/cracklib-words-2.10.3.xz" > "$CRACKLIB_STAGE/usr/share/dict/cracklib-words"
printf '%s\n' alpbahos sifre parola turkiye istanbul admin password qwerty 123456 > "$CRACKLIB_STAGE/usr/share/dict/cracklib-extra-words"
ln -s cracklib-words "$CRACKLIB_STAGE/usr/share/dict/words"
[[ -s "$CRACKLIB_STAGE/usr/lib/libcrack.so" ]]
[[ -x "$CRACKLIB_STAGE/usr/sbin/cracklib-packer" || -x "$CRACKLIB_STAGE/usr/bin/cracklib-packer" ]]
[[ -x "$CRACKLIB_STAGE/usr/sbin/create-cracklib-dict" || -x "$CRACKLIB_STAGE/usr/bin/create-cracklib-dict" ]]
[[ -x "$CRACKLIB_STAGE/usr/sbin/cracklib-check" || -x "$CRACKLIB_STAGE/usr/bin/cracklib-check" ]]
[[ -s "$CRACKLIB_STAGE/usr/share/dict/cracklib-words" && -L "$CRACKLIB_STAGE/usr/share/dict/words" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
printf 'CRACKLIB_STAGE=PASS\n'
CRACKLIB_BUILD_STAGE

sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/cracklib-$VERSION-$STAMP.package.log"
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged-paths.list0"
python3 - "$BACKUP/staged-paths.list0" <<'PY'
import sys
path = sys.argv[1]
with open(path, 'ab') as stream:
    for name in (
        b'usr/lib/cracklib/pw_dict.hwm',
        b'usr/lib/cracklib/pw_dict.pwd',
        b'usr/lib/cracklib/pw_dict.pwi',
    ):
        stream.write(name + b'\0')
PY
sort -zu "$BACKUP/staged-paths.list0" -o "$BACKUP/staged-paths.list0"
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
    [[ -s "$BACKUP/archive.list" ]] || fail 'CrackLib pre-install backup is empty.'
else printf 'No existing CrackLib targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$SOURCE" "$STAGE" "$PACKAGE_LOG" <<'CRACKLIB_FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; stage="$2"; package_log="$3"
exec > >(tee -a "$package_log") 2>&1
cd "$source"
make install
install -d /usr/share/dict /usr/lib/cracklib
install -m 0644 "$stage/usr/share/dict/cracklib-words" /usr/share/dict/cracklib-words
install -m 0644 "$stage/usr/share/dict/cracklib-extra-words" /usr/share/dict/cracklib-extra-words
if [[ ! -e /usr/share/dict/words ]]; then ln -s cracklib-words /usr/share/dict/words; fi
create-cracklib-dict /usr/share/dict/cracklib-words /usr/share/dict/cracklib-extra-words
ldconfig
[[ -s /usr/lib/libcrack.so && -s /usr/lib/cracklib/pw_dict.hwm && -s /usr/lib/cracklib/pw_dict.pwd && -s /usr/lib/cracklib/pw_dict.pwi ]]
command -v cracklib-check >/dev/null
command -v create-cracklib-dict >/dev/null
printf 'CRACKLIB_FINAL_INSTALL=PASS\n'
CRACKLIB_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/cracklib-$VERSION-$STAMP.package.log"
printf 'CRACKLIB_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LOG_DIR/cracklib-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/cracklib-$VERSION-$STAMP.package.status"
printf 'CrackLib %s installed with a baseline dictionary and alpbahOS/Turkish common-word additions; test suite and checksum calculation were skipped.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
