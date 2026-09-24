#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Bc 7.0.3 isolated package stage. Run on Builder as root.
# Copy capture-package-manifest.py and compare-package-manifest.py to /home/sa
# before running. All build, stage, manifest, preflight, and log files stay
# under /mnt/lfs. The rootfs /usr tree and alp database are never installed to.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/bc-7.0.3-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-bc-stage-r1
STAGE_CHROOT=/tmp/alp-m04-bc-stage-r1
SOURCE=/mnt/lfs/sources/bc-7.0.3.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-bc-7.0.3-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-logs/bc-7.0.3-2026-09-24.json
PREFLIGHT=/mnt/lfs/tmp/alp-logs/bc-7.0.3-2026-09-24-preflight.log
CAPTURE_TOOL=${CAPTURE_TOOL:-/home/sa/capture-package-manifest.py}
COMPARE_TOOL=${COMPARE_TOOL:-/home/sa/compare-package-manifest.py}
EXPECTED_MD5=ad4db5a0eb4fdbb3f6813be4b6b3da74
EXPECTED_SHA256=91eb74caed0ee6655b669711a4f350c25579778694df248e28363318e03c7fc4
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

compare_rootfs() {
    local compare_status=0
    if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" > "$PREFLIGHT"; then
        compare_status=0
    else
        compare_status=$?
    fi
    # The comparator exits 1 after successfully reporting one or more diffs.
    (( compare_status <= 1 ))
    echo "PREFLIGHT_EXIT=$compare_status (1 means one or more differences were reported)"
    chmod 0644 "$PREFLIGHT"
    cat "$PREFLIGHT"
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
grep -q '^tester:.*:101:101:' "$LFS/etc/passwd"
for target in "$LFS/dev" "$LFS/dev/pts" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
    ! mountpoint -q "$target"
done

if [[ ${1:-} == --verify-stage-only ]]; then
    [[ -d "$STAGE_HOST" && -x "$STAGE_HOST/usr/bin/bc" && -x "$STAGE_HOST/usr/bin/dc" ]]
    [[ -f "$LOG" && -f "$MANIFEST" ]]
    exec >>"$LOG" 2>&1
    echo "STAGE_VERIFY_ONLY=$(date -Is) Builder=$(hostname)"
    chmod 0644 "$MANIFEST"
    bc_output=$(printf '2+2\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/bc")
    [[ $bc_output == 4 ]]
    dc_output=$(printf '5 2 + p\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/dc")
    [[ $dc_output == 7 ]]
    echo 'BC_DC_STAGE_SMOKE=passed'
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
mkdir -p "$BUILD" "$STAGE_HOST"
tar -xf "$SOURCE" -C "$BUILD" --strip-components=1
chown -R 1001:1001 "$BUILD"

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

chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
    HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c '
        set -e
        cd /build/bc-7.0.3-m04-r1
        CC="gcc -std=c99" ./configure --prefix=/usr -G -O3 -r
        make -j2
    '
chown -R 101:101 "$BUILD"
chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
    HOME=/home/tester TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c 'cd /build/bc-7.0.3-m04-r1 && make test'
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c 'cd /build/bc-7.0.3-m04-r1 && make DESTDIR=/tmp/alp-m04-bc-stage-r1 install'

[[ -x "$STAGE_HOST/usr/bin/bc" && -x "$STAGE_HOST/usr/bin/dc" ]]
bc_output=$(printf '2+2\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/bc")
[[ $bc_output == 4 ]]
dc_output=$(printf '5 2 + p\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/dc")
[[ $dc_output == 7 ]]
echo 'BC_DC_STAGE_SMOKE=passed'
python3 "$CAPTURE_TOOL" \
    --stage "$STAGE_HOST" \
    --name bc \
    --version 7.0.3 \
    --source-url https://github.com/gavinhoward/bc/releases/download/7.0.3/bc-7.0.3.tar.xz \
    --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST"
chmod 0644 "$MANIFEST"
compare_rootfs
check_alp_invariants
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
