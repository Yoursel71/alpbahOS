#!/bin/sh
# AlpbahOS BETA: runs in the LIVE system before the keyboard step (Calamares shellprocess, dontChroot).
# Calamares 3.3.14 does not expand @@ROOT@@ in a shellprocess (checked: the placeholder is not in libcalamares), so the target
# is found by its mount: the mounted directory whose /etc/os-release says ID=alpbahos (Calamares mounts the target under
# /tmp/calamares-root-*). The live layout choice is the live user's kxkbrc, a run-time file that unpackfs does not copy.
# Log: /run/alpbahos-layout.log (live), copied to <target>/var/log/alpbahos-layout-carry.log so the result stays on the disk.
LOG=/run/alpbahos-layout.log
KX=/home/live/.config/kxkbrc
log() { echo "$(date +%T) $*" >> "$LOG"; }
: > "$LOG"
log "start; live kxkbrc: $([ -f "$KX" ] && echo present || echo absent)"
ROOT=""
for m in $(findmnt -rn -o TARGET 2>/dev/null); do
    case "$m" in
        /|/run*|/proc*|/sys*|/dev*|/home*) continue ;;
    esac
    if [ -f "$m/etc/os-release" ] && grep -q '^ID=alpbahos' "$m/etc/os-release"; then
        ROOT=$m
        break
    fi
done
log "target root: ${ROOT:-none}"
[ -n "$ROOT" ] || exit 0
[ -f "$KX" ] || { log "no live choice; nothing copied"; cp "$LOG" "$ROOT/var/log/alpbahos-layout-carry.log" 2>/dev/null; exit 0; }
LL=$(sed -n 's/^LayoutList=//p' "$KX" | head -n 1 | cut -d, -f1)
LV=$(sed -n 's/^VariantList=//p' "$KX" | head -n 1)
# KConfig does not write a key equal to the system default (/etc/xdg/kxkbrc: LayoutList=tr, Use=true): a Turkish Q or F
# choice has only VariantList in the user file, so the layout is then the default tr.
[ -n "$LL" ] || LL=tr
log "live choice: LAYOUT=$LL VARIANT=$LV"
case "$LL" in
    tr|us)
        mkdir -p "$ROOT/usr/lib/alpbahos"
        printf 'LAYOUT=%s\nVARIANT=%s\n' "$LL" "$LV" > "$ROOT/usr/lib/alpbahos/live-layout"
        log "written: $ROOT/usr/lib/alpbahos/live-layout"
        ;;
    *) log "unknown layout $LL; nothing copied" ;;
esac
cp "$LOG" "$ROOT/var/log/alpbahos-layout-carry.log" 2>/dev/null
exit 0
