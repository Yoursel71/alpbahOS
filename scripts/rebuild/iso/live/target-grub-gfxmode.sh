#!/bin/sh
# GRUB-GFXMODE-01 (D158): runs in the live system (Calamares shellprocess@grub-gfxmode, dontChroot) after grubcfg and
# before bootloader. Writes GRUB_GFXMODE='<WxH>,auto' into the target's /etc/default/grub, where WxH is the preferred
# mode of the first connected display as the live kernel sees it (/sys/class/drm/*/modes lists it first). Reason:
# GRUB's own "auto" falls back to 640x480 when the firmware gives it no EDID mode (QEMU, VirtualBox, some old
# monitors), and the alpbahOS theme does not fit 640x480. If GRUB cannot set that mode later (other display), it
# tries "auto". No connected display found: the line stays 'auto'.
# Calamares 3.3.14 does not expand @@ROOT@@ (see live-layout-copy.sh; round 23 install failed on it), so the target
# is the mounted directory with /etc/default/grub whose /etc/os-release says ID=alpbahos (not the live "/").
# Usage: target-grub-gfxmode.sh [target-root]   (an argument that is a real directory wins)
set -eu
ROOT=""
if [ -n "${1:-}" ] && [ -d "$1/etc" ]; then ROOT=$1; fi
if [ -z "$ROOT" ]; then
    for m in $(findmnt -rn -o TARGET 2>/dev/null); do
        case "$m" in /|/run*|/proc*|/sys*|/dev*|/home*) continue ;; esac
        if [ -f "$m/etc/default/grub" ] && grep -q '^ID=alpbahos' "$m/etc/os-release" 2>/dev/null; then ROOT=$m; break; fi
    done
fi
[ -n "$ROOT" ] || { echo "target-grub-gfxmode: target root not found" >&2; exit 1; }
F=$ROOT/etc/default/grub
[ -f "$F" ] || { echo "target-grub-gfxmode: $F missing" >&2; exit 1; }
grep -q '^GRUB_GFXMODE=' "$F" || { echo "target-grub-gfxmode: no GRUB_GFXMODE line in $F" >&2; exit 1; }
mode=""; src=none
for c in /sys/class/drm/card*-*; do
    [ -r "$c/status" ] && [ "$(cat "$c/status")" = connected ] || continue
    m=$(head -n 1 "$c/modes" 2>/dev/null || true)
    if printf '%s\n' "$m" | grep -Eq '^[0-9]{3,4}x[0-9]{3,4}$'; then mode=$m; src=$c; break; fi
done
if [ -n "$mode" ]; then val="$mode,auto"; else val=auto; fi
sed -i "s/^GRUB_GFXMODE=.*/GRUB_GFXMODE='$val'/" "$F"
echo "target-grub-gfxmode: GRUB_GFXMODE='$val' (display: $src, root: $ROOT)"
grep -qx "GRUB_GFXMODE='$val'" "$F"
