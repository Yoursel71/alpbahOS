#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Expect 5.45.4 isolated package stage. Builder only.
# Review this draft before running it. It never merges staged files into /mnt/lfs/usr.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/expect-5.45.4-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-expect-stage-r1
STAGE_CHROOT=/tmp/alp-m04-expect-stage-r1
SOURCE=/mnt/lfs/sources/expect5.45.4.tar.gz
PATCH=/mnt/lfs/sources/expect-5.45.4-gcc15-1.patch
LOG=/mnt/lfs/tmp/alp-logs/m04-expect-5.45.4-stage-20260924-r1.log
MANIFEST=/mnt/lfs/tmp/alp-m04-expect-5.45.4-manifest-20260924-r1.json
PREFLIGHT=/mnt/lfs/tmp/alp-m04-expect-5.45.4-preflight-20260924-r1.log
EXPECTED_MD5=00fce8de158422f5ccd2666512329bd2
# SourceForge's published expect5.45.4.tar.gz.SHA256 sidecar.
EXPECTED_SHA256=49a7da83b0bdd9f46d04a04deec19c7767bb9a323e40c4781f89caf760b92c34
PATCH_MD5=0ca4d6bb8d572fbcdb13cb36cd34833e
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
SOURCE_URL=https://prdownloads.sourceforge.net/expect/expect5.45.4.tar.gz
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
        umount "${MOUNTS[$i]}"
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

if [[ $EUID -ne 0 ]]; then
    echo 'Run this script as root on the Builder.' >&2
    exit 1
fi
[[ -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" && -f "$PATCH" ]]
[[ -f "$CAPTURE_TOOL" && -f "$COMPARE_TOOL" ]]
[[ -f "$LFS/usr/lib/tclConfig.sh" && -f "$LFS/usr/include/tcl.h" ]]
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
[[ $(md5sum "$PATCH" | awk '{print $1}') == "$PATCH_MD5" ]]
[[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    database = json.load(stream)
if database.get("schema_version") != 1 or database.get("packages") != {}:
    raise SystemExit("Refusing: pinned Alp database is not schema 1 with an empty package map")
PY

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE") patch=$(sha256sum "$PATCH")"
echo "alp.py=$(sha256sum "$LFS/usr/lib/alp/alp.py")"
df -h "$LFS"
[[ ! -s /sys/block/nbd0/pid ]]
mkdir -p "$BUILD" "$STAGE_HOST"
tar -xzf "$SOURCE" -C "$BUILD" --strip-components=1
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

# LFS 8.17.1: GCC 15 patch, exact configure flags, make, make test.
# make test requires working /dev/pts; stop if the book's PTY probe fails.
PTY_OUTPUT=$(chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
    HOME=/home/tester TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /usr/bin/python3 -c 'from pty import spawn; spawn(["echo", "ok"])')
PTY_OUTPUT=${PTY_OUTPUT//$'\r'/}
[[ $PTY_OUTPUT == ok ]]
echo 'EXPECT_PTY_PROBE=ok'

chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
    HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c '
        cd /build/expect-5.45.4-m04-r1
        patch -Np1 -i /sources/expect-5.45.4-gcc15-1.patch
        ./configure --prefix=/usr \
                    --with-tcl=/usr/lib \
                    --enable-shared \
                    --disable-rpath \
                    --mandir=/usr/share/man \
                    --with-tclinclude=/usr/include
        make
    '

chown -R 101:101 "$BUILD"
chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
    HOME=/home/tester TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c 'cd /build/expect-5.45.4-m04-r1 && make test'

chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        cd /build/expect-5.45.4-m04-r1
        make DESTDIR=/tmp/alp-m04-expect-stage-r1 install
        ln -svf expect5.45.4/libexpect5.45.4.so \
            /tmp/alp-m04-expect-stage-r1/usr/lib/libexpect5.45.4.so
    '

[[ -x "$STAGE_HOST/usr/bin/expect" ]]
[[ -e "$STAGE_HOST/usr/lib/expect5.45.4/libexpect5.45.4.so" ]]
[[ -L "$STAGE_HOST/usr/lib/libexpect5.45.4.so" ]]
EXPECT_VERSION=$(chroot "$LFS" /usr/bin/env -i \
    PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib/expect5.45.4" \
    "$STAGE_CHROOT/usr/bin/expect" -c 'puts [exp_version]')
[[ $EXPECT_VERSION == 5.45.4 ]]
echo "EXPECT_STAGE_SMOKE=$EXPECT_VERSION"

python3 "$CAPTURE_TOOL" \
    --stage "$STAGE_HOST" \
    --name expect \
    --version 5.45.4 \
    --source-url "$SOURCE_URL" \
    --source-sha256 "$EXPECTED_SHA256" \
    --output "$MANIFEST"
set +e
python3 "$COMPARE_TOOL" --manifest "$MANIFEST" --root "$LFS" >"$PREFLIGHT" 2>&1
preflight_status=$?
set -e
if (( preflight_status == 0 )); then
    echo "PREFLIGHT_RESULT=exact; details=$PREFLIGHT"
elif (( preflight_status == 1 )); then
    echo "PREFLIGHT_RESULT=mismatches; review=$PREFLIGHT"
else
    echo "PREFLIGHT_ERROR: compare tool exited $preflight_status; details=$PREFLIGHT" >&2
    exit "$preflight_status"
fi

[[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
python3 - "$LFS/var/lib/alp/db.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    database = json.load(stream)
if database.get("schema_version") != 1 or database.get("packages") != {}:
    raise SystemExit("Alp database changed during isolated Expect stage")
PY
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
