#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=3.115
readonly ARCHIVE="nss-$VERSION.tar.gz"
readonly PATCH="nss-standalone-1.patch"
readonly URL="https://archive.mozilla.org/pub/security/nss/releases/NSS_3_115_RTM/src/$ARCHIVE"
readonly PATCH_URL="https://www.linuxfromscratch.org/patches/blfs/12.4/$PATCH"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/nss-$VERSION-alpbahOS-$STAMP"
readonly SOURCE="$WORK/nss-$VERSION/nss"
readonly DIST="$WORK/nss-$VERSION/dist"
readonly STAGE="$WORK/stage"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/nss-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/nss-$VERSION-$STAMP.status"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly PATCH_PATH="$LFS/sources/$PATCH"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"
readonly TEMP_PATCH="$DATA/downloads/$PATCH.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && -x /usr/bin/patch && -e /usr/lib/libnspr4.so && ! -e /usr/lib/libnss3.so ]]' || fail 'make/patch/NSPR prerequisites are missing or NSS is already installed.'

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/downloads"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'BLFS_NSS_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'BLFS_NSS_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

printf 'BLFS 12.4 NSS %s; package tests and checksum calculation skipped.\nSource: %s\nPatch: %s\n' "$VERSION" "$URL" "$PATCH_URL"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
fi
if ! sudo -n test -r "$PATCH_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_PATCH" "$PATCH_URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_PATCH" "$PATCH_PATH"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$PATCH" "$WORK" "$SOURCE" "$DIST" "$STAGE" <<'NSS_BUILD'
set -Eeuo pipefail
archive="$1"; patch_file="$2"; work="$3"; source="$4"; dist="$5"; stage="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/Makefile" && -d "$source/lib" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin NSS_SOURCE='$source' NSS_DIST='$dist' NSS_STAGE='$stage' NSS_PATCH='/sources/$patch_file' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$NSS_SOURCE/.."
patch --batch -Np1 -i "$NSS_PATCH"
cd "$NSS_SOURCE"
make -j4 BUILD_OPT=1 USE_64=1 NSPR_INCLUDE_DIR=/usr/include/nspr USE_SYSTEM_ZLIB=1 NSS_ENABLE_WERROR=0 NSS_DISABLE_GTESTS=1 > build.log 2>&1 || { tail -n 200 build.log; exit 1; }
latest="$(<"$NSS_DIST/latest")"
[[ -d "$NSS_DIST/$latest/lib" && -d "$NSS_SOURCE/../dist/public/nss" && -d "$NSS_SOURCE/../dist/private/nss" && -d "$NSS_DIST/$latest/bin" ]]
install -d "$NSS_STAGE/usr/lib" "$NSS_STAGE/usr/include/nss" "$NSS_STAGE/usr/bin"
cp -aL "$NSS_DIST/$latest"/lib/*.so "$NSS_STAGE/usr/lib/"
cp -aL "$NSS_DIST/$latest"/lib/*.chk "$NSS_STAGE/usr/lib/"
cp -aL "$NSS_DIST/public/nss"/. "$NSS_STAGE/usr/include/nss/"
cp -aL "$NSS_DIST/private/nss"/. "$NSS_STAGE/usr/include/nss/"
cp -aL "$NSS_DIST/$latest/lib/pkgconfig" "$NSS_STAGE/usr/lib/"
cp -aL "$NSS_DIST/$latest/bin"/. "$NSS_STAGE/usr/bin/"
[[ -f "$NSS_STAGE/usr/lib/libcrmf.a" || -e "$NSS_DIST/$latest/lib/libcrmf.a" ]]
cp -aL "$NSS_DIST/$latest/lib/libcrmf.a" "$NSS_STAGE/usr/lib/"
[[ -f "$NSS_STAGE/usr/lib/libnss3.so" && -f "$NSS_STAGE/usr/lib/pkgconfig/nss.pc" ]]
[[ -x "$NSS_STAGE/usr/bin/nss-config" && -f "$NSS_STAGE/usr/include/nss/nss.h" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
cp -a "$stage"/. /
ldconfig
[[ "$(pkg-config --modversion nss)" == 3.115.0 ]]
[[ -e /usr/lib/libnss3.so && -x /usr/bin/nss-config && -f /usr/include/nss/nss.h ]]
ldd /usr/lib/libnss3.so | tee "$work/ldd.log"
! ldd /usr/lib/libnss3.so | grep -F 'not found'
printf 'NSS_BUILD_INSTALL=PASS\n'
NSS_BUILD

printf 'BLFS_NSS_RESULT=PASS\nLOG=%s\nWORK=%s\n' "$LOG" "$LFS$WORK" > "$LOG_DIR/nss-$VERSION-$STAMP.package.status"
printf 'NSS %s installed. Log: %s\n' "$VERSION" "$LOG"
