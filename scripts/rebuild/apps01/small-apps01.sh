#!/bin/bash
# APPS-01 step 1: the small BLFS 13.1-systemd dependencies of VLC, Firefox and LibreOffice, one alp record each
# (pkg-url-r11.sh: build in a chroot of r4-root, stage, record, alp check, packages.tsv row). Sources were fetched
# and checked against the book MD5 by fetch-apps01.py (scratch-lfs-bench/apps01-src/SOURCES.tsv); they are linked
# into r10/dl, where pkg-url-r11.sh looks first. Book commands, DESTDIR/STAGE instead of the live root; docs left out.
# Lua 5.4 is already in r4-root. tiff (round 37): LibreOffice's bundled libtiff left zlib out of the libvcllo link.
# Usage: small-apps01.sh [NAME ...] (default: all, in order). Run as root.
# Env: NICE (default 19) and JOBS (default 4) so a running QEMU round is not disturbed.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
SRC=$SB/apps01-src
export NICE=${NICE:-19} JOBS=${JOBS:-4}
BOOK=https://www.linuxfromscratch.org/blfs/view/13.1-systemd
CF="-O2 -march=x86-64 -mtune=generic"
mkdir -p "$SB/r10/dl"
link() { [ -e "$SB/r10/dl/$1" ] || ln "$SRC/$1" "$SB/r10/dl/$1"; }
step() {  # NAME VER URL TARBALL KIND SRCDIR NN PAGE MD5 [opts]
    local n=$1 v=$2 u=$3 t=$4 k=$5 d=$6 nn=$7 page=$8 md5=$9; shift 9
    link "$t"
    echo "== $n-$v ($(date +%T))"
    bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" "$n" "$v" "$u" "$t" "$k" "$d" "$nn" \
        "APPS-01: BLFS 13.1-systemd $page: $v, book MD5 $md5 matches" "$@"
}
want() { [ $# -eq 0 ] && return 0; for w in "${ARGS[@]}"; do [ "$w" = "$1" ] && return 0; done; return 1; }
ARGS=("$@")
w() { [ ${#ARGS[@]} -eq 0 ] || want "$1"; }

w nasm && step nasm 3.02 https://www.nasm.us/pub/nasm/releasebuilds/3.02/nasm-3.02.tar.xz nasm-3.02.tar.xz \
    configure - 405 general/nasm.html 31ba022fff8de3065b5bc5ad5559188c

w zip && CUSTOM_CMD="make -f unix/Makefile generic CC='gcc -std=gnu89' \
 && make prefix=\$STAGE/usr MANDIR=\$STAGE/usr/share/man/man1 -f unix/Makefile install" \
  step zip 3.0 https://downloads.sourceforge.net/infozip/zip30.tar.gz zip30.tar.gz custom - 406 general/zip.html \
    7b74551e63f8ee6aab6fbc86676c0d37

w startup-notification && step startup-notification 0.12 \
    https://www.freedesktop.org/software/startup-notification/releases/startup-notification-0.12.tar.gz \
    startup-notification-0.12.tar.gz configure - 407 x/startup-notification.html 2cd77326d4dcaed9a5a23a1232fb38e9 \
    --disable-static

w liba52 && CUSTOM_CMD="./configure --prefix=/usr --mandir=/usr/share/man --enable-shared --disable-static \
 CFLAGS='$CF -fPIC' && make && make DESTDIR=\$STAGE install && install -Dm644 liba52/a52_internal.h \
 \$STAGE/usr/include/a52dec/a52_internal.h" \
  step liba52 0.8.0 https://distfiles.adelielinux.org/source/a52dec/a52dec-0.8.0.tar.gz a52dec-0.8.0.tar.gz custom - \
    408 multimedia/liba52.html 4debeed0257f5312e84d92711a5cfcec

w libmad && EXTRA_FILES="$SRC/libmad-0.15.1b-fixes-1.patch $WT/scripts/rebuild/apps01/mad.pc" \
  CUSTOM_CMD="patch -Np1 -i ../libmad-0.15.1b-fixes-1.patch && sed 's@AM_CONFIG_HEADER@AC_CONFIG_HEADERS@g' -i configure.ac \
 && touch NEWS AUTHORS ChangeLog && autoreconf -fi && ./configure --prefix=/usr --disable-static CFLAGS='$CF' \
 && make && make DESTDIR=\$STAGE install && install -Dm644 ../mad.pc \$STAGE/usr/lib/pkgconfig/mad.pc" \
  step libmad 0.15.1b https://downloads.sourceforge.net/mad/libmad-0.15.1b.tar.gz libmad-0.15.1b.tar.gz custom - \
    409 multimedia/libmad.html 1be543bc30c56fb6bea1d7bf6a64e66c

w desktop-file-utils && step desktop-file-utils 0.28 \
    https://www.freedesktop.org/software/desktop-file-utils/releases/desktop-file-utils-0.28.tar.xz \
    desktop-file-utils-0.28.tar.xz meson - 410 general/desktop-file-utils.html dec5d7265c802db1fde3980356931b7b

w libnotify && step libnotify 0.8.8 https://download.gnome.org/sources/libnotify/0.8/libnotify-0.8.8.tar.xz \
    libnotify-0.8.8.tar.xz meson - 411 x/libnotify.html 35bef24dc1e9a336394556d09345e078 -Dgtk_doc=false -Dman=false -Dtests=false -Dintrospection=disabled

w tiff && step tiff 4.7.2 https://download.osgeo.org/libtiff/tiff-4.7.2.tar.gz tiff-4.7.2.tar.gz cmake - 420 \
    general/tiff.html a2a65ea450b8f469c667128848ffebfc

echo "small-apps01 done $(date +%T)"
