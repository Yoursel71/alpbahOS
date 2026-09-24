#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Iana-Etc 20250807 isolated stage. Run on Builder as root.
# Copy capture-package-manifest.py and compare-package-manifest.py to /home/sa
# before running. All build, stage, manifest, preflight, and log files remain
# below /mnt/lfs; this script never installs into rootfs /etc or alp's DB.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/iana-etc-20250807-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-iana-etc-stage-r1
STAGE_CHROOT=/tmp/alp-m04-iana-etc-stage-r1
SOURCE=/mnt/lfs/sources/iana-etc-20250807.tar.gz
LOG=/mnt/lfs/tmp/alp-logs/m04-iana-etc-20250807-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-logs/iana-etc-20250807-2026-09-24.json
PREFLIGHT=/mnt/lfs/tmp/alp-logs/iana-etc-20250807-2026-09-24-preflight.log
CAPTURE_TOOL=${CAPTURE_TOOL:-/home/sa/capture-package-manifest.py}
COMPARE_TOOL=${COMPARE_TOOL:-/home/sa/compare-package-manifest.py}
EXPECTED_MD5=de0a909103d4ff59d1424c5ec7ac9e4a
EXPECTED_SHA256=4f88470a2cac2a2f9568285aaff9aeaee0ab66c6ba3c12bba51adca915fa92b1
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
[[ -z $(findmnt -rn -R "$LFS" || true) ]]
[[ ! -s /sys/block/nbd0/pid ]]
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
check_alp_invariants
for target in "$LFS/dev" "$LFS/dev/pts" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    ! mountpoint -q "$target"
done

compare_rootfs() {
    local compare_status=0
    if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" > "$PREFLIGHT"; then
        compare_status=0
    else
        compare_status=$?
    fi
    # compare-package-manifest exits 1 when it successfully reports mismatches.
    # Exit codes above 1 indicate malformed input or an execution error.
    (( compare_status <= 1 ))
    echo "PREFLIGHT_EXIT=$compare_status (1 means one or more differences were reported)"
    chmod 0644 "$PREFLIGHT"
    cat "$PREFLIGHT"
}

if [[ ${1:-} == --verify-stage-only ]]; then
    [[ -d "$BUILD" && -s "$BUILD/services" && -s "$BUILD/protocols" ]]
    [[ -d "$STAGE_HOST" && -s "$STAGE_HOST/etc/services" && -s "$STAGE_HOST/etc/protocols" ]]
    [[ -f "$LOG" && -f "$MANIFEST" ]]
    exec >>"$LOG" 2>&1
    echo "STAGE_VERIFY_ONLY=$(date -Is) Builder=$(hostname)"
    chmod 0644 "$MANIFEST"
    cmp "$BUILD/services" "$STAGE_HOST/etc/services"
    cmp "$BUILD/protocols" "$STAGE_HOST/etc/protocols"
    [[ $(stat -c '%u:%g:%a' "$STAGE_HOST/etc/services") == 0:0:644 ]]
    [[ $(stat -c '%u:%g:%a' "$STAGE_HOST/etc/protocols") == 0:0:644 ]]
    compare_rootfs
    check_alp_invariants
    [[ ! -s /sys/block/nbd0/pid ]]
    FINISHED=1
    exit 0
fi

[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" ]]
[[ -z $(pgrep -x make || true) && -z $(pgrep -x ninja || true) && -z $(pgrep -x cmake || true) ]]
mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
echo "Source MD5: $(md5sum "$SOURCE")"
echo "Pinned alp SHA-256: $ALP_SHA256"
df -h "$LFS"
mkdir -p "$BUILD" "$STAGE_HOST/etc"
tar -xzf "$SOURCE" -C "$BUILD" --strip-components=1

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
        cd /build/iana-etc-20250807-m04-r1
        cp -p services protocols /tmp/alp-m04-iana-etc-stage-r1/etc
        cmp services /tmp/alp-m04-iana-etc-stage-r1/etc/services
        cmp protocols /tmp/alp-m04-iana-etc-stage-r1/etc/protocols
    '

[[ -s "$STAGE_HOST/etc/services" && -s "$STAGE_HOST/etc/protocols" ]]
[[ $(stat -c '%u:%g:%a' "$STAGE_HOST/etc/services") == 0:0:644 ]]
[[ $(stat -c '%u:%g:%a' "$STAGE_HOST/etc/protocols") == 0:0:644 ]]
python3 "$CAPTURE_TOOL" \
    --stage "$STAGE_HOST" \
    --name iana-etc \
    --version 20250807 \
    --source-url https://github.com/Mic92/iana-etc/releases/download/20250807/iana-etc-20250807.tar.gz \
    --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST"
chmod 0644 "$MANIFEST"
compare_rootfs
check_alp_invariants
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
