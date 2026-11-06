#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/pam-stack-$STAMP.log"
readonly STATUS="$LOG_DIR/pam-stack-$STAMP.status"
readonly BACKUP="$DATA/backups/pam-stack-before-config-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the expected HDD directory.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '
    [[ "$(pkg-config --modversion pam)" == 1.7.1 ]]
    [[ -f /usr/lib/security/pam_systemd.so && -f /usr/lib/security/pam_unix.so ]]
    [[ -x /usr/bin/login && -x /usr/bin/su && -s /etc/login.defs ]]
' || fail 'PAM-enabled Linux-PAM, Systemd, and Shadow are required.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'PAM_STACK_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'PAM_STACK_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '
    [[ ! -e /etc/login.defs.orig ]]
    [[ ! -d /etc/pam.d ]] || ! find /etc/pam.d -mindepth 1 -print -quit | grep -q .
    for f in login passwd su system-account system-auth system-session system-password systemd-user polkit-1; do
        [[ ! -e "/etc/pam.d/$f" && ! -L "/etc/pam.d/$f" ]]
    done
' || fail 'Existing PAM policy was found; preserving it without overwrite.'

printf 'etc/login.defs\0' > "$BACKUP/preexisting-paths.list0"
if sudo -n test -d "$LFS/etc/pam.d"; then
    sudo -n find "$LFS/etc/pam.d" -mindepth 1 -printf 'etc/pam.d/%P\0' >> "$BACKUP/preexisting-paths.list0"
fi
sudo -n tar --create --file="$BACKUP/preexisting-pam-config.tar" --numeric-owner --acls --xattrs \
    -C "$LFS" --null --files-from="$BACKUP/preexisting-paths.list0"
sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-pam-config.tar"
sudo -n tar --list --file="$BACKUP/preexisting-pam-config.tar" > "$BACKUP/archive.list"
[[ -s "$BACKUP/archive.list" ]] || fail 'PAM configuration backup is empty.'

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -s <<'PAM_CONFIG'
set -Eeuo pipefail
install -v -m 0644 /etc/login.defs /etc/login.defs.orig
for FUNCTION in FAIL_DELAY FAILLOG_ENAB LASTLOG_ENAB MAIL_CHECK_ENAB \
                OBSCURE_CHECKS_ENAB PORTTIME_CHECKS_ENAB QUOTAS_ENAB \
                CONSOLE MOTD_FILE FTMP_FILE NOLOGINS_FILE ENV_HZ PASS_MIN_LEN \
                SU_WHEEL_ONLY PASS_CHANGE_TRIES PASS_ALWAYS_WARN \
                CHFN_AUTH ENCRYPT_METHOD ENVIRON_FILE; do
    sed -i "s/^${FUNCTION}/# &/" /etc/login.defs
done

install -v -d -m 0755 /etc/pam.d
cat > /etc/pam.d/other <<'EOF'
# Deny PAM services without an explicit policy.
auth        required    pam_deny.so
account     required    pam_deny.so
password    required    pam_deny.so
session     required    pam_deny.so
EOF
cat > /etc/pam.d/system-account <<'EOF'
account     required    pam_unix.so
EOF
cat > /etc/pam.d/system-auth <<'EOF'
auth        required    pam_unix.so
EOF
cat > /etc/pam.d/system-password <<'EOF'
password    required    pam_unix.so yescrypt shadow try_first_pass
EOF
cat > /etc/pam.d/system-session <<'EOF'
session     required    pam_unix.so
session     required    pam_loginuid.so
session     optional    pam_systemd.so
EOF
cat > /etc/pam.d/login <<'EOF'
auth        optional    pam_faildelay.so delay=3000000
auth        requisite   pam_nologin.so
auth        include     system-auth
account     include     system-account
session     required    pam_env.so
session     required    pam_limits.so
session     include     system-session
password    include     system-password
EOF
cat > /etc/pam.d/passwd <<'EOF'
password    include     system-password
EOF
cat > /etc/pam.d/su <<'EOF'
auth        sufficient  pam_rootok.so
auth        include     system-auth
account     include     system-account
session     required    pam_env.so
session     include     system-session
EOF
cat > /etc/pam.d/chpasswd <<'EOF'
auth        sufficient  pam_rootok.so
auth        include     system-auth
account     include     system-account
password    include     system-password
EOF
sed 's/chpasswd/newusers/' /etc/pam.d/chpasswd > /etc/pam.d/newusers
cat > /etc/pam.d/chage <<'EOF'
auth        sufficient  pam_rootok.so
auth        include     system-auth
account     include     system-account
EOF
for PROGRAM in chfn chgpasswd chsh groupadd groupdel groupmems groupmod useradd userdel usermod; do
    sed "s/chage/$PROGRAM/" /etc/pam.d/chage > "/etc/pam.d/$PROGRAM"
done
cat > /etc/pam.d/systemd-user <<'EOF'
account     include     system-account
session     required    pam_env.so
session     required    pam_limits.so
session     required    pam_loginuid.so
session     optional    pam_keyinit.so force revoke
session     optional    pam_systemd.so
auth        required    pam_deny.so
password    required    pam_deny.so
EOF
cat > /etc/pam.d/polkit-1 <<'EOF'
auth        include     system-auth
account     include     system-account
password    include     system-password
session     include     system-session
EOF
chmod -v 0644 /etc/pam.d/*

[[ -f /etc/login.defs.orig && -f /etc/pam.d/login && -f /etc/pam.d/su ]]
[[ -f /etc/pam.d/systemd-user && -f /etc/pam.d/polkit-1 ]]
grep -F 'pam_systemd.so' /etc/pam.d/system-session >/dev/null
grep -F 'pam_systemd.so' /etc/pam.d/systemd-user >/dev/null
grep -F 'yescrypt shadow' /etc/pam.d/system-password >/dev/null
grep -F 'pam_deny.so' /etc/pam.d/other >/dev/null
printf 'PAM_STACK_CONFIGURATION=PASS\nPAM_SERVICE_FILES=%s\n' "$(find /etc/pam.d -maxdepth 1 -type f | wc -l)"
PAM_CONFIG
printf 'PAM_STACK_RESULT=PASS\nLOG=%s\nBACKUP_DIR=%s\n' "$LOG" "$BACKUP" > "$LOG_DIR/pam-stack-$STAMP.package.status"
printf 'Configured PAM login, Shadow utilities, systemd-user, and Polkit stacks. No user or password was created.\n'
printf 'Log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
