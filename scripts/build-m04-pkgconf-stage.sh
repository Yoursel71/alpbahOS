#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Pkgconf-2.5.1 isolated package stage. Run on the Builder.
# This script is a draft and must be reviewed before execution. It does not
# merge staged files into /mnt/lfs; installation always uses DESTDIR.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/pkgconf-2.5.1-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-pkgconf-stage-r1
STAGE_CHROOT=/tmp/alp-m04-pkgconf-stage-r1
SOURCE=/mnt/lfs/sources/pkgconf-2.5.1.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-pkgconf-2.5.1-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-m04-pkgconf-2.5.1-manifest-20260924-r1.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-pkgconf-2.5.1-preflight-20260924-r1.log
SOURCE_URL=https://distfiles.ariadne.space/pkgconf/pkgconf-2.5.1.tar.xz
# LFS 12.4-systemd Chapter 3 provides the MD5. The SHA-256 is cross-checked
# against the archive checksum listed by Fossies for this same .tar.xz file.
# References: https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html
#             https://fossies.org/linux/misc/pkgconf-2.5.1.tar.xz/
EXPECTED_MD5=3291128c917fdb8fccd8c9e7784b643b
EXPECTED_SHA256=cd05c9589b9f86ecf044c10a2269822bc9eb001eced2582cfffd658b0a50c243
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL="$SCRIPT_DIR/capture-package-manifest.py"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"
MOUNTS=()
FINISHED=0

cleanup() {
    local status=$?
    trap - EXIT
    set +e
    for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do
        umount "${MOUNTS[$i]}" || status=1
    done
    if findmnt -rn -R "$LFS"; then
        echo "CLEANUP_FAILED: mounts remain below $LFS" >&2
        status=1
    else
        echo "CLEANUP_OK: no mounts remain below $LFS"
    fi
    if (( FINISHED )); then
        echo "STAGE_OK: $STAGE_HOST"
    else
        echo 'STAGE_INCOMPLETE: preserve build/stage/logs for diagnosis' >&2
        status=1
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

assert_alp_and_empty_db() {
    [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
    python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    database = json.load(stream)
if database.get("schema_version") != 1 or database.get("packages") != {}:
    raise SystemExit("refusing: Alp must remain pinned at schema 1 with an empty package DB")
PY
}

[[ $EUID -eq 0 ]]
[[ -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" ]]
[[ ! -e "$MANIFEST" && ! -e "$PREFLIGHT" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) ]]
[[ ! -s /sys/block/nbd0/pid ]]
for process in make ninja meson; do
    if pgrep -x "$process" >/dev/null; then
        echo "Refusing concurrent build process: $process" >&2
        exit 1
    fi
done
assert_alp_and_empty_db
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
echo "LFS_MD5=$(md5sum "$SOURCE" | awk '{print $1}')"
echo "LFS_ROOTFS_MERGE=forbidden install_mode=DESTDIR"
df -h "$LFS"
mkdir -p "$BUILD" "$STAGE_HOST"
tar -xJf "$SOURCE" -C "$BUILD" --strip-components=1
chown -R 1001:1001 "$BUILD"

bind_mount() {
    local source=$1 target=$2
    if /usr/bin/mountpoint -q "$target"; then
        echo "Refusing pre-existing mount: $target" >&2
        return 1
    fi
    mount --bind "$source" "$target"
    MOUNTS+=("$target")
}
bind_mount /dev "$LFS/dev"
bind_mount /dev/pts "$LFS/dev/pts"
bind_mount /proc "$LFS/proc"
bind_mount /sys "$LFS/sys"
bind_mount /run "$LFS/run"

# Follow the official LFS commands verbatim: configure, make, make install,
# then the two compatibility symlinks. There is no upstream test-suite step.
chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
    HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c '
        cd /build/pkgconf-2.5.1-m04-r1
        ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/pkgconf-2.5.1
        make
    '
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        cd /build/pkgconf-2.5.1-m04-r1
        make DESTDIR=/tmp/alp-m04-pkgconf-stage-r1 install
        test ! -e /tmp/alp-m04-pkgconf-stage-r1/usr/bin/pkg-config
        test ! -L /tmp/alp-m04-pkgconf-stage-r1/usr/bin/pkg-config
        test ! -e /tmp/alp-m04-pkgconf-stage-r1/usr/share/man/man1/pkg-config.1
        test ! -L /tmp/alp-m04-pkgconf-stage-r1/usr/share/man/man1/pkg-config.1
        ln -sv pkgconf /tmp/alp-m04-pkgconf-stage-r1/usr/bin/pkg-config
        ln -sv pkgconf.1 /tmp/alp-m04-pkgconf-stage-r1/usr/share/man/man1/pkg-config.1
    '

# Smoke only the isolated staged tree. The staged library path keeps this from
# silently resolving a libpkgconf.so in the Builder rootfs.
STAGED_VERSION=$(chroot "$LFS" /usr/bin/env \
    LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
    "$STAGE_CHROOT/usr/bin/pkgconf" --version)
[[ "$STAGED_VERSION" == 2.5.1 ]]
[[ $(chroot "$LFS" /usr/bin/env LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
    "$STAGE_CHROOT/usr/bin/pkg-config" --version) == 2.5.1 ]]
chroot "$LFS" /usr/bin/env LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
    "$STAGE_CHROOT/usr/bin/bomtool" --help >/dev/null
[[ -L "$STAGE_HOST/usr/bin/pkg-config" ]]
[[ $(readlink "$STAGE_HOST/usr/bin/pkg-config") == pkgconf ]]
[[ -L "$STAGE_HOST/usr/share/man/man1/pkg-config.1" ]]
[[ $(readlink "$STAGE_HOST/usr/share/man/man1/pkg-config.1") == pkgconf.1 ]]
[[ -s "$STAGE_HOST/usr/lib/libpkgconf.so" || -L "$STAGE_HOST/usr/lib/libpkgconf.so" ]]
echo "PKGCONF_STAGE_SMOKE=passed version=$STAGED_VERSION"

assert_alp_and_empty_db
[[ ! -s /sys/block/nbd0/pid ]]
{
    echo 'package=pkgconf version=2.5.1'
    echo "source_url=$SOURCE_URL"
    echo "source_md5=$EXPECTED_MD5"
    echo "source_sha256=$EXPECTED_SHA256"
    echo 'install_mode=DESTDIR; rootfs_merge=forbidden'
    echo "builder=$(hostname)"
} > "$PREFLIGHT"
python3 "$CAPTURE_TOOL" --stage "$STAGE_HOST" --name pkgconf --version 2.5.1 \
    --source-url "$SOURCE_URL" --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST" | tee -a "$PREFLIGHT"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >> "$PREFLIGHT" 2>&1; then
    compare_status=0
else
    compare_status=$?
fi
case "$compare_status" in
    0) echo 'ROOTFS_PREFLIGHT=all staged paths already match the live rootfs' | tee -a "$PREFLIGHT" ;;
    1) echo 'ROOTFS_PREFLIGHT=staged paths differ; review recorded mismatches before any adoption' | tee -a "$PREFLIGHT" ;;
    *) echo "ROOTFS_PREFLIGHT=compare tool failed status=$compare_status" | tee -a "$PREFLIGHT"; exit "$compare_status" ;;
esac
cat "$PREFLIGHT"
[[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
assert_alp_and_empty_db
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
