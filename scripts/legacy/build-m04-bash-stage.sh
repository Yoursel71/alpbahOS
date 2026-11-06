#!/usr/bin/env bash
set -Eeuo pipefail

# Build and test the LFS 12.4-systemd Bash 5.3 package in the Builder's
# /mnt/lfs chroot, then install it into an isolated DESTDIR for comparison.
# This script does not merge any staged file into the rootfs or alp database.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/bash-5.3-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-bash-stage-r1
STAGE_CHROOT=/tmp/alp-m04-bash-stage-r1
SOURCE=/mnt/lfs/sources/bash-5.3.tar.gz
LOG=/mnt/lfs/tmp/alp-logs/m04-bash-5.3-stage-20260924-r1.log
EXPECTED_MD5=977c8c0c5ae6309191e7768e28ebc951
EXPECTED_SHA256=0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132

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
    else
        echo "STAGE_INCOMPLETE: preserve build/stage/log for diagnosis" >&2
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

if [[ $EUID -ne 0 ]]; then
    echo 'Run this script as root on the Builder.' >&2
    exit 1
fi
[[ -d "$LFS/etc" && -x "$LFS/usr/bin/bash" ]]
[[ -f "$SOURCE" ]]
[[ ! -e "$BUILD" ]]
[[ ! -e "$STAGE_HOST" ]]
[[ ! -e "$LOG" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) ]]
[[ ! -s /sys/block/nbd0/pid ]]
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
[[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
grep -q '"packages": {}' "$LFS/var/lib/alp/db.json"

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
echo "alp.py=$(sha256sum "$LFS/usr/lib/alp/alp.py")"
df -h "$LFS"

mkdir -p "$BUILD" "$STAGE_HOST"
tar -xzf "$SOURCE" -C "$BUILD" --strip-components=1
cat > "$BUILD/run-bash-tests.exp" <<'EXPECT'
set timeout -1
cd /build/bash-5.3-m04-r1
spawn make tests
expect eof
lassign [wait] _ _ _ value
exit $value
EXPECT
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

chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
    HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c '
        cd /build/bash-5.3-m04-r1
        ./configure --prefix=/usr --without-bash-malloc --with-installed-readline --docdir=/usr/share/doc/bash-5.3
        make -j2
    '

# LFS runs the Bash test suite as its unprivileged tester account through
# Expect, which supplies the pseudo-terminal the suite requires.
chown -R 101:101 "$BUILD"
chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
    HOME=/home/tester TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /usr/bin/expect /build/bash-5.3-m04-r1/run-bash-tests.exp

chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        cd /build/bash-5.3-m04-r1
        make DESTDIR=/tmp/alp-m04-bash-stage-r1 install
    '

rm -f "$STAGE_HOST/usr/share/info/dir"
if [[ ! -e "$STAGE_HOST/usr/bin/sh" ]]; then
    ln -s bash "$STAGE_HOST/usr/bin/sh"
fi
[[ $(chroot "$LFS" "$STAGE_CHROOT/usr/bin/bash" --noprofile --norc -c 'printf "%s\n" "$((20 + 22))"') == 42 ]]
chroot "$LFS" "$STAGE_CHROOT/usr/bin/bash" --version | head -n 1
echo 'BASH_ARITHMETIC_SMOKE=42'

[[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
grep -q '"packages": {}' "$LFS/var/lib/alp/db.json"
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
