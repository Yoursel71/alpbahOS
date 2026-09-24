#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Man-pages 6.15 isolated stage. Run on Builder as root.
# Copy capture-package-manifest.py and compare-package-manifest.py to /home/sa
# before running. All build, stage, manifest, preflight, and log files remain
# below /mnt/lfs; this script never installs into rootfs /usr or alp's DB.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/man-pages-6.15-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-man-pages-stage-r1
STAGE_CHROOT=/tmp/alp-m04-man-pages-stage-r1
SOURCE=/mnt/lfs/sources/man-pages-6.15.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-man-pages-6.15-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-logs/man-pages-6.15-2026-09-24.json
PREFLIGHT=/mnt/lfs/tmp/alp-logs/man-pages-6.15-2026-09-24-preflight.log
CAPTURE_TOOL=${CAPTURE_TOOL:-/home/sa/capture-package-manifest.py}
COMPARE_TOOL=${COMPARE_TOOL:-/home/sa/compare-package-manifest.py}
EXPECTED_MD5=16f68d70139dd2bbcae4102be4705753
EXPECTED_SHA256=03d8ebf618bd5df57cb4bf355efa3f4cd3a00b771efd623d4fd042b5dceb4465
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
MOUNTS=()
FINISHED=0

check_alp_invariants() {
    [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
    python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    db = json.load(stream)
assert db.get("packages") == {}, "alp package database is not empty"
PY
}

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
        echo "MANIFEST: $MANIFEST"
        echo "PREFLIGHT: $PREFLIGHT"
    else
        echo 'STAGE_INCOMPLETE: preserve build/stage/log for diagnosis' >&2
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

[[ $EUID -eq 0 ]]
[[ -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) ]]
[[ ! -s /sys/block/nbd0/pid ]]
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
check_alp_invariants
[[ -z $(pgrep -x make || true) && -z $(pgrep -x ninja || true) && -z $(pgrep -x cmake || true) ]]
for target in "$LFS/dev" "$LFS/dev/pts" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    ! mountpoint -q "$target"
done

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
echo "Source MD5: $(md5sum "$SOURCE")"
echo "Pinned alp SHA-256: $ALP_SHA256"
df -h "$LFS"
mkdir -p "$BUILD" "$STAGE_HOST"
tar -xf "$SOURCE" -C "$BUILD" --strip-components=1

bind_mount() {
    local source=$1 target=$2
    if mountpoint -q "$target"; then
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

chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c '
        set -e
        cd /build/man-pages-6.15-m04-r1
        rm -v man3/crypt*
        make -R GIT=false prefix=/usr DESTDIR=/tmp/alp-m04-man-pages-stage-r1 install
    '

[[ -d "$STAGE_HOST" && -n $(find "$STAGE_HOST" -mindepth 1 -print -quit) ]]
[[ -s "$STAGE_HOST/usr/share/man/man2/open.2" ]]
[[ -z $(find "$STAGE_HOST/usr/share/man/man3" -maxdepth 1 -name 'crypt*' -print -quit) ]]
echo "MAN_PAGE_FILES=$(find "$STAGE_HOST/usr/share/man" -type f | wc -l)"
python3 "$CAPTURE_TOOL" \
    --stage "$STAGE_HOST" \
    --name man-pages \
    --version 6.15 \
    --source-url https://www.kernel.org/pub/linux/docs/man-pages/man-pages-6.15.tar.xz \
    --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST"
python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" > "$PREFLIGHT"
chmod 0644 "$MANIFEST" "$PREFLIGHT"
cat "$PREFLIGHT"
check_alp_invariants
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
