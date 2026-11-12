#!/bin/sh
# alpbahOS BETA: runs in the INSTALLED system (Calamares shellprocess, chroot of the target). Removes what only the
# live session needs. Each step tolerates "already gone" so a rerun is harmless.
# INSTALL-CLEANUP-01 (D149): the security-relevant steps (live polkit rule, sddm autologin of the live user,
# live-only helpers) are followed by post-checks (also: no live user, no passwordless account); a failed post-check
# makes this script exit 1, which fails the Calamares job and stops the install with an error. The live user itself
# was removed before the users step (target-live-user.sh); this script never deletes an account, so a user that the
# installer made is never removed here. The keyboard step stays best effort (it logs only).
# Test hook: the kernel command line token alpbahos.testfail=live-cleanup skips the removals, so the post-checks must
# fail. It can only make an install fail, never pass.
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

# Keyboard (round 15): Calamares writes an empty Option "XkbVariant" "" line, which systemd-localed does not
# parse (localectl then shows the X11 layout as unset). Remove that line; the layout tr stays.
if [ -f /etc/X11/xorg.conf.d/00-keyboard.conf ]; then
    sed -i '/Option "XkbVariant" ""/d' /etc/X11/xorg.conf.d/00-keyboard.conf
fi

# ------------------------------------------------------------------ security-relevant steps (post-checked below)
SDDM_FILES="/etc/sddm.conf $(ls /etc/sddm.conf.d/*.conf /usr/lib/sddm/sddm.conf.d/*.conf 2>/dev/null | tr '\n' ' ')"
LIVE_ONLY="/etc/polkit-1/rules.d/49-alpbahos-live.rules /etc/profile.d/99-alpbahos-live.sh /usr/bin/alpbahos-install
/etc/alpbahos-live-debug /usr/lib/alpbahos/live-layout-copy.sh /usr/lib/alpbahos/target-initramfs.sh
/usr/lib/alpbahos/target-live-user.sh /usr/lib/alpbahos/target-grub-gfxmode.sh"
# (target-grub-gfxmode.sh runs later from the live system, dontChroot; the target's copy was left behind until round
# 43, so /usr/lib/alpbahos stayed in installed systems.)
if grep -qw 'alpbahos.testfail=live-cleanup' /proc/cmdline 2>/dev/null; then
    echo "alpbahos cleanup: TEST HOOK alpbahos.testfail=live-cleanup, removals skipped" >&2
else
    # Live-only polkit rule (installer without a password), live-only environment, launcher and helpers.
    for f in $LIVE_ONLY; do rm -f "$f"; done
    # Live-only installer configuration.
    rm -rf /etc/calamares
    # sddm: no autologin of the live user (the live image sets User=live, Session=plasma.desktop). Only an
    # [Autologin] section with User=live is reset; an autologin the user chose in the installer (Calamares writes
    # User=<their name>) is kept.
    for f in $SDDM_FILES; do
        [ -f "$f" ] || continue
        if sed -n '/^\[Autologin\]/,/^\[/p' "$f" | grep -qx 'User=live'; then
            sed -i -e '/^\[Autologin\]/,/^\[/{s/^User=.*/User=/;s/^Session=.*/Session=/}' "$f"
        fi
    done
fi

# ------------------------------------------------------------------ post-checks (exit 1 on any failure)
FAILED=0
fail() { echo "alpbahos cleanup check FAILED: $*" >&2; FAILED=1; }
getent passwd live > /dev/null 2>&1 && fail "user live still exists"
getent group live > /dev/null 2>&1 && fail "group live still exists"
[ ! -e /home/live ] || fail "/home/live still exists"
for f in $LIVE_ONLY; do [ ! -e "$f" ] || fail "live-only file still present: $f"; done
[ ! -e /etc/calamares ] || fail "/etc/calamares still present"
# No polkit rule may grant anything to the live user any more.
if grep -ls 'subject.user == "live"' /etc/polkit-1/rules.d/*.rules /usr/share/polkit-1/rules.d/*.rules 2>/dev/null | grep -q .; then
    fail "a polkit rule still names the live user"
fi
# An autologin user may only be an existing account other than live (the installer's own choice).
for f in $SDDM_FILES; do
    [ -f "$f" ] || continue
    for AU in $(sed -n '/^\[Autologin\]/,/^\[/{s/^User=\(..*\)$/\1/p}' "$f"); do
        [ "$AU" != live ] || fail "sddm autologin user is still live in $f"
        getent passwd "$AU" > /dev/null 2>&1 || fail "sddm autologin user $AU in $f is not an account"
    done
done
# No account may log in without a password (field 2 of /etc/shadow empty).
NOPW=$(awk -F: '$2 == "" { print $1 }' /etc/shadow)
[ -z "$NOPW" ] || fail "accounts without a password: $NOPW"
[ "$(stat -c %u:%g /)" = "0:0" ] || fail "/ is not owned by root: $(stat -c %u:%g /)"
[ "$FAILED" = 0 ] || exit 1

# The live image has an empty /etc/fstab; the fstab module has written the installed one before this step.
# This script removes itself last (only after every post-check passed).
rm -f /usr/lib/alpbahos/target-cleanup.sh
rmdir /usr/lib/alpbahos 2>/dev/null || true
echo "alpbahos cleanup: live-only items removed, post-checks passed"
exit 0
