#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly VERSION=4.18.0
readonly ARCHIVE="shadow-$VERSION.tar.xz"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/shadow-$VERSION-pam-rebuild-$STAMP"
readonly SOURCE="$WORK/shadow-$VERSION"
readonly BUILD="$SOURCE/build"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/shadow-$VERSION-pam-rebuild-$STAMP.log"
readonly STATUS="$LOG_DIR/shadow-$VERSION-pam-rebuild-$STAMP.status"
readonly BACKUP="$DATA/backups/shadow-$VERSION-before-pam-rebuild-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the expected HDD directory.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n test -r "$LFS/sources/$ARCHIVE" || fail "The retained source archive is missing: $ARCHIVE"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '
    [[ "$(pkg-config --modversion pam)" == 1.7.1 ]]
    [[ -f /usr/include/security/pam_appl.h && -f /usr/lib/security/pam_systemd.so ]]
    [[ -x /usr/bin/login && -x /usr/bin/passwd && -x /usr/bin/su ]]
' || fail 'Linux-PAM, PAM-enabled Systemd, and the current Shadow tools are required.'
for f in passwd group shadow gshadow; do [[ -s "$LFS/etc/$f" ]] || fail "Missing account database /etc/$f"; done
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP/account-files"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'SHADOW_PAM_REBUILD_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'SHADOW_PAM_REBUILD_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

printf 'Rebuilding BLFS 12.4 Shadow %s with Linux-PAM support. No package test suite or checksum calculation.\n' "$VERSION"
printf 'The active account databases are snapshotted and compared unchanged across install.\n'
for f in passwd group shadow gshadow; do sudo -n cp -p "$LFS/etc/$f" "$BACKUP/account-files/$f"; done

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" "$PACKAGE_LOG" <<'SHADOW_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; package_log="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior build tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -x "$source/configure" && -f "$source/src/Makefile.in" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX SHADOW_SOURCE='$source' SHADOW_BUILD='$build' SHADOW_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
source="$SHADOW_SOURCE"; build="$SHADOW_BUILD"; stage="$SHADOW_STAGE"
cd "$source"
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} +
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} +
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} +
sed -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD YESCRYPT@' \
    -e 's@/var/spool/mail@/var/mail@' \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' -i etc/login.defs
mkdir -pv "$build"
cd "$build"
"$source/configure" \
    --sysconfdir=/etc \
    --disable-static \
    --without-libbsd \
    --with-bcrypt \
    --with-yescrypt \
    --with-libpam \
    --with-group-name-max-length=32 > "${build%/build}/configure.log" 2>&1 || {
        tail -n 100 "${build%/build}/configure.log"; exit 1;
    }
grep -Ei 'pam[^[:alnum:]]+yes|pam[^[:alnum:]]+enabled|pam_start' "${build%/build}/configure.log" >/dev/null
make -j4 > "${build%/build}/compile.log" 2>&1 || {
    tail -n 120 "${build%/build}/compile.log"; exit 1;
}
mkdir -pv "$stage"
make -j1 exec_prefix=/usr pamddir= DESTDIR="$stage" install > "${build%/build}/staged-install.log" 2>&1 || {
    tail -n 100 "${build%/build}/staged-install.log"; exit 1;
}
make -j1 -C "$build/man" pamddir= DESTDIR="$stage" install-man >> "${build%/build}/staged-install.log" 2>&1 || {
    tail -n 100 "${build%/build}/staged-install.log"; exit 1;
}
[[ -x "$stage/usr/bin/login" && -x "$stage/usr/bin/passwd" && -x "$stage/usr/bin/su" ]]
[[ -f "$stage/etc/login.defs" && -f "$stage/usr/share/man/man1/login.1" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
[[ -n "$(find "$stage" \( -type f -o -type l \) -print -quit)" ]]
printf 'SHADOW_PAM_STAGE=PASS\n'
SHADOW_BUILD_STAGE
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/shadow-$VERSION-pam-rebuild-$STAMP.package.log"

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
print(f'Staged paths: {len(staged)}; existing target paths to archive: {len(set(existing))}')
PY
if [[ -s "$BACKUP/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
    [[ -s "$BACKUP/archive.list" ]] || fail 'The Shadow pre-install archive is empty.'
else
    printf 'No staged Shadow target paths needed an archive.\n' > "$BACKUP/no-preexisting-files.txt"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$BUILD" "$PACKAGE_LOG" <<'SHADOW_FINAL_INSTALL'
set -Eeuo pipefail
build="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
make -C "$build" -j1 exec_prefix=/usr pamddir= install
make -j1 -C "$build/man" pamddir= install-man
ldconfig
[[ -x /usr/bin/login && -x /usr/bin/passwd && -x /usr/bin/su ]]
[[ "$(pkg-config --modversion pam)" == 1.7.1 ]]
readelf -Ws /usr/bin/login | grep -E 'UND[[:space:]]+pam_start(@|$)' >/dev/null
readelf -d /usr/bin/login | grep -F 'libpam.so.0' >/dev/null
[[ -s /etc/login.defs && -s /etc/passwd && -s /etc/group && -s /etc/shadow && -s /etc/gshadow ]]
printf 'SHADOW_PAM_FINAL_INSTALL=PASS\n'
SHADOW_FINAL_INSTALL
for f in passwd group shadow gshadow; do sudo -n cmp -s "$BACKUP/account-files/$f" "$LFS/etc/$f" || fail "Shadow changed /etc/$f during reinstall."; done
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/shadow-$VERSION-pam-rebuild-$STAMP.package.log"
printf 'SHADOW_PAM_REBUILD_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\nACCOUNT_DATABASES=UNCHANGED\n' \
    "$LOG" "$LOG_DIR/shadow-$VERSION-pam-rebuild-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/shadow-$VERSION-pam-rebuild-$STAMP.package.status"
printf 'Shadow %s rebuilt with PAM support. Account databases are byte-for-byte unchanged. No package test suite or checksum calculation ran.\n' "$VERSION"
printf 'Log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
