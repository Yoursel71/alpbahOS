#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "FAILED line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

# Run on Builder as root. The only target is the authoritative LFS rootfs.
ROOTFS=/mnt/lfs
ALP_SOURCE=${1:?Pass the alp.py extracted from commit e8b0376}
EXPECTED_ALP=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132

[[ $EUID -eq 0 && -d $ROOTFS/etc && -f $ROOTFS/usr/lib/alp/alp.py ]]
[[ -f $ALP_SOURCE && $(sha256sum "$ALP_SOURCE" | cut -d' ' -f1) == "$EXPECTED_ALP" ]]
test -f "$ROOTFS/usr/lib/systemd/system/getty@.service"
test -f "$ROOTFS/usr/lib/systemd/system/systemd-resolved.service"

mkdir -p "$ROOTFS/etc/systemd/system/getty.target.wants" \
    "$ROOTFS/etc/systemd/system/sysinit.target.wants" \
    "$ROOTFS/tmp/alp-logs"
ln -sfn /usr/lib/systemd/system/getty@.service \
    "$ROOTFS/etc/systemd/system/getty.target.wants/getty@tty1.service"
ln -sfn /usr/lib/systemd/system/systemd-resolved.service \
    "$ROOTFS/etc/systemd/system/sysinit.target.wants/systemd-resolved.service"
ln -sfn /usr/lib/systemd/system/systemd-resolved.service \
    "$ROOTFS/etc/systemd/system/dbus-org.freedesktop.resolve1.service"
ln -sfn ../run/systemd/resolve/stub-resolv.conf "$ROOTFS/etc/resolv.conf"

target="$ROOTFS/usr/lib/alp/alp.py"
if [[ $(sha256sum "$target" | cut -d' ' -f1) != "$EXPECTED_ALP" ]]; then
    cp -a "$target" "$ROOTFS/tmp/alp-logs/alp.py.before-e8b0376"
    install -o 0 -g 0 -m 0755 "$ALP_SOURCE" "$target"
fi

[[ $(sha256sum "$target" | cut -d' ' -f1) == "$EXPECTED_ALP" ]]
[[ $(readlink "$ROOTFS/etc/systemd/system/getty.target.wants/getty@tty1.service") == /usr/lib/systemd/system/getty@.service ]]
[[ $(readlink "$ROOTFS/etc/systemd/system/sysinit.target.wants/systemd-resolved.service") == /usr/lib/systemd/system/systemd-resolved.service ]]
[[ $(readlink "$ROOTFS/etc/systemd/system/dbus-org.freedesktop.resolve1.service") == /usr/lib/systemd/system/systemd-resolved.service ]]
[[ $(readlink "$ROOTFS/etc/resolv.conf") == ../run/systemd/resolve/stub-resolv.conf ]]

sha256sum "$target"
readlink "$ROOTFS/etc/systemd/system/getty.target.wants/getty@tty1.service"
readlink "$ROOTFS/etc/systemd/system/sysinit.target.wants/systemd-resolved.service"
readlink "$ROOTFS/etc/systemd/system/dbus-org.freedesktop.resolve1.service"
readlink "$ROOTFS/etc/resolv.conf"
systemctl --root="$ROOTFS" is-enabled getty@tty1.service systemd-resolved.service
