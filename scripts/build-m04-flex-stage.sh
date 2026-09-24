#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Flex 2.6.4 isolated package stage. Run on Builder as root.
# Copy capture-package-manifest.py and compare-package-manifest.py to /home/sa
# before running. All build, stage, manifest, preflight, and log files stay
# under /mnt/lfs. No install is made to rootfs /usr or alp's database.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/flex-2.6.4-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-flex-stage-r1
STAGE_CHROOT=/tmp/alp-m04-flex-stage-r1
SOURCE=/mnt/lfs/sources/flex-2.6.4.tar.gz
LOG=/mnt/lfs/tmp/alp-logs/m04-flex-2.6.4-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-logs/flex-2.6.4-2026-09-24.json
PREFLIGHT=/mnt/lfs/tmp/alp-logs/flex-2.6.4-2026-09-24-preflight.log
CAPTURE_TOOL=${CAPTURE_TOOL:-/home/sa/capture-package-manifest.py}
COMPARE_TOOL=${COMPARE_TOOL:-/home/sa/compare-package-manifest.py}
EXPECTED_MD5=2882e3179748cc9f9c23ec593d6adc8d
EXPECTED_SHA256=e87aae032bf07c26f85ac0ed3250998c37621d95f8bd748b31f15b33c45ee995
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
    (( compare_status <= 1 ))
    echo "PREFLIGHT_EXIT=$compare_status (1 means one or more differences were reported)"
    chmod 0644 "$PREFLIGHT"
    cat "$PREFLIGHT"
}

flex_smoke() {
    local version
    version=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/flex" --version)
    [[ $version == "flex 2.6.4" ]]
    chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
        /bin/bash --noprofile --norc -c '
            set -e
            cd /build/flex-2.6.4-m04-r1
            /tmp/alp-m04-flex-stage-r1/usr/bin/flex -o smoke.c smoke.l
            test -s smoke.c
        '
    [[ $(readlink "$STAGE_HOST/usr/bin/lex") == flex ]]
    [[ $(readlink "$STAGE_HOST/usr/share/man/man1/lex.1") == flex.1 ]]
    [[ $(readlink "$STAGE_HOST/usr/bin/flex++") == flex ]]
    echo "FLEX_STAGE_SMOKE=$version; scanner generation passed"
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
    [[ -d "$BUILD" && -s "$BUILD/smoke.l" ]]
    [[ -d "$STAGE_HOST" && -x "$STAGE_HOST/usr/bin/flex" && -x "$STAGE_HOST/usr/lib/libfl.so" ]]
    [[ -f "$LOG" && -f "$MANIFEST" ]]
    exec >>"$LOG" 2>&1
    echo "STAGE_VERIFY_ONLY=$(date -Is) Builder=$(hostname)"
    chmod 0644 "$MANIFEST"
    flex_smoke
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
tar -xzf "$SOURCE" -C "$BUILD" --strip-components=1
chown -R 1001:1001 "$BUILD"
cat > "$BUILD/smoke.l" <<'EOF'
%%
[a-z]+ ECHO;
%%
EOF
chown 1001:1001 "$BUILD/smoke.l"

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
        cd /build/flex-2.6.4-m04-r1
        ./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4 --disable-static
        make -j2
    '
chown -R 101:101 "$BUILD"
chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
    HOME=/home/tester TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c 'cd /build/flex-2.6.4-m04-r1 && make check'
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c 'cd /build/flex-2.6.4-m04-r1 && make DESTDIR=/tmp/alp-m04-flex-stage-r1 install'
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        set -e
        ln -sv flex /tmp/alp-m04-flex-stage-r1/usr/bin/lex
        ln -sv flex.1 /tmp/alp-m04-flex-stage-r1/usr/share/man/man1/lex.1
    '

flex_smoke
python3 "$CAPTURE_TOOL" \
    --stage "$STAGE_HOST" \
    --name flex \
    --version 2.6.4 \
    --source-url https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz \
    --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST"
chmod 0644 "$MANIFEST"
compare_rootfs
check_alp_invariants
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
