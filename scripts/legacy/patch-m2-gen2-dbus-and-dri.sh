#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "FAILED at line $LINENO: $BASH_COMMAND" >&2' ERR

# Gen2 test image only (never /mnt/lfs):
#  1. enable systemd user D-Bus (dbus.socket/dbus.service were entirely
#     missing under /usr/lib/systemd/user on this image -- built from an
#     /mnt/lfs snapshot predating that fix);
#  2. symlink Mesa's existing megadriver (libgallium-25.1.8.so) into
#     /usr/lib/dri/ under the classic per-vendor names the DRI loader
#     searches for (swrast_dri.so, kms_swrast_dri.so). Mesa's own build
#     compiled and installed the megadriver to /usr/lib but never created
#     these symlinks (confirmed: no such step in mesa-build.log).
# Offline via NBD; VM must be stopped. Never touches /mnt/lfs.
IMG=${IMG:-/tmp/claude-gen2-v3.vhdx}
EXPECTED_IMG=f1c7cb4a3278e6550bc3180e53cae469dff00c9244d6bb2ff059d7cc48c6d1f1
NBD=/dev/nbd0
WORK=$(mktemp -d /tmp/claude-gen2-dbusdri.XXXXXX)
MOUNT=$WORK/root
ATTACHED=0
ROOT_MOUNTED=0

cleanup() {
    set +e
    if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
    if (( ATTACHED )); then qemu-nbd --disconnect "$NBD" >/dev/null 2>&1; fi
    rm -rf -- "$WORK"
}
trap cleanup EXIT

[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
[[ -f $IMG ]] || { echo "Missing image: $IMG" >&2; exit 1; }
ACTUAL_IMG=$(sha256sum "$IMG" | cut -d' ' -f1)
[[ $ACTUAL_IMG == "$EXPECTED_IMG" ]] || { echo "Unexpected source image hash: $ACTUAL_IMG" >&2; exit 1; }
[[ ! -s /sys/block/nbd0/pid ]] || { echo "$NBD is already in use (another agent?)." >&2; exit 1; }

modprobe nbd max_part=8
qemu-nbd --connect="$NBD" --format=vhdx "$IMG"
ATTACHED=1
partprobe "$NBD"
udevadm settle
mkdir -p "$MOUNT"
mount "${NBD}p2" "$MOUNT"
ROOT_MOUNTED=1

echo "== dbus user units"
unit_sock="$MOUNT/usr/lib/systemd/user/dbus.socket"
unit_svc="$MOUNT/usr/lib/systemd/user/dbus.service"
mkdir -p "$MOUNT/usr/lib/systemd/user"
cat > "$unit_sock" <<'INNER'
[Unit]
Description=D-Bus User Message Bus Socket

[Socket]
ListenStream=%t/bus
ExecStartPost=-/usr/bin/systemctl --user set-environment DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus
INNER
cat > "$unit_svc" <<'INNER'
[Unit]
Description=D-Bus User Message Bus
Documentation=man:dbus-daemon(1)
Requires=dbus.socket

[Service]
Type=notify
NotifyAccess=main
ExecStart=/usr/bin/dbus-daemon --session --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
ExecReload=/usr/bin/dbus-send --print-reply --session --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig
Slice=session.slice
INNER
chmod 644 "$unit_sock" "$unit_svc"
mkdir -p "$MOUNT/etc/systemd/user/sockets.target.wants"
ln -sfn /usr/lib/systemd/user/dbus.socket "$MOUNT/etc/systemd/user/sockets.target.wants/dbus.socket"
ln -sfn /usr/lib/systemd/user/dbus.service "$MOUNT/etc/systemd/user/sockets.target.wants/dbus.service"
test -L "$MOUNT/etc/systemd/user/sockets.target.wants/dbus.socket"

echo "== mesa dri megadriver symlinks"
megadriver="$MOUNT/usr/lib/libgallium-25.1.8.so"
test -f "$megadriver"
mkdir -p "$MOUNT/usr/lib/dri"
for n in swrast_dri.so kms_swrast_dri.so; do
    ln -sfn ../libgallium-25.1.8.so "$MOUNT/usr/lib/dri/$n"
    test -L "$MOUNT/usr/lib/dri/$n"
done
ls -la "$MOUNT/usr/lib/dri/"

sync
umount "$MOUNT"
ROOT_MOUNTED=0
qemu-nbd --disconnect "$NBD"
ATTACHED=0
qemu-img check "$IMG"
sha256sum "$IMG"
