#!/bin/bash
# Round 39 (user request 2026-11-11): the orange/cyan line under the logo of the brand wallpaper looked like a stuck
# loading bar; it is now a real one. The wallpaper (and the SDDM background, a copy of its 1920x1080 image) has no
# line; KSplash draws the same layout with a bar in the same place that fills with the session start stages.
# Record alpbahos-loadingbar-r39 takes over the wallpaper images, the preview, the SDDM background and the KSplash
# files (REPLACE=1). Run as root on the host.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ST=$SB/r39/stage-loadingbar
SRC=$WT/branding/alpbahos-brand/wallpaper/alpbahOS-Brand/contents
LNF=$WT/profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/splash
cd "$WT"
python3 -B branding/alpbahos-brand/tools/build_brand_wallpaper.py --check
rm -rf "$ST"; D=$ST/usr/share/wallpapers/alpbahOS-Brand/contents
K=$ST/usr/share/plasma/look-and-feel/org.alpbahos.solid.desktop/contents/splash
install -d -m 755 "$D/images" "$ST/usr/share/sddm/themes/alpbahos" "$K/images"
install -m 644 "$SRC"/images/*.png "$D/images/"; install -m 644 "$SRC/screenshot.png" "$D/screenshot.png"
install -m 644 "$SRC/images/1920x1080.png" "$ST/usr/share/sddm/themes/alpbahos/background.png"
install -m 644 "$LNF/Splash.qml" "$LNF/BrandGeometry.qml" "$K/"
install -m 644 "$LNF/images/brand-center.png" "$K/images/"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-loadingbar-r39 0.9-r39 "$ST" \
    alpbahos-loadingbar-r39 0.9-r39
chown -R yrslf: "$SB/r39"
