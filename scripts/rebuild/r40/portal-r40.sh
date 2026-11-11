#!/bin/bash
# Round 40 (PORTAL-01, found after the real-PC test 2026-11-11): the image had xdg-desktop-portal-kde but not the
# xdg-desktop-portal daemon itself (org.freedesktop.portal.Desktop), so Flatpak apps had no file chooser or other portals
# and Firefox could not use the KDE file dialog. xdg-desktop-portal is not in BLFS 13.1; its upstream release 1.22.1
# (github.com/flatpak/xdg-desktop-portal, sha256 checked against the release's .sha256sum) needs gstreamer-pbutils, so
# GStreamer 1.28.6 and gst-plugins-base 1.28.6 come first, from BLFS 13.1-systemd (book MD5 checked). One alp record each
# through pkg-url-r11.sh (rows 424-426). No GObject Introspection in r4-root: introspection off. Run as root.
# Usage: portal-r40.sh [NAME ...] (default: all, in order). Env NICE (default 10), JOBS (default 14).
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
SRC=$SB/apps01-src
export NICE=${NICE:-10} JOBS=${JOBS:-14}
mkdir -p "$SB/r10/dl"
ARGS=("$@")
w() { [ ${#ARGS[@]} -eq 0 ] && return 0; local x; for x in "${ARGS[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
get() {  # URL FILE MD5|-
    [ -s "$SRC/$2" ] || curl -fsSL --max-time 600 -o "$SRC/$2" "$1"
    [ "$3" = - ] || [ "$(md5sum < "$SRC/$2" | cut -c1-32)" = "$3" ] || { echo "MD5 mismatch: $2"; exit 1; }
    [ -e "$SB/r10/dl/$2" ] || ln "$SRC/$2" "$SB/r10/dl/$2"
}
B=https://gstreamer.freedesktop.org/src
if w gstreamer; then
    get $B/gstreamer/gstreamer-1.28.6.tar.xz gstreamer-1.28.6.tar.xz 3d16d7912727ea85ab90b9e5f3bc6e8a
    bash scripts/rebuild/r11/pkg-url-r11.sh gstreamer 1.28.6 $B/gstreamer/gstreamer-1.28.6.tar.xz gstreamer-1.28.6.tar.xz \
        meson - 424 "PORTAL-01: BLFS 13.1-systemd multimedia/gstreamer10.html: 1.28.6, book MD5 3d16d791... matches" \
        -Dgst_debug=false -Dtests=disabled -Dexamples=disabled -Dintrospection=disabled -Ddoc=disabled
fi
if w gst-plugins-base; then
    get $B/gst-plugins-base/gst-plugins-base-1.28.6.tar.xz gst-plugins-base-1.28.6.tar.xz cd0b2bd13e8196d5bfb20459c12a5d9b
    bash scripts/rebuild/r11/pkg-url-r11.sh gst-plugins-base 1.28.6 $B/gst-plugins-base/gst-plugins-base-1.28.6.tar.xz \
        gst-plugins-base-1.28.6.tar.xz meson - 425 \
        "PORTAL-01: BLFS 13.1-systemd multimedia/gst10-plugins-base.html: 1.28.6, book MD5 cd0b2bd1... matches" \
        --wrap-mode=nodownload -Dtests=disabled -Dexamples=disabled -Dintrospection=disabled -Ddoc=disabled
fi
if w xdg-desktop-portal; then
    U=https://github.com/flatpak/xdg-desktop-portal/releases/download/1.22.1
    T=xdg-desktop-portal-1.22.1.tar.xz
    [ -s "$SRC/$T" ] || curl -fsSL -o "$SRC/$T" "$U/$T"
    [ "$(sha256sum < "$SRC/$T" | cut -c1-64)" = d4879ddb3d65ff1a8f19187497e6f13dc5d267bcac404a5d501218be355753d3 ] \
        || { echo "sha256 mismatch: $T"; exit 1; }
    [ -e "$SB/r10/dl/$T" ] || ln "$SRC/$T" "$SB/r10/dl/$T"
    bash scripts/rebuild/r11/pkg-url-r11.sh xdg-desktop-portal 1.22.1 "$U/$T" "$T" meson - 426 \
        "PORTAL-01: upstream release 1.22.1 (not in BLFS 13.1), sha256 d4879ddb... matches the release .sha256sum" \
        -Dgeoclue=disabled -Ddocumentation=disabled -Dtests=disabled -Dman-pages=disabled -Dsystemd=enabled \
        -Dflatpak-interfaces=enabled
fi
echo "portal-r40 done $(date +%T)"
