#!/bin/bash
# REBUILD-R5 image finishing: applied to an image built by build-image.sh, read-write through a loop
# device backed by that image. Runs as root on the host. Nothing touches real disks, host /boot, /etc,
# NVRAM or /mnt/lfs. Idempotent: each edit is applied only when the R4 value is still there.
#   1. sddm X server path. The R4 /etc/sddm.conf sets ServerPath=/opt/xorg/bin/X in [X11]; the image has
#      /usr/bin/Xorg only. sddm reads /etc/sddm.conf last (ConfigReader load order: system dir, then
#      /etc/sddm.conf.d, then the classic file), so the R4 value wins over a conf.d drop-in. The line is
#      changed in the image copy of /etc/sddm.conf. The R4 snapshot is not changed.
#   2. PAM for sddm. R4 has no /etc/pam.d/system-login and no system-local-login, but sddm and sddm-autologin
#      include them. Without them the account stack falls back to "other" (pam_deny) and autologin fails
#      with "Permission denied" at acctMgmt. Both files are added with the R4 system-* modules.
#   3. Test user and sddm autologin into the plasma (Wayland) session. Test image only. The user and the
#      password come from configs/rebuild/r5-test-user.example.env (repo example config). The autologin
#      keys are set in the [Autologin] section of /etc/sddm.conf for the same load-order reason.
#
# Usage: sudo r5-image-finish.sh IMG
set -euo pipefail

IMG=${1:?usage: r5-image-finish.sh IMG}
HERE=$(cd "$(dirname "$0")" && pwd)
CONF=$HERE/../../../configs/rebuild/r5-test-user.example.env
ROOTMNT=/mnt/r5-image-finish
LOOP=
SDDM=$ROOTMNT/etc/sddm.conf

die() { echo "r5-image-finish: $*" >&2; exit 1; }
assert_loop() {
    [[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] || die "bad loop device '$LOOP'"
    [ "$(losetup -n -O BACK-FILE "$LOOP" 2>/dev/null)" = "$IMG" ] || die "$LOOP is not backed by $IMG"
}
cleanup() {
    set +e
    for m in "$ROOTMNT/dev" "$ROOTMNT/proc" "$ROOTMNT/sys"; do umount "$m" 2>/dev/null; done
    umount "$ROOTMNT" 2>/dev/null
    if [[ "$LOOP" =~ ^/dev/loop[0-9]+$ ]] && [ "$(losetup -n -O BACK-FILE "$LOOP" 2>/dev/null)" = "$IMG" ]; then
        sync
        losetup -d "$LOOP"
    fi
}
trap cleanup EXIT

[ "$(id -u)" -eq 0 ] || die "run as root"
[ -f "$IMG" ] || die "no image $IMG"
[ -f "$CONF" ] || die "no config $CONF"
. "$CONF"
[ -n "${R5_TEST_USER:-}" ] || die "config incomplete: R5_TEST_USER not set"
if [ -z "${R5_TEST_PASSWORD:-}" ]; then
    # No fixed password in the repo. Generate one now; keep it in a root-written 600 file, never print it.
    SECRET_DIR=/home/yrslf/alpbahOS/scratch-lfs-bench/test-secrets
    SECRET_FILE=$SECRET_DIR/r5-test-user.pw
    (umask 077 && mkdir -p "$SECRET_DIR")
    R5_TEST_PASSWORD=$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')
    [ "${#R5_TEST_PASSWORD}" -eq 24 ] || die "password generation failed"
    (umask 077 && printf '%s\n' "$R5_TEST_PASSWORD" > "$SECRET_FILE")
    chown --reference="$SECRET_DIR" "$SECRET_DIR" "$SECRET_FILE" 2>/dev/null || true
    chmod 600 "$SECRET_FILE"
fi

mkdir -p "$ROOTMNT"
LOOP=$(losetup --find --show --partscan "$IMG")
assert_loop
[ -b "${LOOP}p3" ] || die "missing ${LOOP}p3"
[ "$(lsblk -no PKNAME "${LOOP}p3")" = "$(basename "$LOOP")" ] || die "p3 not on $LOOP"
assert_loop
mount "${LOOP}p3" "$ROOTMNT"
mount --bind /dev "$ROOTMNT/dev"
mount -t proc proc "$ROOTMNT/proc"
mount -t sysfs sys "$ROOTMNT/sys"

[ -x "$ROOTMNT/usr/bin/Xorg" ] || die "no /usr/bin/Xorg in the image"
rm -f "$ROOTMNT/etc/sddm.conf.d/05-r5-xorg-serverpath.conf" "$ROOTMNT/etc/sddm.conf.d/10-r5-test-autologin.conf"
if grep -qx "ServerPath=/opt/xorg/bin/X" "$SDDM"; then
    sed -i "s|^ServerPath=/opt/xorg/bin/X$|ServerPath=/usr/bin/Xorg|" "$SDDM"
fi
grep -qx "ServerPath=/usr/bin/Xorg" "$SDDM" || die "sddm ServerPath not fixed"

for pamf in system-login system-local-login; do
    if [ ! -e "$ROOTMNT/etc/pam.d/$pamf" ]; then
        cat > "$ROOTMNT/etc/pam.d/$pamf" << PAM
# REBUILD-R5: R4 has no $pamf; sddm and sddm-autologin include it. Same modules as the R4 system-* stacks.
auth      include     system-auth
account   include     system-account
password  include     system-password
session   include     system-session
PAM
    fi
done
[ -f "$ROOTMNT/etc/pam.d/system-login" ] && [ -f "$ROOTMNT/etc/pam.d/system-local-login" ] || die "pam files missing"

if ! chroot "$ROOTMNT" /usr/bin/id "$R5_TEST_USER" >/dev/null 2>&1; then
    chroot "$ROOTMNT" /usr/sbin/useradd -m -G wheel,video,input,audio -s /bin/bash "$R5_TEST_USER"
fi
printf '%s:%s\n' "$R5_TEST_USER" "$R5_TEST_PASSWORD" | chroot "$ROOTMNT" /usr/sbin/chpasswd
chroot "$ROOTMNT" /usr/bin/id "$R5_TEST_USER" > /dev/null

sed -i "/^\[Autologin\]/,/^\[/{s/^User=.*/User=$R5_TEST_USER/;s/^Session=.*/Session=plasma.desktop/}" "$SDDM"
sed -i "/^\[Autologin\]/,/^\[/{s/^Relogin=.*/Relogin=false/}" "$SDDM"
sed -n "/^\[Autologin\]/,/^\[/p" "$SDDM" | grep -qx "User=$R5_TEST_USER" || die "autologin User not set"
sed -n "/^\[Autologin\]/,/^\[/p" "$SDDM" | grep -qx "Session=plasma.desktop" || die "autologin Session not set"

# Test-only environment. The Qt and KF6 paths are not set here: R4 provides them in /etc/profile.d
# (qt6.sh, kf6.sh) and /etc/profile, which the sddm Wayland session reads through a login shell.
touch "$ROOTMNT/etc/environment"
sed -i "/^LIBGL_ALWAYS_SOFTWARE=/d;/^QT_LOGGING_RULES=/d;/^QML_IMPORT_TRACE=/d;/^QT_DEBUG_PLUGINS=/d" "$ROOTMNT/etc/environment"
if [ -n "${R5_TEST_GL_SOFTWARE:-}" ]; then
    # The QEMU virtio GPU has no virgl, so Mesa uses software EGL (test image only).
    echo "LIBGL_ALWAYS_SOFTWARE=1" >> "$ROOTMNT/etc/environment"
fi
if [ -n "${R5_TEST_DEBUG_ENV:-}" ]; then
    # Diagnostic logging for plasmashell (goes to the user journal).
    echo "QT_LOGGING_RULES=*.debug=true" >> "$ROOTMNT/etc/environment"
    echo "QML_IMPORT_TRACE=1" >> "$ROOTMNT/etc/environment"
    echo "QT_DEBUG_PLUGINS=1" >> "$ROOTMNT/etc/environment"
fi
if [ -n "${R5_DEBUG_LIBPLASMA_DIR:-}" ]; then
    # Diagnostic: libPlasma built with RelWithDebInfo (same version, installed only into this image).
    cp "$R5_DEBUG_LIBPLASMA_DIR/libPlasma.so.6.7.4" "$ROOTMNT/usr/lib/libPlasma.so.6.7.4"
fi
# Test-only: no idle screen lock and no DPMS or suspend, so the desktop stays on the screen during the test.
mkdir -p "$ROOTMNT/home/$R5_TEST_USER/.config"
cat > "$ROOTMNT/home/$R5_TEST_USER/.config/kscreenlockerrc" << CFG
[Daemon]
Autolock=false
LockOnResume=false
CFG
cat > "$ROOTMNT/home/$R5_TEST_USER/.config/powermanagementprofilesrc" << CFG
[AC][DPMSControl]
idleTime=86400

[AC][SuspendSession]
idleTime=86400
CFG
chroot "$ROOTMNT" /usr/bin/chown -R "$R5_TEST_USER:$R5_TEST_USER" "/home/$R5_TEST_USER/.config"
umount "$ROOTMNT/sys" "$ROOTMNT/proc" "$ROOTMNT/dev"
umount "$ROOTMNT"
assert_loop
echo "OK r5-image-finish user=$R5_TEST_USER"
