#!/bin/bash
# Round 40 (real-PC test 2026-11-11, PIXBUF-01): GTK programs could load no images. BLFS 13.1 builds gdk-pixbuf 2.44.7
# with the PNG/JPEG/GIF/TIFF loaders disabled in favour of glycin, but r4-root never got glycin, so
# /usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache lists no loader at all. On real hardware Firefox crashed (SIGSEGV) while
# the user picked a photo to upload; the journal also had "Could not load a pixbuf ... pixbuf loaders ... could not be
# found". Deviation from the book until glycin is built (follow-up): the same gdk-pixbuf 2.44.7 source is built again
# with the classic loaders; only the loader modules and a regenerated loaders.cache are recorded
# (record gdk-pixbuf-loaders 2.44.7-alpbahos1: GIF and TIFF modules, loaders.cache taken over from gdk-pixbuf) and the
# library with PNG and JPEG built in (record gdk-pixbuf-builtin 2.44.7-alpbahos1). Run as root on the host.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
TAR=$SB/blfs-src-13.1/gdk-pixbuf-2.44.7.tar.xz
[ "$(md5sum < "$TAR" | cut -c1-32)" = 2a12da2133476b7b36fbfcadd7133315 ] || { echo "book MD5 mismatch"; exit 1; }
cd "$WT"
CUSTOM_CMD="meson setup build --prefix=/usr --buildtype=release -Dpng=enabled -Djpeg=enabled -Dgif=enabled \
 -Dtiff=enabled -Dthumbnailer=disabled -Dglycin=disabled -Dman=false -Dtests=false -Dinstalled_tests=false \
 --wrap-mode=nofallback && ninja -C build && DESTDIR=\$STAGE ninja -C build install" \
  bash scripts/rebuild/r10/build-pkg-r10.sh gdk-pixbuf-loaders 2.44.7 "$TAR" custom -
W=$SB/r10/gdk-pixbuf-loaders
ST=$SB/r40/stage-pixbuf
L=usr/lib/gdk-pixbuf-2.0/2.10.0
rm -rf "$ST" && mkdir -p "$ST/$L/loaders"
cp -a "$W/stage/$L/loaders/." "$ST/$L/loaders/"
ls "$ST/$L/loaders"
# loaders.cache from the root's own gdk-pixbuf-query-loaders, over the staged modules, paths rewritten to /usr
T=/tmp/pixbuf-loaders-r40
rm -rf "$R4$T" && mkdir -p "$R4$T" && cp -a "$ST/$L/loaders/." "$R4$T/"
trap 'rm -rf "$R4$T"' EXIT
chroot "$R4" /usr/bin/env PATH=/usr/bin:/bin sh -c "gdk-pixbuf-query-loaders $T/*.so" \
    | sed "s|$T/|/$L/loaders/|g" > "$ST/$L/loaders.cache"
grep -c '^"/usr/lib/gdk-pixbuf' "$ST/$L/loaders.cache"
grep -qE '"image/gif"' "$ST/$L/loaders.cache"
grep -qE '"image/tiff"' "$ST/$L/loaders.cache"
chmod 644 "$ST/$L/loaders.cache"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py gdk-pixbuf-loaders 2.44.7-alpbahos1 \
    "$ST" gdk-pixbuf-loaders 2.44.7-alpbahos1
# PNG and JPEG are built into the library in 2.44 ("Builtin loaders: png jpeg"), so the library itself is replaced too:
# record gdk-pixbuf-builtin 2.44.7-alpbahos1 takes libgdk_pixbuf-2.0.so.0.4400.7 over from gdk-pixbuf (REPLACE=1).
LIB=usr/lib/libgdk_pixbuf-2.0.so.0.4400.7
[ "$(strings "$W/stage/$LIB" | grep -cx 'image/png')" -ge 1 ]
[ "$(strings "$W/stage/$LIB" | grep -cx 'image/jpeg')" -ge 1 ]
SL=$SB/r40/stage-pixbuf-lib
rm -rf "$SL" && install -D -m 755 "$W/stage/$LIB" "$SL/$LIB"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py gdk-pixbuf-builtin 2.44.7-alpbahos1 \
    "$SL" gdk-pixbuf-builtin 2.44.7-alpbahos1
echo "pixbuf-loaders-r40 done $(date +%T)"
