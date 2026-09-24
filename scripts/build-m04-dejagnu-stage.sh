#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd DejaGNU 1.6.3 isolated package stage. Builder only.
# No files are merged into /mnt/lfs; all package installation uses DESTDIR.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/dejagnu-1.6.3-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-dejagnu-stage-r1
STAGE_CHROOT=/tmp/alp-m04-dejagnu-stage-r1
SOURCE=/mnt/lfs/sources/dejagnu-1.6.3.tar.gz
LOG=/mnt/lfs/tmp/alp-logs/m04-dejagnu-1.6.3-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-m04-dejagnu-1.6.3-manifest-20260924-r1.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-dejagnu-1.6.3-preflight-20260924-r1.log
EXPECTED_MD5=68c5208c58236eba447d7d6d1326b821
EXPECTED_SHA256=87daefacd7958b4a69f88c6856dbd1634261963c414079d0c371f589cd66a2e3
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
SOURCE_URL=https://ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.3.tar.gz
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_TOOL="$SCRIPT_DIR/capture-package-manifest.py"
COMPARE_TOOL="$SCRIPT_DIR/compare-package-manifest.py"

MOUNTS=()
FINISHED=0

check_alp_invariants() {
    [[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
    python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    database = json.load(stream)
if database.get("schema_version") != 1 or database.get("packages") != {}:
    raise SystemExit("Refusing: pinned Alp database is not schema 1 with an empty package map")
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
[[ -x "$LFS/usr/bin/expect" && -x "$LFS/usr/bin/tclsh" && -x "$LFS/usr/bin/makeinfo" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" && ! -e "$MANIFEST" && ! -e "$PREFLIGHT" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) ]]
if [[ -e /sys/block/nbd0/pid && -s /sys/block/nbd0/pid ]]; then
    echo "Refusing active NBD device: nbd0 pid=$(cat /sys/block/nbd0/pid)" >&2
    exit 1
fi
for process in make ninja cmake; do
    if pgrep -x "$process" >/dev/null; then
        echo "Refusing concurrent build process: $process" >&2
        exit 1
    fi
done
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
check_alp_invariants
grep -q '^tester:.*:101:101:' "$LFS/etc/passwd"

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
tar -xzf "$SOURCE" -C "$BUILD" --strip-components=1
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
        cd /build/dejagnu-1.6.3-m04-r1
        mkdir build
        cd build
        ../configure --prefix=/usr
        makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
        makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
    '

chown -R 101:101 "$BUILD"
chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
    HOME=/home/tester TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c 'cd /build/dejagnu-1.6.3-m04-r1/build && make check'

chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c '
        set -e
        cd /build/dejagnu-1.6.3-m04-r1/build
        make DESTDIR=/tmp/alp-m04-dejagnu-stage-r1 install
        install -v -dm755 /tmp/alp-m04-dejagnu-stage-r1/usr/share/doc/dejagnu-1.6.3
        install -v -m644 doc/dejagnu.html doc/dejagnu.txt \
            /tmp/alp-m04-dejagnu-stage-r1/usr/share/doc/dejagnu-1.6.3
    '

[[ -x "$STAGE_HOST/usr/bin/dejagnu" && -x "$STAGE_HOST/usr/bin/runtest" ]]
[[ -s "$STAGE_HOST/usr/share/doc/dejagnu-1.6.3/dejagnu.html" ]]
[[ -s "$STAGE_HOST/usr/share/doc/dejagnu-1.6.3/dejagnu.txt" ]]
DEJAGNU_VERSION=$(chroot "$LFS" /usr/bin/env -i \
    PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    "$STAGE_CHROOT/usr/bin/runtest" --version)
[[ $DEJAGNU_VERSION == *"DejaGnu version"*"1.6.3"* ]]
echo "DEJAGNU_STAGE_SMOKE=$DEJAGNU_VERSION"

python3 "$CAPTURE_TOOL" \
    --stage "$STAGE_HOST" \
    --name dejagnu \
    --version 1.6.3 \
    --source-url "$SOURCE_URL" \
    --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST"
if python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >"$PREFLIGHT" 2>&1; then
    preflight_status=0
else
    preflight_status=$?
fi
if (( preflight_status == 0 )); then
    echo "PREFLIGHT_RESULT=exact; details=$PREFLIGHT"
elif (( preflight_status == 1 )); then
    echo "PREFLIGHT_RESULT=mismatches; review=$PREFLIGHT"
else
    echo "PREFLIGHT_ERROR: compare tool exited $preflight_status; details=$PREFLIGHT" >&2
    exit "$preflight_status"
fi

check_alp_invariants
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
