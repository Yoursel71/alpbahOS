#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly VERSION=1.4.5
readonly ARCHIVE="libpwquality-$VERSION.tar.bz2"
readonly URL="https://github.com/libpwquality/libpwquality/releases/download/libpwquality-$VERSION/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/libpwquality-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/libpwquality-$VERSION"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/libpwquality-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/libpwquality-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/libpwquality-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the expected HDD directory.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '
    [[ -x /usr/bin/make && -x /usr/bin/pip3 && -x /usr/bin/pkg-config ]]
    [[ -s /usr/lib/libcrack.so && -s /usr/lib/cracklib/pw_dict.pwd ]]
    [[ -f /usr/include/security/pam_modules.h ]]
    [[ ! -e /usr/lib/libpwquality.so && ! -e /usr/lib/security/pam_pwquality.so ]]
    [[ "$(cat /etc/pam.d/system-password)" == "password    required    pam_unix.so yescrypt shadow try_first_pass" ]]
' || fail 'CrackLib/PAM prerequisites are missing, libpwquality already exists, or the PAM policy differs from the expected baseline.'

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'LIBPWQUALITY_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'LIBPWQUALITY_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'BLFS 12.4 libpwquality %s; PAM password quality enabled; package has no test suite; checksum calculation skipped.\n' "$VERSION"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$STAGE" "$PACKAGE_LOG" <<'LIBPWQUALITY_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"; package_log="$5"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/configure" && -d "$source/python" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LIBPWQUALITY_SOURCE='$source' LIBPWQUALITY_WORK='$work' LIBPWQUALITY_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$LIBPWQUALITY_SOURCE"
./configure \
    --prefix=/usr \
    --disable-static \
    --with-securedir=/usr/lib/security \
    --disable-python-bindings > "$LIBPWQUALITY_WORK/configure.log" 2>&1 || { tail -n 100 "$LIBPWQUALITY_WORK/configure.log"; exit 1; }
make -j4 > "$LIBPWQUALITY_WORK/compile.log" 2>&1 || { tail -n 120 "$LIBPWQUALITY_WORK/compile.log"; exit 1; }
mkdir -pv dist
python3 -m pip wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$LIBPWQUALITY_SOURCE/python" > "$LIBPWQUALITY_WORK/python-wheel.log" 2>&1 || { tail -n 100 "$LIBPWQUALITY_WORK/python-wheel.log"; exit 1; }
compgen -G 'dist/*.whl' >/dev/null
mkdir -pv "$LIBPWQUALITY_STAGE"
DESTDIR="$LIBPWQUALITY_STAGE" make install > "$LIBPWQUALITY_WORK/staged-install.log" 2>&1 || { tail -n 100 "$LIBPWQUALITY_WORK/staged-install.log"; exit 1; }
python3 -m pip install --no-index --find-links dist --no-user --root "$LIBPWQUALITY_STAGE" pwquality > "$LIBPWQUALITY_WORK/staged-python-install.log" 2>&1 || { tail -n 100 "$LIBPWQUALITY_WORK/staged-python-install.log"; exit 1; }
[[ -s "$LIBPWQUALITY_STAGE/usr/lib/libpwquality.so" && -s "$LIBPWQUALITY_STAGE/usr/lib/security/pam_pwquality.so" ]]
[[ -f "$LIBPWQUALITY_STAGE/usr/lib/pkgconfig/pwquality.pc" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
printf 'LIBPWQUALITY_STAGE=PASS\n'
LIBPWQUALITY_BUILD_STAGE

sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/libpwquality-$VERSION-$STAMP.package.log"
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged-paths.list0"
python3 - "$BACKUP/staged-paths.list0" <<'PY'
import sys
with open(sys.argv[1], 'ab') as stream: stream.write(b'etc/pam.d/system-password\0')
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
    [[ -s "$BACKUP/archive.list" ]] || fail 'libpwquality pre-install backup is empty.'
else printf 'No existing libpwquality targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$SOURCE" "$PACKAGE_LOG" <<'LIBPWQUALITY_FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cd "$source"
make install
python3 -m pip install --no-index --find-links dist --no-user pwquality
ldconfig
cat > /etc/pam.d/system-password <<'PAM_POLICY'
# Begin /etc/pam.d/system-password
# Check new passwords against the CrackLib dictionary and basic quality rules.
password required pam_pwquality.so authtok_type=UNIX retry=1 difok=1 minlen=8 dcredit=0 ucredit=0 lcredit=0 ocredit=0 minclass=1 maxrepeat=0 maxsequence=0 maxclassrepeat=0 gecoscheck=0 dictcheck=1 usercheck=1 enforcing=1 badwords="" dictpath=/usr/lib/cracklib/pw_dict

# Keep yescrypt hashing, shadow use, and any token collected by earlier modules.
password required pam_unix.so yescrypt shadow try_first_pass
# End /etc/pam.d/system-password
PAM_POLICY
[[ "$(pkg-config --modversion pwquality)" == 1.4.5 ]]
[[ -s /usr/lib/security/pam_pwquality.so && -s /usr/lib/libpwquality.so ]]
python3 -c 'import pwquality; assert pwquality.__file__.startswith("/usr/lib/")'
python3 - /etc/pam.d/system-password <<'PY'
import sys
lines = [line.strip() for line in open(sys.argv[1], encoding='utf-8') if line.strip() and not line.lstrip().startswith('#')]
assert len(lines) == 2, lines
assert lines[0].startswith('password required pam_pwquality.so '), lines[0]
assert lines[1] == 'password required pam_unix.so yescrypt shadow try_first_pass', lines[1]
assert 'dictpath=/usr/lib/cracklib/pw_dict' in lines[0]
PY
ldd_output="$(ldd /usr/lib/security/pam_pwquality.so)"
printf '%s\n' "$ldd_output"
[[ "$ldd_output" != *'not found'* ]]
printf 'LIBPWQUALITY_FINAL_INSTALL=PASS\n'
LIBPWQUALITY_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/libpwquality-$VERSION-$STAMP.package.log"
printf 'LIBPWQUALITY_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LOG_DIR/libpwquality-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/libpwquality-$VERSION-$STAMP.package.status"
printf 'libpwquality %s installed and system-password PAM policy updated; no password was created/changed, test suite and checksum calculation were skipped.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
