#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly VERSION=1.7.1
readonly ARCHIVE="Linux-PAM-$VERSION.tar.xz"
readonly URL="https://github.com/linux-pam/linux-pam/releases/download/v$VERSION/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/linux-pam-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/Linux-PAM-$VERSION"
readonly BUILD="$SOURCE/build"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/linux-pam-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/linux-pam-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/linux-pam-$VERSION-before-final-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the expected HDD directory.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'LINUX_PAM_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'LINUX_PAM_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

printf 'BLFS 12.4 Linux-PAM %s source/build/install. Package test suites and checksum calculations are skipped.\n' "$VERSION"
printf 'Source: %s\nTarget: %s\nStarted: %s\n' "$URL" "$LFS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else
    printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" "$PACKAGE_LOG" <<'PAM_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; package_log="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior build tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/meson.build" && -f "$source/meson_options.txt" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX PAM_SOURCE='$source' PAM_BUILD='$build' PAM_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
source="$PAM_SOURCE"; build="$PAM_BUILD"; stage="$PAM_STAGE"
mkdir -pv "$build" "$stage"
meson setup "$build" "$source" \
    --prefix=/usr \
    --buildtype=release \
    -D docdir=/usr/share/doc/Linux-PAM-1.7.1 > "${build%/build}/configure.log" 2>&1 || {
        tail -n 100 "${build%/build}/configure.log"; exit 1;
    }
ninja -C "$build" -j4 > "${build%/build}/compile.log" 2>&1 || {
    tail -n 120 "${build%/build}/compile.log"; exit 1;
}
DESTDIR="$stage" ninja -C "$build" install > "${build%/build}/staged-install.log" 2>&1 || {
    tail -n 100 "${build%/build}/staged-install.log"; exit 1;
}
[[ -f "$stage/usr/include/security/pam_appl.h" ]]
[[ -f "$stage/usr/lib/libpam.so" && -f "$stage/usr/lib/security/pam_unix.so" ]]
[[ -x "$stage/usr/sbin/unix_chkpwd" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
[[ -n "$(find "$stage" \( -type f -o -type l \) -print -quit)" ]]
printf 'LINUX_PAM_STAGE=PASS\n'
PAM_BUILD_STAGE
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/linux-pam-$VERSION-$STAMP.package.log"

sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged-paths.list0"
python3 - "$LFS" "$BACKUP/staged-paths.list0" "$BACKUP/preexisting-paths.list0" <<'PY'
import os, sys
root, staged_path, existing_path = sys.argv[1:]
with open(staged_path, 'rb') as stream:
    staged = [p for p in stream.read().split(b'\0') if p]
existing = []
for raw in staged:
    rel = os.fsdecode(raw)
    if os.path.isabs(rel) or '..' in rel.split('/'):
        raise SystemExit(f'Unsafe staged path: {rel!r}')
    if os.path.lexists(os.path.join(root, rel)):
        existing.append(raw)
with open(existing_path, 'wb') as stream:
    for raw in sorted(set(existing)):
        stream.write(raw + b'\0')
print(f'Staged paths: {len(staged)}; pre-existing target files to archive: {len(set(existing))}')
PY
if [[ -s "$BACKUP/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
    [[ -s "$BACKUP/archive.list" ]] || fail 'The pre-install backup archive is empty.'
else
    printf 'No staged Linux-PAM target file was present before install.\n' > "$BACKUP/no-preexisting-files.txt"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$BUILD" "$PACKAGE_LOG" <<'PAM_FINAL_INSTALL'
set -Eeuo pipefail
build="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
ninja -C "$build" install
chmod -v 4755 /usr/sbin/unix_chkpwd
ldconfig
[[ -f /usr/include/security/pam_appl.h ]]
[[ -f /usr/lib/libpam.so && -f /usr/lib/libpam.so.0 ]]
[[ -f /usr/lib/security/pam_unix.so && -x /usr/sbin/unix_chkpwd ]]
[[ -d /etc/security && -f /etc/environment ]]
[[ "$(stat -c '%a' /usr/sbin/unix_chkpwd)" == 4755 ]]
printf 'LINUX_PAM_FINAL_INSTALL=PASS\n'
PAM_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/linux-pam-$VERSION-$STAMP.package.log"
printf 'LINUX_PAM_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' \
    "$LOG" "$LOG_DIR/linux-pam-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/linux-pam-$VERSION-$STAMP.package.status"
printf 'Linux-PAM %s installed. No test suite or checksum calculation ran; source/build/stage and prior target-file archive retained.\n' "$VERSION"
printf 'Log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
