#!/bin/bash
# APPS-01 step 2: Firefox 153.2.0esr and its missing BLFS 13.1-systemd dependencies (NSPR, NSS, cbindgen, Node.js),
# one alp record each through pkg-url-r11.sh. The book's commands are in chroot/*.sh and firefox/ (files copied next
# to the build tree, run with sh). Sources: fetch-apps01.py (book MD5 checked, apps01-src/SOURCES.tsv).
# Usage: firefox-chain-apps01.sh [NAME ...] (default: all, in order). Run as root.
# Env: NICE (default 10), JOBS (default 14). Do not run next to a QEMU timing or memory row.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
A=$WT/scripts/rebuild/apps01
SRC=$SB/apps01-src
export NICE=${NICE:-10} JOBS=${JOBS:-14}
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
w nspr && step nspr 4.40 https://archive.mozilla.org/pub/nspr/releases/v4.40/src/nspr-4.40.tar.gz nspr-4.40.tar.gz \
    412 general/nspr.html 0c3c871158cc9af694f1f7d2b799ffd8 "$A/chroot/nspr.sh"
w nss && step nss 3.126 https://archive.mozilla.org/pub/security/nss/releases/NSS_3_126_RTM/src/nss-3.126.tar.gz \
    nss-3.126.tar.gz 413 postlfs/nss.html 0ca322cec564a53ac5a59ce130d96f46 "$A/chroot/nss.sh" \
    "$SRC/nss-standalone-1.patch"
w cbindgen && step cbindgen 0.29.4 https://github.com/mozilla/cbindgen/archive/v0.29.4/cbindgen-0.29.4.tar.gz \
    cbindgen-0.29.4.tar.gz 414 general/cbindgen.html 7e790e024bc678ad1b4431b0350679e9 "$A/chroot/cbindgen.sh"
w nodejs && step nodejs 24.19.0 https://nodejs.org/dist/v24.19.0/node-v24.19.0.tar.xz node-v24.19.0.tar.xz \
    415 general/nodejs.html 9746bea71fd37c5ec17236b713e0879f "$A/chroot/nodejs.sh"
w firefox && step firefox 153.2.0esr \
    https://archive.mozilla.org/pub/firefox/releases/153.2.0esr/source/firefox-153.2.0esr.source.tar.xz \
    firefox-153.2.0esr.source.tar.xz 416 xsoft/firefox.html 127f9c7fe72cf8cc9a47f35a051303f0 \
    "$A/firefox/firefox.sh" "$A/firefox/mozconfig"
echo "firefox-chain-apps01 done $(date +%T)"
