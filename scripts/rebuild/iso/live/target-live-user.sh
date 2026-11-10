#!/bin/sh
# alpbahOS installer (INSTALL-UID-01, D148): runs in the INSTALLED system (Calamares shellprocess@live-user, chroot of
# the target) right after the files are copied and BEFORE the users step, so the first installed user gets UID 1000
# (the live user holds UID 1000 in the copied files). The job fails (exit 1) when a post-check fails; "already gone"
# passes because only the post-checks decide.
# Test hook: the kernel command line token alpbahos.testfail=live-user skips the removal, so the post-checks must
# fail and the installer must stop. It can only make an install fail, never pass.
set -u
FAILED=0
fail() { echo "alpbahos live-user check FAILED: $*" >&2; FAILED=1; }

if grep -qw 'alpbahos.testfail=live-user' /proc/cmdline 2>/dev/null; then
    echo "alpbahos live-user: TEST HOOK alpbahos.testfail=live-user, removal skipped" >&2
else
    if getent passwd live > /dev/null 2>&1; then
        userdel -r live 2> /tmp/alpbahos-userdel.err || echo "userdel -r live returned $? ($(cat /tmp/alpbahos-userdel.err))" >&2
        rm -f /tmp/alpbahos-userdel.err
    fi
    if getent group live > /dev/null 2>&1; then groupdel live || echo "groupdel live returned $?" >&2; fi
    rm -rf /home/live
fi

# Post-checks.
getent passwd live > /dev/null 2>&1 && fail "user live still exists"
getent group live > /dev/null 2>&1 && fail "group live still exists"
[ ! -e /home/live ] || fail "/home/live still exists"
U=$(awk -F: '$3 == 1000 { print $1 }' /etc/passwd)
[ -z "$U" ] || fail "UID 1000 is still taken by: $U"
G=$(awk -F: '$3 == 1000 { print $1 }' /etc/group)
[ -z "$G" ] || fail "GID 1000 is still taken by: $G"
# Nothing on the root file system may belong to UID/GID 1000 before the first user is made (it would get it).
LEFT=$(find / -xdev \( -uid 1000 -o -gid 1000 \) -print 2> /dev/null | head -n 5)
[ -z "$LEFT" ] || fail "files owned by UID/GID 1000 remain: $LEFT"
[ "$(stat -c %u:%g /)" = "0:0" ] || fail "/ is not owned by root: $(stat -c %u:%g /)"

[ "$FAILED" = 0 ] || exit 1
echo "alpbahos live-user: live user removed, UID/GID 1000 free"
exit 0
