#!/bin/sh
# AlpbahOS BETA: runs in the INSTALLED system (Calamares shellprocess, chroot of the target). Removes what only the
# live session needs. Each step tolerates "already gone" so a rerun is harmless.
set -u

# Live user and its home (desktop launcher included).
userdel -r live 2>/dev/null || true
rm -rf /home/live

# Live-only polkit rule (lets the live user start the installer without a password), live-only test environment.
rm -f /etc/polkit-1/rules.d/49-alpbahos-live.rules
rm -f /etc/profile.d/99-alpbahos-live.sh
rm -f /usr/bin/alpbahos-install

# Live-only installer configuration.
rm -rf /etc/calamares

# sddm: no autologin in the installed system (the live image sets User=live, Session=plasma.desktop).
if [ -f /etc/sddm.conf ]; then
    sed -i -e 's/^User=live$/User=/' -e 's/^Session=plasma.desktop$/Session=/' /etc/sddm.conf
fi

# The live image has an empty /etc/fstab; the fstab module has written the installed one before this step.
# Nothing else to remove: the squashfs holds no live-only files outside the list above.
rm -f /usr/lib/alpbahos/target-initramfs.sh
rm -f /usr/lib/alpbahos/target-cleanup.sh
rm -f /etc/alpbahos-live-debug
rmdir /usr/lib/alpbahos 2>/dev/null || true
exit 0
