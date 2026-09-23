#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "FAILED line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

# Run on Builder as root. The only target is the authoritative LFS rootfs.
ROOTFS=/mnt/lfs
ALP_SOURCE=${1:?Pass the alp.py extracted from commit e8b0376}
EXPECTED_ALP=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
DBUS_ARCHIVE=$ROOTFS/sources/dbus-1.16.2.tar.xz
EXPECTED_DBUS_ARCHIVE=0ba2a1a4b16afe7bceb2c07e9ce99a8c2c3508e5dec290dbb643384bd6beb7e2

[[ $EUID -eq 0 && -d $ROOTFS/etc && -f $ROOTFS/usr/lib/alp/alp.py ]]
[[ -f $ALP_SOURCE && $(sha256sum "$ALP_SOURCE" | cut -d' ' -f1) == "$EXPECTED_ALP" ]]
test -f "$ROOTFS/usr/lib/systemd/system/getty@.service"
test -f "$ROOTFS/usr/lib/systemd/system/systemd-resolved.service"
[[ -f $DBUS_ARCHIVE && $(sha256sum "$DBUS_ARCHIVE" | cut -d' ' -f1) == "$EXPECTED_DBUS_ARCHIVE" ]]

mkdir -p "$ROOTFS/etc/systemd/system/getty.target.wants" \
    "$ROOTFS/etc/systemd/system/sysinit.target.wants" \
    "$ROOTFS/usr/lib/systemd/user" \
    "$ROOTFS/tmp/alp-logs"
ln -sfn /usr/lib/systemd/system/getty@.service \
    "$ROOTFS/etc/systemd/system/getty.target.wants/getty@tty1.service"
ln -sfn /usr/lib/systemd/system/systemd-resolved.service \
    "$ROOTFS/etc/systemd/system/sysinit.target.wants/systemd-resolved.service"
ln -sfn /usr/lib/systemd/system/systemd-resolved.service \
    "$ROOTFS/etc/systemd/system/dbus-org.freedesktop.resolve1.service"
ln -sfn ../run/systemd/resolve/stub-resolv.conf "$ROOTFS/etc/resolv.conf"

# Install the upstream D-Bus 1.16.2 user-bus units from the already-verified
# source archive. PipeWire's packaged user unit Requires=dbus.service; the
# rootfs previously had only the system bus units, so PipeWire could not start.
tmp_service=$(mktemp "$ROOTFS/tmp/alp-logs/dbus.service.XXXXXX")
tmp_socket=$(mktemp "$ROOTFS/tmp/alp-logs/dbus.socket.XXXXXX")
tar -xOf "$DBUS_ARCHIVE" dbus-1.16.2/bus/systemd-user/dbus.service.in \
    | sed -e 's|@EXPANDED_BINDIR@|/usr/bin|g' -e 's|@SYSTEMCTL@|/usr/bin/systemctl|g' > "$tmp_service"
tar -xOf "$DBUS_ARCHIVE" dbus-1.16.2/bus/systemd-user/dbus.socket.in \
    | sed -e 's|@SYSTEMCTL@|/usr/bin/systemctl|g' > "$tmp_socket"
! grep -q '@[A-Z_]*@' "$tmp_service" "$tmp_socket"
install -o 0 -g 0 -m 0644 "$tmp_service" "$ROOTFS/usr/lib/systemd/user/dbus.service"
install -o 0 -g 0 -m 0644 "$tmp_socket" "$ROOTFS/usr/lib/systemd/user/dbus.socket"
rm -f -- "$tmp_service" "$tmp_socket"

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
grep -q '^Requires=dbus.socket$' "$ROOTFS/usr/lib/systemd/user/dbus.service"
grep -q '^ExecStart=/usr/bin/dbus-daemon --session --address=systemd:' "$ROOTFS/usr/lib/systemd/user/dbus.service"
grep -q '^ListenStream=%t/bus$' "$ROOTFS/usr/lib/systemd/user/dbus.socket"
grep -q '^ExecStartPost=-/usr/bin/systemctl --user set-environment DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus$' "$ROOTFS/usr/lib/systemd/user/dbus.socket"

sha256sum "$target"
readlink "$ROOTFS/etc/systemd/system/getty.target.wants/getty@tty1.service"
readlink "$ROOTFS/etc/systemd/system/sysinit.target.wants/systemd-resolved.service"
readlink "$ROOTFS/etc/systemd/system/dbus-org.freedesktop.resolve1.service"
readlink "$ROOTFS/etc/resolv.conf"
sha256sum "$ROOTFS/usr/lib/systemd/user/dbus.service" "$ROOTFS/usr/lib/systemd/user/dbus.socket"
systemctl --root="$ROOTFS" is-enabled getty@tty1.service systemd-resolved.service
