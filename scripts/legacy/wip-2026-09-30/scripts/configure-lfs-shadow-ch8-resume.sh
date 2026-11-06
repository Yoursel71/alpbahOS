#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly BUILD_LOG="$DATA/logs/lfs-12.4-systemd/shadow-ch8-20260926T214925458560984Z.log"
readonly ACCOUNT_BACKUP="$DATA/logs/lfs-12.4-systemd/shadow-account-files-before-20260926T214925458560984Z"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="$LOG_DIR/shadow-configure-resume-$STAMP.log"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
[[ -f "$BUILD_LOG" && -f "$ACCOUNT_BACKUP/passwd" && -f "$ACCOUNT_BACKUP/group" ]] || fail 'The Shadow install log or pre-install account file copies are missing.'
rg -q '^shadow-4.18.0.tar.xz: OK$' "$BUILD_LOG" || fail 'The official Shadow source checksum did not pass.'
rg -q 'install -c passwd /usr/bin/passwd' "$BUILD_LOG" || fail 'The Shadow command install output is not recorded.'
rg -q "'/usr/share/man/man1'" "$BUILD_LOG" || fail 'The Shadow man-page install output is not recorded.'
cmp -s "$ACCOUNT_BACKUP/passwd" "$LFS/etc/passwd" || fail 'The current passwd file changed since its backup; inspect before conversion.'
cmp -s "$ACCOUNT_BACKUP/group" "$LFS/etc/group" || fail 'The current group file changed since its backup; inspect before conversion.'
for path in "$LFS/usr/bin/passwd" "$LFS/usr/bin/login" "$LFS/usr/sbin/useradd" "$LFS/usr/sbin/usermod" "$LFS/usr/sbin/pwconv" "$LFS/usr/sbin/grpconv" "$LFS/usr/include/shadow" "$LFS/etc/login.defs"; do
    [[ -e "$path" || -L "$path" ]] || fail "Required Shadow installation path is missing: $path"
done
for path in "$LFS/etc/shadow" "$LFS/etc/gshadow" "$LFS/etc/default/useradd"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Account setup already exists; refusing to repeat conversion: $path"
done
grep -Eq '^[[:space:]]*ENCRYPT_METHOD[[:space:]]+YESCRYPT([[:space:]]|$)' "$LFS/etc/login.defs" || fail 'YESCRYPT was not selected in installed login.defs.'
grep -Eq '^[[:space:]]*MAIL_DIR[[:space:]]+/var/mail([[:space:]]|$)' "$LFS/etc/login.defs" || fail 'The mailbox directory was not set to /var/mail.'
awk -F: '$1 == "users" && $3 == 999 { found=1 } END { exit found ? 0 : 1 }' "$LFS/etc/group" || fail 'The LFS users group with GID 999 is missing.'
if ps -eo comm= | awk '$1 == "pwconv" || $1 == "grpconv" || $1 == "useradd" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another account conversion process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1

printf 'Completing standard LFS Shadow account setup.\n'
printf 'Pre-install passwd/group copies: %s\nStarted: %s\n\n' "$ACCOUNT_BACKUP" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        pwconv
        grpconv
        mkdir -p /etc/default
        useradd -D --gid 999
        test -s /etc/shadow
        test -s /etc/gshadow
        test -s /etc/default/useradd
        grep -Fx "GROUP=999" /etc/default/useradd >/dev/null
        grep -Fx "CREATE_MAIL_SPOOL=yes" /etc/default/useradd >/dev/null
        printf "SHADOW_ACCOUNT_SETUP=PASS\\n"
        printf "ROOT_SHADOW_ENTRY="
        awk -F: '\''$1 == "root" { print $2 }'\'' /etc/shadow
    ' shadow-configure-resume

printf '\nFinished: %s\nStatus: PASS\nRoot password: not set\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
