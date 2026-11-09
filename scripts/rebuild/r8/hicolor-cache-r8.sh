#!/bin/bash
# REBUILD-R8 S3: regenerate the hicolor icon cache in a copy inside r4-root (chroot), copy the cache to STAGE.
# Usage: hicolor-cache-r8.sh <R4_ROOT> <STAGE_DIR>   (run as root; the stage gets usr/share/icons/hicolor/icon-theme.cache)
set -euo pipefail
R4=$1; STAGE=$2
TMP=$R4/tmp/hicolor-r8
rm -rf "$TMP" && mkdir -p "$TMP"
cp -a "$R4/usr/share/icons/hicolor/." "$TMP/"
chroot "$R4" /usr/bin/env PATH=/usr/bin:/usr/sbin:/bin:/sbin gtk-update-icon-cache -f -t /tmp/hicolor-r8
mkdir -p "$STAGE/usr/share/icons/hicolor"
cp -a "$TMP/icon-theme.cache" "$STAGE/usr/share/icons/hicolor/icon-theme.cache"
rm -rf "$TMP"
echo "cache $(stat -c %s "$STAGE/usr/share/icons/hicolor/icon-theme.cache") bytes"
