#!/bin/bash
# REBUILD-R21 (SUDO-01, D151): sudo 1.9.17p2 per BLFS 13.1-systemd postlfs/sudo.html, as an alp record in r4-root.
# Run as root on the host; the build runs in a chroot of r4-root with generic x86-64 flags (D146).
# Source: https://www.sudo.ws/dist/sudo-1.9.17p2.tar.gz, book MD5 dcbf46f739ae06b076e1a11cbb271a10; upstream signature
#   checked on the host on 2026-11-10 ("Good signature from Todd C. Miller", key 59D1E9CCBA2B376704FDD35BA9F4C021CEA470FB
#   from https://www.sudo.ws/dist/PGPKEYS).
# Book steps: the openssl-4 sed fix, configure (--libexecdir=/usr/lib --with-secure-path --with-env-editor --docdir
#   --with-passprompt), make, make install; /etc/pam.d/sudo from the book. The test suite (make check) is run and its
#   failure count is printed. alpbahOS adds /etc/sudoers.d/10-alpbahos-wheel (the book's 00-sudo content):
#   members of wheel run any command after their own password. visudo -c checks the result in the chroot.
# Usage: sudo-r21.sh <tarball>
set -euo pipefail
export LC_ALL=C
TAR=$1
MD5=dcbf46f739ae06b076e1a11cbb271a10
NAME=sudo; VER=1.9.17p2
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
W=$SB/r10/$NAME
[ -d "$R4/usr/lib" ] || { echo "r4-root missing"; exit 1; }
echo "$MD5  $TAR" | md5sum -c - || { echo "md5 mismatch"; exit 1; }
echo "tarball sha256 $(sha256sum "$TAR" | cut -d' ' -f1)"
[ ! -e "$R4/usr/bin/sudo" ] || { echo "sudo already in r4-root"; exit 1; }
BLD=/tmp/build-$NAME
STG=/tmp/stage-$NAME
rm -rf "$W" "$R4$BLD" "$R4$STG"
mkdir -p "$W" "$R4$BLD"
tar xf "$TAR" -C "$R4$BLD" --strip-components=1
mount --bind /dev "$R4/dev"; mount -t proc proc "$R4/proc"
cleanup() { umount "$R4/proc" "$R4/dev" 2>/dev/null || true; rm -rf "$R4$BLD" "$R4$STG"; }
trap cleanup EXIT
cat > "$R4$BLD/.build.sh" << 'EOS'
set -e
cd /tmp/build-sudo
sed -e 's/\([->.a-zA-Z_]*\)->length/ASN1_STRING_length(\1)/' -i lib/iolog/hostcheck.c
CFLAGS='-O2 -march=x86-64 -mtune=generic' ./configure --prefix=/usr --libexecdir=/usr/lib --with-secure-path \
    --with-env-editor --docdir=/usr/share/doc/sudo-1.9.17p2 --with-passprompt="[sudo] password for %p: "
make -j16
env LC_ALL=C make check > make-check.log 2>&1 || true
echo "make check: $(grep -c -i 'failed' make-check.log) lines with 'failed'"
grep -i 'failed' make-check.log | head -n 10 || true
make DESTDIR=/tmp/stage-sudo install
install -d -m 755 /tmp/stage-sudo/etc/pam.d /tmp/stage-sudo/etc/sudoers.d
cat > /tmp/stage-sudo/etc/pam.d/sudo << "EOF2"
# Begin /etc/pam.d/sudo
# include the default auth settings
auth      include     system-auth
# include the default account settings
account   include     system-account
# Set default environment variables for the service user
session   required    pam_env.so
# include system session defaults
session   include     system-session
# End /etc/pam.d/sudo
EOF2
chmod 644 /tmp/stage-sudo/etc/pam.d/sudo
cat > /tmp/stage-sudo/etc/sudoers.d/10-alpbahos-wheel << "EOF2"
# alpbahOS (D151): members of wheel run any command after their own password (BLFS 13.1 00-sudo content).
Defaults secure_path="/usr/sbin:/usr/bin"
%wheel ALL=(ALL) ALL
EOF2
chmod 440 /tmp/stage-sudo/etc/sudoers.d/10-alpbahos-wheel
LD_LIBRARY_PATH=/tmp/stage-sudo/usr/lib/sudo /tmp/stage-sudo/usr/sbin/visudo -c -f /tmp/stage-sudo/etc/sudoers
LD_LIBRARY_PATH=/tmp/stage-sudo/usr/lib/sudo /tmp/stage-sudo/usr/sbin/visudo -c -f /tmp/stage-sudo/etc/sudoers.d/10-alpbahos-wheel
EOS
set +e
chroot "$R4" /usr/bin/env PATH=/usr/bin:/usr/sbin sh "$BLD/.build.sh" > "$W/build.log" 2>&1
RC=$?
set -e
echo "chroot build rc=$RC (log $W/build.log)"
grep -E "^make check:|parsed OK" "$W/build.log" || true
[ "$RC" = 0 ] || exit 1
grep -q 'march=x86-64' "$W/build.log" || grep -q 'march=x86-64' "$R4$BLD/config.log" || { echo "generic flags not seen"; exit 1; }
cp "$R4$BLD/make-check.log" "$W/make-check.log"
rm -rf "$W/stage" && cp -a "$R4$STG" "$W/stage"
rm -rf "$W/stage/run" "$W/stage/var/run"   # runtime dirs (made by systemd-tmpfiles), not package files
echo "staged files: $(find "$W/stage" -type f -o -type l | wc -l); sudo mode $(stat -c %a "$W/stage/usr/bin/sudo")"
set +e
"$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh" "$W/stage" > "$W/audit-isa.txt" 2>&1
ARC=$?
set -e
echo "audit-isa rc=$ARC: $(tail -1 "$W/audit-isa.txt")"
[ "$ARC" = 0 ] || exit 1
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh "$WT/scripts/rebuild/r8/stage-record-r8.py" "$NAME" "$VER" "$W/stage" "$NAME" "$VER" usr/share/info/dir
echo "installed: sudo mode $(stat -c %a "$R4/usr/bin/sudo") owner $(stat -c %u:%g "$R4/usr/bin/sudo")"
chroot "$R4" /usr/sbin/visudo -c
# sudo 1.9.17p2 installs itself 4755 (u+s); the check is on the setuid bit (an earlier 4111 expectation was wrong).
[ -u "$R4/usr/bin/sudo" ] || { echo "sudo is not setuid"; exit 1; }
