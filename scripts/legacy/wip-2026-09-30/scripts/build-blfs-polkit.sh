#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=126
readonly ARCHIVE="polkit-$VERSION.tar.gz"
readonly URL="https://github.com/polkit-org/polkit/archive/$VERSION/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/polkit-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/polkit-$VERSION"
readonly BUILD="$WORK/build"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/polkit-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/polkit-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/polkit-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi

sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -s <<'POLKIT_PREFLIGHT'
set -Eeuo pipefail
for pair in 'glib-2.0=2.84.4' 'gio-2.0=2.84.4' 'gio-unix-2.0=2.84.4' 'pam=1.7.1' 'libsystemd=257' 'duktape=2.7.0'; do
    name=${pair%%=*}; expected=${pair#*=}
    [[ "$(pkg-config --modversion "$name")" == "$expected" ]]
done
pkg-config --modversion dbus-1 >/dev/null
pkg-config --modversion expat >/dev/null
[[ -f /usr/include/security/pam_appl.h && -f /usr/lib/libpam.so ]]
[[ -f /usr/lib/libduktape.so && -f /usr/include/duktape.h ]]
[[ -f /etc/pam.d/polkit-1 && -f /etc/pam.d/system-auth && -f /etc/pam.d/system-session ]]
[[ -x /usr/bin/meson && -x /usr/bin/ninja && -x /usr/sbin/useradd && -x /usr/sbin/groupadd ]]
if getent group polkitd >/dev/null || getent group 27 >/dev/null || getent passwd polkitd >/dev/null || getent passwd 27 >/dev/null; then
    printf 'polkitd name or UID/GID 27 is already occupied; refusing to alter account records.\n' >&2
    exit 1
fi
POLKIT_PREFLIGHT

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'POLKIT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'POLKIT_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

printf 'BLFS 12.4 Polkit %s; no test suite or checksum calculation.\n' "$VERSION"
printf 'Source: %s\nStarted: %s\n' "$URL" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else
    printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" "$PACKAGE_LOG" <<'POLKIT_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; package_log="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior build tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/meson.build" && -f "$source/meson_options.txt" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX POLKIT_SOURCE='$source' POLKIT_BUILD='$build' POLKIT_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
mkdir -pv "$POLKIT_BUILD"
meson setup "$POLKIT_BUILD" "$POLKIT_SOURCE" \
    --prefix=/usr --buildtype=release -Dman=false -Dsession_tracking=logind \
    -Dos_type=lfs -Dauthfw=pam -Dintrospection=false -Dexamples=false \
    -Dgtk_doc=false -Dtests=false -Dgettext=false \
    -Dsystemdsystemunitdir=/usr/lib/systemd/system -Dpam_prefix=/etc/pam.d \
    | tee "$POLKIT_BUILD/configure.log"
grep -F 'Authentication framework: pam' "$POLKIT_BUILD/configure.log"
grep -E 'Session tracking:[[:space:]]+logind' "$POLKIT_BUILD/configure.log"
grep -E 'PAM config location:[[:space:]]+/etc/pam[.]d' "$POLKIT_BUILD/configure.log"
ninja -C "$POLKIT_BUILD" -j4 > "$POLKIT_BUILD/compile.log" 2>&1 || { tail -n 120 "$POLKIT_BUILD/compile.log"; exit 1; }
DESTDIR="$POLKIT_STAGE" ninja -C "$POLKIT_BUILD" install > "$POLKIT_BUILD/staged-install.log" 2>&1 || { tail -n 120 "$POLKIT_BUILD/staged-install.log"; exit 1; }
[[ -x "$POLKIT_STAGE/usr/bin/pkexec" && -x "$POLKIT_STAGE/usr/lib/polkit-1/polkitd" ]]
[[ -f "$POLKIT_STAGE/etc/pam.d/polkit-1" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
[[ -n "$(find "$stage" \( -type f -o -type l \) -print -quit)" ]]
printf 'POLKIT_STAGE=PASS\n'
POLKIT_BUILD_STAGE
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/polkit-$VERSION-$STAMP.package.log"

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
print(f'Staged paths: {len(staged)}; existing target paths: {len(set(existing))}')
PY
if [[ -s "$BACKUP/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
    [[ -s "$BACKUP/archive.list" ]] || fail 'The Polkit pre-install backup is empty.'
else
    printf 'No existing Polkit package targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"
fi

install -d -m 0700 "$BACKUP/account-files"
for name in passwd group shadow gshadow subuid subgid; do
    if sudo -n test -f "$LFS/etc/$name"; then
        sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0600 "$LFS/etc/$name" "$BACKUP/account-files/$name"
    fi
done
[[ -s "$BACKUP/account-files/passwd" && -s "$BACKUP/account-files/group" ]]
printf 'Protected pre-account-creation snapshots: %s\n' "$(find "$BACKUP/account-files" -maxdepth 1 -type f | wc -l)"

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -s <<'POLKIT_ACCOUNT'
set -Eeuo pipefail
if getent group polkitd >/dev/null || getent group 27 >/dev/null || getent passwd polkitd >/dev/null || getent passwd 27 >/dev/null; then
    printf 'polkitd name or UID/GID 27 became occupied; refusing account creation.\n' >&2
    exit 1
fi
groupadd -g 27 polkitd
useradd -M -c 'PolicyKit Daemon Owner' -d /etc/polkit-1 -u 27 -g polkitd -s /bin/false polkitd
[[ "$(getent group polkitd)" == 'polkitd:x:27:' ]]
[[ "$(getent passwd polkitd)" == 'polkitd:x:27:27:PolicyKit Daemon Owner:/etc/polkit-1:/bin/false' ]]
printf 'POLKITD_ACCOUNT=PASS uid=27 gid=27 no-home=no-password\n'
POLKIT_ACCOUNT

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$BUILD" "$PACKAGE_LOG" <<'POLKIT_FINAL_INSTALL'
set -Eeuo pipefail
build="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
ninja -C "$build" install
ldconfig
pkg-config --exists polkit-agent-1 polkit-gobject-1
[[ "$(pkg-config --modversion polkit-agent-1)" == 126 ]]
[[ -x /usr/bin/pkexec && -x /usr/bin/pkaction && -x /usr/bin/pkcheck && -x /usr/bin/pkttyagent ]]
[[ -x /usr/lib/polkit-1/polkitd && -x /usr/lib/polkit-1/polkit-agent-helper-1 ]]
[[ -f /usr/lib/systemd/system/polkit.service ]]
[[ -f /usr/share/dbus-1/system-services/org.freedesktop.PolicyKit1.service ]]
[[ -f /usr/lib/sysusers.d/polkit.conf && -f /usr/lib/tmpfiles.d/polkit-tmpfiles.conf ]]
[[ -f /etc/pam.d/polkit-1 && -x /usr/lib/security/pam_systemd.so ]]
[[ "$(stat -c '%a:%u' /usr/bin/pkexec)" == '4755:0' ]]
[[ "$(stat -c '%a:%u' /usr/lib/polkit-1/polkit-agent-helper-1)" == '4755:0' ]]
[[ "$(stat -c '%a:%g' /etc/polkit-1/rules.d)" == '750:27' ]]
ldd /usr/bin/pkexec | grep -F 'libpam.so'
ldd /usr/lib/polkit-1/polkitd | grep -F 'libsystemd.so'
! ldd /usr/bin/pkexec /usr/lib/polkit-1/polkitd | grep -F 'not found'
printf 'POLKIT_FINAL_INSTALL=PASS\nPOLKIT_AUTHFW=pam\nPOLKIT_SESSION_TRACKING=logind\n'
POLKIT_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/polkit-$VERSION-$STAMP.package.log"
printf 'POLKIT_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\nACCOUNT_SNAPSHOT=%s\n' \
    "$LOG" "$LOG_DIR/polkit-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" "$BACKUP/account-files" > "$LOG_DIR/polkit-$VERSION-$STAMP.package.status"
printf 'Polkit %s installed with PAM/logind; package tests and checksum calculations were skipped.\n' "$VERSION"
printf 'Log: %s\nStatus: %s\nBackup: %s\nFinished: %s\n' "$LOG" "$STATUS" "$BACKUP" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
