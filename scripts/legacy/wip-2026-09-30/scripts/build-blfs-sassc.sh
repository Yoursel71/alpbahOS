#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SASSC_VERSION=3.6.2
readonly LIBSASS_VERSION=3.6.6
readonly SASSC_ARCHIVE="sassc-$SASSC_VERSION.tar.gz"
readonly LIBSASS_ARCHIVE="libsass-$LIBSASS_VERSION.tar.gz"
readonly SASSC_URL="https://github.com/sass/sassc/archive/$SASSC_VERSION/$SASSC_ARCHIVE"
readonly LIBSASS_URL="https://github.com/sass/libsass/archive/$LIBSASS_VERSION/$LIBSASS_ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/sassc-$SASSC_VERSION-blfs-$STAMP"
readonly SASSC_SOURCE="$WORK/sassc-$SASSC_VERSION"
readonly LIBSASS_SOURCE="$SASSC_SOURCE/libsass-$LIBSASS_VERSION"
readonly LIBSASS_STAGE="$WORK/libsass-stage"
readonly SASSC_STAGE="$WORK/sassc-stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/sassc-$SASSC_VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/sassc-$SASSC_VERSION-$STAMP.status"
readonly LIBSASS_BACKUP="$DATA/backups/libsass-$LIBSASS_VERSION-before-final-$STAMP"
readonly SASSC_BACKUP="$DATA/backups/sassc-$SASSC_VERSION-before-final-$STAMP"
readonly SASSC_ARCHIVE_PATH="$LFS/sources/$SASSC_ARCHIVE"
readonly LIBSASS_ARCHIVE_PATH="$LFS/sources/$LIBSASS_ARCHIVE"
readonly SASSC_TEMP_DOWNLOAD="$DATA/downloads/$SASSC_ARCHIVE.partial-$STAMP"
readonly LIBSASS_TEMP_DOWNLOAD="$DATA/downloads/$LIBSASS_ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the expected HDD directory.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '
    [[ -x /usr/bin/make && -x /usr/bin/autoreconf && -x /usr/bin/pkg-config && -x /usr/bin/g++ ]]
    if [[ -e /usr/lib/libsass.so ]]; then
        [[ -f /usr/lib/pkgconfig/libsass.pc && -f /usr/include/sass/context.h ]]
    else
        [[ ! -e /usr/include/sass && ! -e /usr/bin/sassc ]]
    fi
' || fail 'SassC build tools are missing or libsass has an incomplete installation.'

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$LIBSASS_BACKUP" "$SASSC_BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'SASSC_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'SASSC_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'BLFS 12.4 libsass %s + SassC %s; both packages have no test suite; checksum calculations skipped.\n' "$LIBSASS_VERSION" "$SASSC_VERSION"
if ! sudo -n test -r "$SASSC_ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$SASSC_TEMP_DOWNLOAD" "$SASSC_URL"
    sudo -n install -o 0 -g 0 -m 0644 "$SASSC_TEMP_DOWNLOAD" "$SASSC_ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$SASSC_ARCHIVE_PATH"; fi
if ! sudo -n test -r "$LIBSASS_ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$LIBSASS_TEMP_DOWNLOAD" "$LIBSASS_URL"
    sudo -n install -o 0 -g 0 -m 0644 "$LIBSASS_TEMP_DOWNLOAD" "$LIBSASS_ARCHIVE_PATH"
else printf 'Using retained libsass archive: %s\n' "$LIBSASS_ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$SASSC_ARCHIVE" "$LIBSASS_ARCHIVE" "$WORK" "$SASSC_SOURCE" "$LIBSASS_SOURCE" "$LIBSASS_STAGE" "$PACKAGE_LOG" <<'SASSC_LIBSASS_BUILD'
set -Eeuo pipefail
sassc_archive="$1"; libsass_archive="$2"; work="$3"; sassc_source="$4"; libsass_source="$5"; stage="$6"; package_log="$7"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$sassc_archive" -C "$work"
tar -xf "/sources/$libsass_archive" -C "$sassc_source"
[[ -f "$sassc_source/configure.ac" && -f "$libsass_source/configure.ac" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin SASSC_SOURCE='$sassc_source' LIBSASS_SOURCE='$libsass_source' SASSC_WORK='$work' LIBSASS_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_LIBSASS_BUILD'
set -Eeuo pipefail
if [[ ! -e /usr/lib/libsass.so ]]; then
    mkdir -pv "$LIBSASS_STAGE"
    cd "$LIBSASS_SOURCE"
    autoreconf -fi > "$SASSC_WORK/libsass-autoreconf.log" 2>&1 || { tail -n 100 "$SASSC_WORK/libsass-autoreconf.log"; exit 1; }
    ./configure --prefix=/usr --disable-static > "$SASSC_WORK/libsass-configure.log" 2>&1 || { tail -n 100 "$SASSC_WORK/libsass-configure.log"; exit 1; }
    make -j4 > "$SASSC_WORK/libsass-compile.log" 2>&1 || { tail -n 120 "$SASSC_WORK/libsass-compile.log"; exit 1; }
    DESTDIR="$LIBSASS_STAGE" make install > "$SASSC_WORK/libsass-stage-install.log" 2>&1 || { tail -n 100 "$SASSC_WORK/libsass-stage-install.log"; exit 1; }
    [[ -s "$LIBSASS_STAGE/usr/lib/libsass.so" && -f "$LIBSASS_STAGE/usr/lib/pkgconfig/libsass.pc" && -f "$LIBSASS_STAGE/usr/include/sass/context.h" ]]
    printf 'LIBSASS_STAGE=PASS\n'
else
    printf 'LIBSASS_ALREADY_INSTALLED=PASS\n'
fi
UNPRIVILEGED_LIBSASS_BUILD
SASSC_LIBSASS_BUILD

if ! sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -s /usr/lib/libsass.so && -f /usr/lib/pkgconfig/libsass.pc ]]'; then
    sudo -n find "$LFS$LIBSASS_STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$LIBSASS_BACKUP/staged-paths.list0"
    python3 - "$LFS" "$LIBSASS_BACKUP/staged-paths.list0" "$LIBSASS_BACKUP/preexisting-paths.list0" <<'PY'
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
print(f'libsass staged paths: {len(paths)}; existing target paths: {len(set(old))}')
PY
    if [[ -s "$LIBSASS_BACKUP/preexisting-paths.list0" ]]; then
        sudo -n tar --create --file="$LIBSASS_BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$LIBSASS_BACKUP/preexisting-paths.list0"
        sudo -n chown "$(id -u):$(id -g)" "$LIBSASS_BACKUP/preexisting-files.tar"
        sudo -n tar --list --file="$LIBSASS_BACKUP/preexisting-files.tar" > "$LIBSASS_BACKUP/archive.list"
        [[ -s "$LIBSASS_BACKUP/archive.list" ]] || fail 'libsass pre-install backup is empty.'
    else printf 'No existing libsass targets required an archive.\n' > "$LIBSASS_BACKUP/no-preexisting-files.txt"; fi
    sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
        /bin/bash -s -- "$LIBSASS_SOURCE" "$PACKAGE_LOG" <<'LIBSASS_FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cd "$source"
make install
ldconfig
[[ -s /usr/lib/libsass.so && -f /usr/lib/pkgconfig/libsass.pc && -f /usr/include/sass/context.h ]]
printf 'LIBSASS_FINAL_INSTALL=PASS\n'
LIBSASS_FINAL_INSTALL
else
    printf 'libsass is already installed; it will not be rewritten.\n' > "$LIBSASS_BACKUP/already-installed.txt"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$SASSC_SOURCE" "$WORK" "$SASSC_STAGE" "$PACKAGE_LOG" <<'SASSC_BUILD_STAGE'
set -Eeuo pipefail
source="$1"; work="$2"; stage="$3"; package_log="$4"
exec > >(tee -a "$package_log") 2>&1
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin SASSC_SOURCE='$source' SASSC_WORK='$work' SASSC_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_SASSC_BUILD'
set -Eeuo pipefail
[[ -s /usr/lib/libsass.so && -f /usr/lib/pkgconfig/libsass.pc ]]
cd "$SASSC_SOURCE"
autoreconf -fi > "$SASSC_WORK/sassc-autoreconf.log" 2>&1 || { tail -n 100 "$SASSC_WORK/sassc-autoreconf.log"; exit 1; }
./configure --prefix=/usr > "$SASSC_WORK/sassc-configure.log" 2>&1 || { tail -n 120 "$SASSC_WORK/sassc-configure.log"; exit 1; }
make -j4 > "$SASSC_WORK/sassc-compile.log" 2>&1 || { tail -n 120 "$SASSC_WORK/sassc-compile.log"; exit 1; }
mkdir -pv "$SASSC_STAGE"
DESTDIR="$SASSC_STAGE" make install > "$SASSC_WORK/sassc-stage-install.log" 2>&1 || { tail -n 100 "$SASSC_WORK/sassc-stage-install.log"; exit 1; }
[[ -x "$SASSC_STAGE/usr/bin/sassc" ]]
UNPRIVILEGED_SASSC_BUILD
chown -R 0:0 "$stage"
[[ -x "$stage/usr/bin/sassc" ]]
printf 'SASSC_STAGE=PASS\n'
SASSC_BUILD_STAGE
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/sassc-$SASSC_VERSION-$STAMP.package.log"
sudo -n find "$LFS$SASSC_STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$SASSC_BACKUP/staged-paths.list0"
python3 - "$LFS" "$SASSC_BACKUP/staged-paths.list0" "$SASSC_BACKUP/preexisting-paths.list0" <<'PY'
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
print(f'sassc staged paths: {len(paths)}; existing target paths: {len(set(old))}')
PY
if [[ -s "$SASSC_BACKUP/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$SASSC_BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$SASSC_BACKUP/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$SASSC_BACKUP/preexisting-files.tar"
    sudo -n tar --list --file="$SASSC_BACKUP/preexisting-files.tar" > "$SASSC_BACKUP/archive.list"
    [[ -s "$SASSC_BACKUP/archive.list" ]] || fail 'SassC pre-install backup is empty.'
else printf 'No existing SassC targets required an archive.\n' > "$SASSC_BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$SASSC_SOURCE" "$WORK" "$PACKAGE_LOG" <<'SASSC_FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; work="$2"; package_log="$3"
exec > >(tee -a "$package_log") 2>&1
cd "$source"
make install
ldconfig
[[ -x /usr/bin/sassc && -s /usr/lib/libsass.so && -f /usr/include/sass/context.h ]]
pkg-config --exists libsass
ldd_output="$(ldd /usr/bin/sassc)"
printf '%s\n' "$ldd_output"
[[ "$ldd_output" != *'not found'* && "$ldd_output" != *"$work"* ]]
if ! grep -Fq 'libsass.so.1 => /usr/lib/libsass.so.1 ' <<< "$ldd_output" &&
   ! grep -Fq 'libsass.so.1 => /usr/lib/../lib/libsass.so.1 ' <<< "$ldd_output"; then
    printf 'SassC did not resolve libsass from the LFS /usr/lib hierarchy.\n' >&2
    exit 1
fi
printf 'SASSC_FINAL_INSTALL=PASS\n'
SASSC_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/sassc-$SASSC_VERSION-$STAMP.package.log"
printf 'SASSC_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nLIBSASS_BACKUP_DIR=%s\nSASSC_BACKUP_DIR=%s\n' "$LOG" "$LOG_DIR/sassc-$SASSC_VERSION-$STAMP.package.log" "$LFS$WORK" "$LIBSASS_BACKUP" "$SASSC_BACKUP" > "$LOG_DIR/sassc-$SASSC_VERSION-$STAMP.package.status"
printf 'libsass %s and SassC %s installed; binary resolves libsass from /usr/lib; no package test suite or checksum calculation was run.\nLog: %s\nStatus: %s\n' "$LIBSASS_VERSION" "$SASSC_VERSION" "$LOG" "$STATUS"
