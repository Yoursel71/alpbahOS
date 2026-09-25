#!/usr/bin/env bash
# Test-image only. Offline NBD patch of a COPY of a Gen2 image so agents never need the VM console:
#  - passwordless sudo for sa/admin (test accounts)
#  - tty1 autologin as admin (real seat0 session)
#  - admin login shell starts Plasma Wayland once per boot when /etc/alp-autostart-plasma exists
# Never touches /mnt/lfs. VM must be stopped.
set -Eeuo pipefail
trap 'echo "FAILED at line $LINENO: $BASH_COMMAND" >&2' ERR
IMG=${IMG:?set IMG}
NBD=/dev/nbd0
WORK=$(mktemp -d /tmp/claude-autoseat.XXXXXX); MOUNT=$WORK/root; ATTACHED=0; MOUNTED=0
cleanup() { set +e; ((MOUNTED)) && umount "$MOUNT"; ((ATTACHED)) && qemu-nbd --disconnect "$NBD" >/dev/null 2>&1; rm -rf -- "$WORK"; }
trap cleanup EXIT
[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
[[ ! -s /sys/block/nbd0/pid ]] || { echo "$NBD busy" >&2; exit 1; }
modprobe nbd max_part=8
qemu-nbd --connect="$NBD" --format=vhdx "$IMG"; ATTACHED=1
partprobe "$NBD"; udevadm settle
mkdir -p "$MOUNT"; mount "${NBD}p2" "$MOUNT"; MOUNTED=1

install -d -m 0750 "$MOUNT/etc/sudoers.d"
printf 'sa ALL=(ALL) NOPASSWD:ALL\nadmin ALL=(ALL) NOPASSWD:ALL\n' > "$MOUNT/etc/sudoers.d/90-alpbah-test"
chmod 0440 "$MOUNT/etc/sudoers.d/90-alpbah-test"

install -d "$MOUNT/etc/systemd/system/getty@tty1.service.d"
cat > "$MOUNT/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<'INNER'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \u' --noclear --autologin admin %I $TERM
INNER

cat > "$MOUNT/home/admin/.bash_profile" <<'INNER'
export PATH=/opt/kf6/bin:$PATH
if [ "$(tty)" = /dev/tty1 ] && [ -e /etc/alp-autostart-plasma ] && [ ! -e /run/alp-plasma-tried ]; then
    : > /run/alp-plasma-tried
    exec /opt/kf6/bin/startplasma-wayland > /var/tmp/alp-plasma-autostart.log 2>&1
fi
INNER
chown 1001:999 "$MOUNT/home/admin/.bash_profile"
: > "$MOUNT/etc/alp-autostart-plasma"

sync; umount "$MOUNT"; MOUNTED=0; qemu-nbd --disconnect "$NBD"; ATTACHED=0
qemu-img check "$IMG"; sha256sum "$IMG"
