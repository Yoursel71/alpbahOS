#!/bin/bash
# APPS-01 step 3: VLC 3.0.23, Archive-Zip 1.68 (LibreOffice build requirement) and LibreOffice 26.2.5.2, one alp
# record each through pkg-url-r11.sh; book commands in chroot/*.sh. Sources: fetch-apps01.py (book MD5 checked).
# Usage: vlc-lo-chain-apps01.sh [NAME ...] (default: all, in order). Run as root. Env: NICE (default 10), JOBS
# (default 14). Do not run next to a QEMU timing or memory row.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
A=$WT/scripts/rebuild/apps01
SRC=$SB/apps01-src
export NICE=${NICE:-10} JOBS=${JOBS:-14} DROP_SRC=1
mkdir -p "$SB/r10/dl"
link() { [ -e "$SB/r10/dl/$1" ] || ln "$SRC/$1" "$SB/r10/dl/$1"; }
ARGS=("$@")
w() { [ ${#ARGS[@]} -eq 0 ] && return 0; local x; for x in "${ARGS[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
step() {  # NAME VER URL TARBALL NN PAGE MD5 SCRIPT [extra files...]
    local n=$1 v=$2 u=$3 t=$4 nn=$5 page=$6 md5=$7 s=$8; shift 8
    link "$t"
    echo "== $n-$v ($(date +%T))"
    EXTRA_FILES="$s $*" CUSTOM_CMD="sh ../$(basename "$s")" \
      bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" "$n" "$v" "$u" "$t" custom - "$nn" \
        "APPS-01: BLFS 13.1-systemd $page: $v, book MD5 $md5 matches"
}
w vlc && step vlc 3.0.23 https://download.videolan.org/vlc/3.0.23/vlc-3.0.23.tar.xz vlc-3.0.23.tar.xz 417 \
    multimedia/vlc.html ebc3f0d0a94785fd2b2df4087516938e "$A/chroot/vlc.sh"
w archive-zip && step perl-archive-zip 1.68 \
    https://www.cpan.org/authors/id/P/PH/PHRED/Archive-Zip-1.68.tar.gz Archive-Zip-1.68.tar.gz 418 \
    general/perl-modules.html a33993309322164867c99e04a4000ee3 \
    "$A/chroot/archive-zip.sh"
w libreoffice && step libreoffice 26.2.5.2 \
    https://download.documentfoundation.org/libreoffice/src/26.2.5/libreoffice-26.2.5.2.tar.xz \
    libreoffice-26.2.5.2.tar.xz 419 xsoft/libreoffice.html cde5452693205386a34cbf3ce561956b \
    "$A/chroot/libreoffice.sh" "$SRC/libreoffice-dictionaries-26.2.5.2.tar.xz" \
    "$SRC/libreoffice-translations-26.2.5.2.tar.xz"
echo "vlc-lo-chain-apps01 done $(date +%T)"
