#!/bin/bash
# APPS-02 (round 43, found 2026-11-12 while checking drivers): the rebuilt image had none of D127's KDE apps besides
# Dolphin and Konsole: no Kate/KWrite, Okular (and no poppler: no PDF viewing), Gwenview, Ark. BLFS 13.1-systemd
# pages, book MD5 checked by fetch-apps01.py; one alp record each through pkg-url-r11.sh (rows 437-448), book commands
# in chroot/*.sh. Order: openjpeg, poppler, poppler-data, exiv2, libkexiv2, kColorPicker, kImageAnnotator, 7zip,
# okular, gwenview, ark, kate. Usage: apps02-chain.sh [NAME ...] (default: all). Run as root. Env NICE (default 15),
# JOBS (default 10): the host also runs QEMU rows.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
A=$WT/scripts/rebuild/apps02/chroot
SRC=$SB/apps01-src
export NICE=${NICE:-15} JOBS=${JOBS:-10} DROP_SRC=1
mkdir -p "$SB/r10/dl"
link() { [ -e "$SB/r10/dl/$1" ] || ln "$SRC/$1" "$SB/r10/dl/$1"; }
md5() { [ "$(md5sum < "$SRC/$1" | cut -c1-32)" = "$2" ] || { echo "MD5 mismatch: $1"; exit 1; }; }
ARGS=("$@")
w() { [ ${#ARGS[@]} -eq 0 ] && return 0; local x; for x in "${ARGS[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
step() {  # NAME VER URL TARBALL NN PAGE MD5 SCRIPT
    local n=$1 v=$2 u=$3 t=$4 nn=$5 page=$6 m=$7 s=$8
    md5 "$t" "$m"; link "$t"
    echo "== $n-$v ($(date +%T))"
    EXTRA_FILES="$s" CUSTOM_CMD="sh ../$(basename "$s")" \
      bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" "$n" "$v" "$u" "$t" custom - "$nn" \
        "APPS-02: BLFS 13.1-systemd $page: $v, book MD5 $m matches"
}
K=https://download.kde.org/stable/release-service/26.04.3/src
w openjpeg && step openjpeg 2.5.4 https://github.com/uclouvain/openjpeg/archive/v2.5.4/openjpeg-2.5.4.tar.gz openjpeg-2.5.4.tar.gz 437 general/openjpeg2.html 6160de075bb5191e482bc0f024b375e4 "$A/openjpeg.sh"
w poppler && step poppler 26.08.0 https://poppler.freedesktop.org/poppler-26.08.0.tar.xz poppler-26.08.0.tar.xz 438 general/poppler.html 0c7953c55c449f20d97adbe355bcf49d "$A/poppler.sh"
w poppler-data && step poppler-data 0.4.12 https://poppler.freedesktop.org/poppler-data-0.4.12.tar.gz poppler-data-0.4.12.tar.gz 439 general/poppler.html 67ee4a40aa830b1f6e2560ce5f6471ba "$A/poppler-data.sh"
w exiv2 && step exiv2 0.28.8 https://github.com/Exiv2/exiv2/archive/v0.28.8/exiv2-0.28.8.tar.gz exiv2-0.28.8.tar.gz 440 general/exiv2.html 3f3b2d9c3e73880ea8e6bd78c67ea56a "$A/exiv2.sh"
w libkexiv2 && step libkexiv2 26.04.3 $K/libkexiv2-26.04.3.tar.xz libkexiv2-26.04.3.tar.xz 441 kde/libkexiv2.html a8e59525f1b204efafa0efb894597e25 "$A/libkexiv2.sh"
w kcolorpicker && step kcolorpicker 0.3.1 https://github.com/ksnip/kColorPicker/archive/v0.3.1/kColorPicker-0.3.1.tar.gz kColorPicker-0.3.1.tar.gz 442 x/kcolorpicker.html 1efc91252446af0d7e5c467ea7d517e7 "$A/kcolorpicker.sh"
w kimageannotator && step kimageannotator 0.7.2 https://github.com/ksnip/kImageAnnotator/archive/v0.7.2/kImageAnnotator-0.7.2.tar.gz kImageAnnotator-0.7.2.tar.gz 443 x/kimageannotator.html 12811a2611613152b8dccc266a8f4804 "$A/kimageannotator.sh"
w 7zip && step 7zip 26.02 https://github.com/ip7z/7zip/archive/26.02/7zip-26.02.tar.gz 7zip-26.02.tar.gz 444 general/7zip.html 29f692dc18d150acbbd31a86e3ffe610 "$A/7zip.sh"
w okular && step okular 26.04.3 $K/okular-26.04.3.tar.xz okular-26.04.3.tar.xz 445 kde/okular.html aad3a5d01cf615cb22b2a9ef3eb120ef "$A/okular.sh"
w gwenview && step gwenview 26.04.3 $K/gwenview-26.04.3.tar.xz gwenview-26.04.3.tar.xz 446 kde/gwenview.html e5f5de769772d49975243e24dd95f3af "$A/gwenview.sh"
w ark && step ark 26.04.3 $K/ark-26.04.3.tar.xz ark-26.04.3.tar.xz 447 kde/ark.html d716cf45066ca14705e7227267c31e08 "$A/ark.sh"
w kate && step kate 26.04.3 $K/kate-26.04.3.tar.xz kate-26.04.3.tar.xz 448 postlfs/kate.html 2b5b0f7071088586f4424d53b5148a6d "$A/kate.sh"
echo "apps02 done $(date +%T)"
