#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=4.37
readonly ARCHIVE="nspr-$VERSION.tar.gz"
readonly URL="https://archive.mozilla.org/pub/nspr/releases/v$VERSION/src/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/nspr-$VERSION-alpbahOS-$STAMP"
readonly SOURCE="$WORK/nspr-$VERSION/nspr"
readonly STAGE="$WORK/stage"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/nspr-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/nspr-$VERSION-$STAMP.status"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libnspr4.so ]]' || fail 'make is missing or NSPR already exists in the target.'

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/downloads"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'BLFS_NSPR_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'BLFS_NSPR_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

printf 'BLFS 12.4 NSPR %s; package tests and checksum calculation skipped.\nSource: %s\n' "$VERSION" "$URL"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$STAGE" <<'NSPR_BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
tar -xf "/sources/$archive" -C "$work"
[[ -x "$source/configure" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j4 NSPR_SOURCE='$source' NSPR_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$NSPR_SOURCE"
sed -i '/^RELEASE/s|^|#|' pr/src/misc/Makefile.in
./configure --prefix=/usr --with-mozilla --with-pthreads --enable-64bit > configure.log 2>&1 || { tail -n 120 configure.log; exit 1; }
make -j4 > compile.log 2>&1 || { tail -n 180 compile.log; exit 1; }
mkdir -pv "$NSPR_STAGE"
make install DESTDIR="$NSPR_STAGE" > staged-install.log 2>&1 || { tail -n 120 staged-install.log; exit 1; }
[[ -e "$NSPR_STAGE/usr/lib/libnspr4.so" && -f "$NSPR_STAGE/usr/lib/pkgconfig/nspr.pc" ]]
[[ -f "$NSPR_STAGE/usr/include/nspr/prtypes.h" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
cp -a "$stage"/. /
ldconfig
[[ "$(pkg-config --modversion nspr)" == 4.37.0 ]]
[[ -e /usr/lib/libnspr4.so && -f /usr/include/nspr/prtypes.h ]]
ldd /usr/lib/libnspr4.so | tee "$work/ldd.log"
! ldd /usr/lib/libnspr4.so | grep -F 'not found'
printf 'NSPR_BUILD_INSTALL=PASS\n'
NSPR_BUILD

printf 'BLFS_NSPR_RESULT=PASS\nLOG=%s\nWORK=%s\n' "$LOG" "$LFS$WORK" > "$LOG_DIR/nspr-$VERSION-$STAMP.package.status"
printf 'NSPR %s installed. Log: %s\n' "$VERSION" "$LOG"
