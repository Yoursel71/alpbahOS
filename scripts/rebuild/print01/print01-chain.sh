#!/bin/bash
# PRINT-01 (round 44, found 2026-11-12 in the driver audit): the image had CUPS without cups-filters (no PDF/raster
# filters, so most printers could not print), no ghostscript, qpdf or MuPDF. BLFS 13.1-systemd pages (book MD5
# checked by fetch-apps01.py; LFS patch sha256 printed in the record note); one alp record each through
# pkg-url-r11.sh (rows 449-456): ghostscript (+ the book's font archives), qpdf, pdfio, libexif, MuPDF (library and
# mutool), libcupsfilters, libppd, cups-filters. Network printer discovery (Avahi, cups-browsed) is a later step.
# Usage: print01-chain.sh [NAME ...] (default: all). Run as root. Env NICE (default 15), JOBS (default 10).
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
A=$WT/scripts/rebuild/print01/chroot
SRC=$SB/apps01-src
export NICE=${NICE:-15} JOBS=${JOBS:-10} DROP_SRC=1
mkdir -p "$SB/r10/dl"
link() { [ -e "$SB/r10/dl/$1" ] || ln "$SRC/$1" "$SB/r10/dl/$1"; }
md5() { [ "$(md5sum < "$SRC/$1" | cut -c1-32)" = "$2" ] || { echo "MD5 mismatch: $1"; exit 1; }; }
ARGS=("$@")
w() { [ ${#ARGS[@]} -eq 0 ] && return 0; local x; for x in "${ARGS[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
step() {  # NAME VER URL TARBALL NN PAGE MD5 SCRIPT [extra files...]
    local n=$1 v=$2 u=$3 t=$4 nn=$5 page=$6 m=$7 s=$8; shift 8
    md5 "$t" "$m"; link "$t"
    echo "== $n-$v ($(date +%T))"
    EXTRA_FILES="$s $*" CUSTOM_CMD="sh ../$(basename "$s")" \
      bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" "$n" "$v" "$u" "$t" custom - "$nn" \
        "PRINT-01: BLFS 13.1-systemd $page: $v, book MD5 $m matches"
}
G=https://github.com/OpenPrinting
w ghostscript && { md5 ghostscript-fonts-std-8.11.tar.gz 6865682b095f8c4500c54b285ff05ef6; md5 gnu-gs-fonts-other-6.0.tar.gz 33457d3f37de7ef03d2eea05a9e6aa4f
  step ghostscript 10.07.1 https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10071/ghostscript-10.07.1.tar.xz ghostscript-10.07.1.tar.xz 449 pst/gs.html 9e987b203c535d3c7829e1daefb85e98 "$A/gs.sh" "$SRC/ghostscript-fonts-std-8.11.tar.gz" "$SRC/gnu-gs-fonts-other-6.0.tar.gz"; }
w qpdf && step qpdf 12.4.0 https://github.com/qpdf/qpdf/releases/download/v12.4.0/qpdf-12.4.0.tar.gz qpdf-12.4.0.tar.gz 450 general/qpdf.html d3156920305cafe5b554dcf36cf3cfe7 "$A/qpdf.sh"
w pdfio && step pdfio 1.6.4 https://github.com/michaelrsweet/pdfio/releases/download/v1.6.4/pdfio-1.6.4.tar.gz pdfio-1.6.4.tar.gz 451 general/pdfio.html 21d128da7e16b8035e5eab0676c7496d "$A/pdfio.sh"
w libexif && step libexif 0.6.26 https://github.com/libexif/libexif/releases/download/v0.6.26/libexif-0.6.26.tar.bz2 libexif-0.6.26.tar.bz2 452 general/libexif.html d659a750d1be6330105de54eb3bf627a "$A/libexif.sh"
w mupdf && step mupdf 1.26.12 https://www.mupdf.com/downloads/archive/mupdf-1.26.12-source.tar.gz mupdf-1.26.12-source.tar.gz 453 pst/mupdf.html d10eb7e1ef0f4a44f5c14a29b9d6f906 "$A/mupdf.sh"
w libcupsfilters && step libcupsfilters 2.1.1 $G/libcupsfilters/releases/download/2.1.1/libcupsfilters-2.1.1.tar.xz libcupsfilters-2.1.1.tar.xz 454 pst/libcupsfilters.html 1e3144c242e7ddcee112d41c79266885 "$A/libcupsfilters.sh"
w libppd && step libppd 2.1.1 $G/libppd/releases/download/2.1.1/libppd-2.1.1.tar.xz libppd-2.1.1.tar.xz 455 pst/libppd.html 65accc86f9956a1160937b14e0f516a6 "$A/libppd.sh"
w cups-filters && { [ "$(sha256sum < "$SRC/cups-filters-2.0.1-security_fix-1.patch" | cut -c1-64)" = 52e73c96d896d18b28eabc6f507eb1011686d9c436c69983ba485312ed3e573b ] || { echo "patch sha256 changed"; exit 1; }
  step cups-filters 2.0.1 $G/cups-filters/releases/download/2.0.1/cups-filters-2.0.1.tar.xz cups-filters-2.0.1.tar.xz 456 pst/cups-filters.html b40d0f135af414666e1c3917983a1bb3 "$A/cups-filters.sh" "$SRC/cups-filters-2.0.1-security_fix-1.patch"; }
echo "print01 done $(date +%T)"
