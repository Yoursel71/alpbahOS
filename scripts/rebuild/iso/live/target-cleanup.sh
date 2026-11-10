#!/bin/sh
# AlpbahOS BETA: runs in the INSTALLED system (Calamares shellprocess, chroot of the target). Removes what only the
# live session needs. Each step tolerates "already gone" so a rerun is harmless.
set -u

# Keyboard (round 17): apply the layout chosen in the live session. live-layout-copy.sh wrote it to
# /usr/lib/alpbahos/live-layout before the keyboard step; here it is applied after that step to the X11 keyboard file, the KDE
# default, the console keymap (trq / trf / us) and the SDDM greeter environment. The result is kept on disk in
# /var/log/alpbahos-layout-apply.log (evidence; not removed).
LF=/usr/lib/alpbahos/live-layout
KL=/var/log/alpbahos-layout-apply.log
kl() { echo "$(date +%T) $*" >> "$KL"; }
if [ -f "$LF" ]; then
    LL=$(sed -n 's/^LAYOUT=//p' "$LF" | head -n 1)
    LV=$(sed -n 's/^VARIANT=//p' "$LF" | head -n 1)
    kl "live choice: LAYOUT=$LL VARIANT=$LV"
    case "$LL" in
        tr|us)
            X=/etc/X11/xorg.conf.d/00-keyboard.conf
            if [ -f "$X" ]; then
                sed -i "s/Option \"XkbLayout\" \".*\"/Option \"XkbLayout\" \"$LL\"/; s/Option \"XkbVariant\" \".*\"/Option \"XkbVariant\" \"$LV\"/" "$X"
                kl "00-keyboard.conf: $(grep -h 'XkbLayout\|XkbVariant' "$X" | tr -s ' ' | tr '\n' ' ')"
            fi
            if [ -f /etc/xdg/kxkbrc ]; then
                sed -i "s/^LayoutList=.*/LayoutList=$LL/; s/^VariantList=.*/VariantList=$LV/" /etc/xdg/kxkbrc
                kl "kxkbrc: $(grep -h 'LayoutList\|VariantList' /etc/xdg/kxkbrc | tr '\n' ' ')"
            fi
            if [ "$LL" = us ]; then CM=us; elif [ "$LV" = f ]; then CM=trf; else CM=trq; fi
            if [ -f /etc/vconsole.conf ]; then
                sed -i "s/^KEYMAP=.*/KEYMAP=$CM/" /etc/vconsole.conf
                grep -q '^KEYMAP=' /etc/vconsole.conf || echo "KEYMAP=$CM" >> /etc/vconsole.conf
                kl "vconsole.conf: $(grep -h KEYMAP /etc/vconsole.conf | tr '\n' ' ')"
            fi
            if [ -f /etc/sddm.conf ] && [ "$LV" = f ]; then
                sed -i 's/^GreeterEnvironment=\(.*\)$/GreeterEnvironment=\1,XKB_DEFAULT_VARIANT=f/' /etc/sddm.conf
                kl "sddm.conf: $(grep -h '^GreeterEnvironment' /etc/sddm.conf)"
            fi
            ;;
        *) kl "unknown layout $LL; not applied" ;;
    esac
    rm -f "$LF"
else
    kl "no live choice file; the installer layout stays"
fi
rm -f /usr/lib/alpbahos/live-layout-copy.sh

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
# Keyboard (round 15): Calamares writes an empty Option "XkbVariant" "" line, which systemd-localed does not
# parse (localectl then shows the X11 layout as unset). Remove that line; the layout tr stays.
if [ -f /etc/X11/xorg.conf.d/00-keyboard.conf ]; then
    sed -i '/Option "XkbVariant" ""/d' /etc/X11/xorg.conf.d/00-keyboard.conf
fi
exit 0
