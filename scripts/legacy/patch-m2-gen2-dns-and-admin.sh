#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "FAILED at line $LINENO: $BASH_COMMAND" >&2' ERR

# Gen2 test image only (never /mnt/lfs):
#  1. enable systemd-resolved (/etc/resolv.conf already points at its stub file
#     but the unit was never enabled, so every hostname lookup failed);
#  2. add a local console account "admin" (wheel) with a password chosen by the
#     user for this throwaway test VM. SSH stays key-only (AllowUsers sa).
# The plaintext password comes from ADMIN_PASSWORD and is never echoed.
IMG=${IMG:-/tmp/claude-gen2-work.vhdx}
ADMIN_PASSWORD=${ADMIN_PASSWORD:?Set ADMIN_PASSWORD}
NBD=/dev/nbd0
WORK=$(mktemp -d /tmp/claude-gen2-admin.XXXXXX)
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
[[ ! -s /sys/block/nbd0/pid ]] || { echo "$NBD is already in use (another agent?)." >&2; exit 1; }

modprobe nbd max_part=8
qemu-nbd --connect="$NBD" --format=vhdx "$IMG"
ATTACHED=1
partprobe "$NBD"
udevadm settle
mkdir -p "$MOUNT"
mount "${NBD}p2" "$MOUNT"
ROOT_MOUNTED=1

# --- DNS ---
unit=/usr/lib/systemd/system/systemd-resolved.service
test -f "$MOUNT$unit"
ln -sfn ../run/systemd/resolve/stub-resolv.conf "$MOUNT/etc/resolv.conf"
mkdir -p "$MOUNT/etc/systemd/system/sysinit.target.wants"
ln -sfn "$unit" "$MOUNT/etc/systemd/system/sysinit.target.wants/systemd-resolved.service"
ln -sfn "$unit" "$MOUNT/etc/systemd/system/dbus-org.freedesktop.resolve1.service"

# --- admin account ---
if grep -q '^admin:' "$MOUNT/etc/passwd"; then
    echo 'admin already exists; leaving account unchanged' >&2
else
    grep -q '^users:' "$MOUNT/etc/group"
    grep -q '^wheel:' "$MOUNT/etc/group"
    if awk -F: '$3 == 1001 { f=1 } END { exit !f }' "$MOUNT/etc/passwd"; then
        echo 'UID 1001 already taken' >&2; exit 1
    fi
    chroot "$MOUNT" /usr/sbin/useradd -m -u 1001 -g users -G wheel -s /bin/bash admin
    hash=$(printf '%s' "$ADMIN_PASSWORD" | openssl passwd -6 -stdin)
    printf 'admin:%s\n' "$hash" | chroot "$MOUNT" /usr/sbin/chpasswd -e
    unset hash
fi
grep -q '^admin:' "$MOUNT/etc/passwd"
awk -F: '$1 == "admin" && $2 ~ /^\$6\$/ { ok=1 } END { exit !ok }' "$MOUNT/etc/shadow"
test -d "$MOUNT/home/admin"
grep -E '^(admin|wheel):' "$MOUNT/etc/passwd" "$MOUNT/etc/group"
test -L "$MOUNT/etc/systemd/system/sysinit.target.wants/systemd-resolved.service"

sync
umount "$MOUNT"
ROOT_MOUNTED=0
qemu-nbd --disconnect "$NBD"
ATTACHED=0
qemu-img check "$IMG"
sha256sum "$IMG"
