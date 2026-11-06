#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=1.1.43
readonly ARCHIVE="libxslt-$VERSION.tar.xz"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/libxslt-$VERSION-alpbahOS-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/libxslt-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/libxslt-$VERSION-d34-$STAMP.status"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
    '[[ -x /usr/bin/make && -x /usr/bin/pkg-config && -x /usr/bin/xml2-config && ! -x /usr/bin/xsltproc ]]' \
    || fail 'libxml2/make prerequisites are missing or xsltproc is already installed.'
sudo -n test -r "$LFS/sources/$ARCHIVE" || fail "Missing cached source: $LFS/sources/$ARCHIVE"
mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_LIBXSLT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'BLFS_LIBXSLT_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
printf 'BLFS 12.4 libxslt %s for isolated D34 candidate; package tests and checksum skipped.\n' "$VERSION"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" <<'LIBXSLT_BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
install -d -o nobody -g nogroup "$work"
tar -xf "/sources/$archive" -C "$work"
source="$work/libxslt-1.1.43"
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "cd '$source' && ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/libxslt-1.1.43 && make -j4" > "$work/build.log" 2>&1 \
    || { tail -n 120 "$work/build.log"; exit 1; }
install -d "$work/stage"
make -C "$source" -j1 DESTDIR="$work/stage" install > "$work/install.log" 2>&1 \
    || { tail -n 100 "$work/install.log"; exit 1; }
chown -R 0:0 "$work/stage"
cp -a "$work/stage"/. /
ldconfig
[[ "$(pkg-config --modversion libxslt)" == 1.1.43 ]]
[[ "$(pkg-config --modversion libexslt)" == 0.8.24 ]]
[[ "$(xslt-config --version)" == 1.1.43 ]]
[[ -x /usr/bin/xsltproc && -d /usr/include/libxslt && -d /usr/include/libexslt ]]
printf 'LIBXSLT_D34_BUILD_INSTALL=PASS\nLIBXSLT_VERSION=1.1.43\n'
LIBXSLT_BUILD
printf 'BLFS libxslt %s installed in the D34 candidate; log: %s\n' "$VERSION" "$LOG"
