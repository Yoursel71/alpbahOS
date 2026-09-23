#!/usr/bin/env bash
set -Eeuo pipefail

# Enable the tty1 console login and deploy the fixed alp engine into the
# Gen2 test image only. Never touches /mnt/lfs. Writes are preflight-checked
# and the previous alp.py is backed up before being overwritten.
IMG=/tmp/alpbahOS-m2-ssh-gen2-test.vhdx
EXPECTED_IMG=da7b69b3d43ea75250b3f631aef1e7c3c0357ca49be02863173c96c18139a849
NEW_ALP=/tmp/claude-alp-fixed.py
EXPECTED_ALP=7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132
NBD=/dev/nbd0
WORK=$(mktemp -d /tmp/alpbahos-gen2-login-alp.XXXXXX)
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
[[ -f $IMG ]] || { echo "Missing test image: $IMG" >&2; exit 1; }
[[ -f $NEW_ALP ]] || { echo "Missing fixed alp.py source: $NEW_ALP" >&2; exit 1; }
ACTUAL_IMG=$(sha256sum "$IMG" | cut -d' ' -f1)
[[ $ACTUAL_IMG == "$EXPECTED_IMG" ]] || { echo "Unexpected source image hash: $ACTUAL_IMG" >&2; exit 1; }
ACTUAL_ALP=$(sha256sum "$NEW_ALP" | cut -d' ' -f1)
[[ $ACTUAL_ALP == "$EXPECTED_ALP" ]] || { echo "Unexpected alp.py source hash: $ACTUAL_ALP" >&2; exit 1; }

modprobe nbd max_part=8
[[ ! -s /sys/block/nbd0/pid ]] || { echo "$NBD is already in use." >&2; exit 1; }
qemu-nbd --connect="$NBD" --format=vhdx "$IMG"
ATTACHED=1
partprobe "$NBD"
udevadm settle
mkdir -p "$MOUNT"
mount "${NBD}p2" "$MOUNT"
ROOT_MOUNTED=1

# --- tty1 console login ---
test -f "$MOUNT/usr/lib/systemd/system/getty@.service"
mkdir -p "$MOUNT/etc/systemd/system/getty.target.wants"
ln -sfn /usr/lib/systemd/system/getty@.service \
    "$MOUNT/etc/systemd/system/getty.target.wants/getty@tty1.service"
test -L "$MOUNT/etc/systemd/system/getty.target.wants/getty@tty1.service"

# --- fixed alp engine ---
target="$MOUNT/usr/lib/alp/alp.py"
test -f "$target"
cp -a "$target" "/tmp/alpbahOS-m2-gen2-alp.py.before-e8b0376"
old_mode=$(stat -c '%a' "$target")
old_owner=$(stat -c '%U:%G' "$target")
install -m "$old_mode" -o "${old_owner%%:*}" -g "${old_owner##*:}" "$NEW_ALP" "$target"
sha256sum "$target"
[[ $(sha256sum "$target" | cut -d' ' -f1) == "$EXPECTED_ALP" ]]

sync
umount "$MOUNT"
ROOT_MOUNTED=0
qemu-nbd --disconnect "$NBD"
ATTACHED=0
qemu-img check "$IMG"
sha256sum "$IMG"
