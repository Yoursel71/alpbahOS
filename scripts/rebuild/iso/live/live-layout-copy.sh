#!/bin/sh
# AlpbahOS BETA: runs in the LIVE system before the keyboard step (Calamares shellprocess, dontChroot, argument @@ROOT@@ = the
# target). It copies the layout chosen with alpbahos-keyboard into the target. The choice is the live user's kxkbrc, a file
# written at run time; unpackfs copies the image, not the running session, so the target cannot see it otherwise.
ROOT=$1
KX=/home/live/.config/kxkbrc
[ -f "$KX" ] || exit 0
LL=$(sed -n 's/^LayoutList=//p' "$KX" | head -n 1 | cut -d, -f1)
# KConfig does not write a key equal to the system default (/etc/xdg/kxkbrc: LayoutList=tr, Use=true), so a Turkish Q
# or Turkish F choice has only VariantList in the user file: the layout is then the default tr.
[ -n "$LL" ] || LL=tr
LV=$(sed -n 's/^VariantList=//p' "$KX" | head -n 1)
case "$LL" in
    tr|us) ;;
    *) exit 0 ;;
esac
mkdir -p "$ROOT/usr/lib/alpbahos"
printf 'LAYOUT=%s\nVARIANT=%s\n' "$LL" "$LV" > "$ROOT/usr/lib/alpbahos/live-layout"
exit 0
