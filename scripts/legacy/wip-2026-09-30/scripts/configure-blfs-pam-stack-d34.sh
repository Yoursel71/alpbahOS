#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A build or package-test process is active.'
fi

sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -s <<'PAM_PREFLIGHT'
set -Eeuo pipefail
[[ "$(pkg-config --modversion pam)" == 1.7.1 ]]
[[ -f /usr/lib/security/pam_unix.so && -f /usr/lib/security/pam_systemd.so ]]
[[ ! -e /etc/pam.d && ! -L /etc/pam.d ]]
PAM_PREFLIGHT

lfs_acquire_writer_lock "$DATA"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -s <<'PAM_CONFIG'
set -Eeuo pipefail
install -d -m 0755 /etc/pam.d
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
for program in chfn chgpasswd chsh groupadd groupdel groupmems groupmod useradd userdel usermod; do
    sed "s/chage/$program/" /etc/pam.d/chage > "/etc/pam.d/$program"
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
chmod 0644 /etc/pam.d/*
[[ -f /etc/pam.d/login && -f /etc/pam.d/su && -f /etc/pam.d/systemd-user && -f /etc/pam.d/polkit-1 ]]
grep -F 'pam_systemd.so' /etc/pam.d/system-session >/dev/null
grep -F 'yescrypt shadow' /etc/pam.d/system-password >/dev/null
grep -F 'pam_deny.so' /etc/pam.d/other >/dev/null
printf 'PAM_STACK_CONFIGURATION=PASS\nPAM_SERVICE_FILES=%s\n' "$(find /etc/pam.d -maxdepth 1 -type f | wc -l)"
PAM_CONFIG
