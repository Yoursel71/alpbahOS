#!/bin/bash
# APPS-01 (round 37 finding): VLC 3.0.23's Qt 6 interface shows no video in a Plasma Wayland session (the window
# shows the cone while the time runs; QEMU screenshots r37 apps-vlc-wayland-*), as the BLFS 13.1 VLC page warns.
# With QT_QPA_PLATFORM=xcb (Xwayland, D132) the video plays (apps-vlc-xcb-*). Record vlc-alpbahos-desktop
# 0.9-apps01 takes /usr/share/applications/vlc.desktop over from the vlc record (REPLACE=1) with the same file and
# only the Exec line changed, so menus, the taskbar and "Open with" start VLC through Xwayland. Run as root.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
D=usr/share/applications/vlc.desktop
grep -qx 'Exec=/usr/bin/vlc --started-from-file %U' "$R4/$D" || { echo "unexpected Exec line in $D"; exit 1; }
ST=$SB/apps01/stage-vlc-desktop
rm -rf "$ST" && mkdir -p "$ST/usr/share/applications"
sed 's|^Exec=/usr/bin/vlc --started-from-file %U$|Exec=env QT_QPA_PLATFORM=xcb /usr/bin/vlc --started-from-file %U|' \
    "$R4/$D" > "$ST/$D"
chmod 644 "$ST/$D"
[ "$(diff "$R4/$D" "$ST/$D" | grep -c '^[<>]')" = 2 ] || { echo "more than the Exec line changed"; exit 1; }
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py vlc-alpbahos-desktop 0.9-apps01 \
    "$ST" vlc-alpbahos-desktop 0.9-apps01
grep -n '^Exec=' "$R4/$D"
echo "vlc-xcb-apps01 done $(date +%T)"
