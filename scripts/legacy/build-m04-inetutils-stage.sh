#!/usr/bin/env bash
set -Eeuo pipefail

# LFS 12.4-systemd Inetutils-2.6 isolated package stage. Run on the Builder.

LFS=/mnt/lfs
BUILD=/mnt/lfs/build/inetutils-2.6-m04-r1
STAGE_HOST=/mnt/lfs/tmp/alp-m04-inetutils-stage-r1
STAGE_CHROOT=/tmp/alp-m04-inetutils-stage-r1
SOURCE=/mnt/lfs/sources/inetutils-2.6.tar.xz
LOG=/mnt/lfs/tmp/alp-logs/m04-inetutils-2.6-stage-20260924-r1.log
ALP_SHA256=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
EXPECTED_MD5=401d7d07682a193960bcdecafd03de94
EXPECTED_SHA256=68bedbfeaf73f7d86be2a7d99bcfbd4093d829f52770893919ae174c0b2357ca
MOUNTS=()
FINISHED=0

cleanup() {
    local status=$?
    trap - EXIT
    set +e
    for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
    if findmnt -rn -R "$LFS"; then
        echo "CLEANUP_FAILED: mounts remain below $LFS" >&2
        status=1
    else
        echo "CLEANUP_OK: no mounts remain below $LFS"
    fi
    if (( FINISHED )); then echo "STAGE_OK: $STAGE_HOST"; else echo 'STAGE_INCOMPLETE: preserve build/stage/log for diagnosis' >&2; fi
    exit "$status"
}
trap cleanup EXIT
trap 'status=$?; echo "FAILED line $LINENO status $status: $BASH_COMMAND" >&2; exit "$status"' ERR

[[ $EUID -eq 0 ]]
[[ -d "$LFS/etc" && -x "$LFS/usr/bin/bash" && -f "$SOURCE" ]]
[[ ! -e "$BUILD" && ! -e "$STAGE_HOST" && ! -e "$LOG" ]]
[[ -z $(findmnt -rn -R "$LFS" || true) ]]
[[ ! -s /sys/block/nbd0/pid ]]
[[ -z $(pgrep -x make || true) && -z $(pgrep -x ninja || true) && -z $(pgrep -x cmake || true) ]]
[[ $(md5sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_MD5" ]]
[[ $(sha256sum "$SOURCE" | awk '{print $1}') == "$EXPECTED_SHA256" ]]
[[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
grep -q '"packages": {}' "$LFS/var/lib/alp/db.json"
grep -q '^tester:' "$LFS/etc/passwd"

mkdir -p /mnt/lfs/build /mnt/lfs/tmp/alp-logs
exec > >(tee -a "$LOG") 2>&1
echo "Builder=$(hostname) source=$(sha256sum "$SOURCE")"
df -h "$LFS"
[[ ! -s /sys/block/nbd0/pid ]]
mkdir -p "$BUILD" "$STAGE_HOST"
tar -xf "$SOURCE" -C "$BUILD" --strip-components=1
chown -R 1001:1001 "$BUILD"

bind_mount() {
    local source=$1 target=$2
    if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
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
        cd /build/inetutils-2.6-m04-r1
        sed -i "s/def HAVE_TERMCAP_TGETENT/ 1/" telnet/telnet.c
        ./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var \
            --disable-logger --disable-whois --disable-rcp --disable-rexec \
            --disable-rlogin --disable-rsh --disable-servers
        make -j2
    '
chown -R 101:101 "$BUILD"
chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
    HOME=/home/tester TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
    /bin/bash --noprofile --norc -c 'cd /build/inetutils-2.6-m04-r1 && make check'
chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    /bin/bash --noprofile --norc -c '
        cd /build/inetutils-2.6-m04-r1
        make DESTDIR=/tmp/alp-m04-inetutils-stage-r1 install
    '

chroot "$LFS" "$STAGE_CHROOT/usr/bin/ftp" --version | head -n 1
[[ -x "$STAGE_HOST/usr/bin/ftp" ]]
echo 'INETUTILS_STAGE_SMOKE=passed'
[[ $(sha256sum "$LFS/usr/lib/alp/alp.py" | awk '{print $1}') == "$ALP_SHA256" ]]
grep -q '"packages": {}' "$LFS/var/lib/alp/db.json"
[[ ! -s /sys/block/nbd0/pid ]]
FINISHED=1
