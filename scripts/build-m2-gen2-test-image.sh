#!/usr/bin/env bash
set -Eeuo pipefail

# Build a standalone Gen2/UEFI TEST VHDX from Builder /mnt/lfs. The companion
# script first applies the shared fixes to the authoritative rootfs. The admin
# password is placed only in this test image, never in a release rootfs/image.

ROOTFS=/mnt/lfs
OUT=${OUT:-/home/sa/alpbahOS-m2-ssh-gen2-test.vhdx}
ALP_SOURCE=${ALP_SOURCE:?Set ALP_SOURCE to alp.py from commit e8b0376}
ADMIN_PASSWORD=${ADMIN_PASSWORD:?Set ADMIN_PASSWORD for this test image}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SIZE=24G
WORK=$(mktemp -d /tmp/alpbahos-gen2-image.XXXXXX)
NBD=/dev/nbd0
MOUNT=$WORK/root
ATTACHED=0
ROOT_MOUNTED=0
EFI_MOUNTED=0
SUCCESS=0
CREATED=0

cleanup() {
    set +e
    if (( EFI_MOUNTED )); then umount "$MOUNT/boot/efi"; fi
    if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
    if (( ATTACHED )); then
        qemu-nbd --disconnect "$NBD" >/dev/null 2>&1
    fi
    if (( CREATED && ! SUCCESS )); then
        rm -f -- "$OUT"
    fi
    rmdir "$MOUNT" 2>/dev/null
    rm -rf -- "$WORK"
}
trap cleanup EXIT
trap 'printf "FAILED line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
[[ $OUT == /* && $OUT != /tmp/* && $OUT != /mnt/lfs/* ]] || { echo 'OUT must be an absolute path outside /tmp and /mnt/lfs.' >&2; exit 1; }
[[ -d $ROOTFS/etc && -x $ROOTFS/usr/bin/alp ]] || { echo "Invalid rootfs: $ROOTFS" >&2; exit 1; }
[[ ! -e $OUT ]] || { echo "Refusing to overwrite existing image: $OUT" >&2; exit 1; }
test -f "$SCRIPT_DIR/apply-m2-rootfs-fixes.sh"
[[ -x /usr/bin/qemu-img && -x /usr/bin/qemu-nbd && -x /usr/sbin/sgdisk ]] || { echo 'Required image tools are missing.' >&2; exit 1; }
[[ -x /usr/sbin/mkfs.vfat && -x /usr/sbin/mkfs.ext4 && -x /usr/sbin/grub-install ]] || { echo 'Required filesystem/UEFI tools are missing.' >&2; exit 1; }
test -f "$ROOTFS/etc/shadow"
test -f "$ROOTFS/etc/pam.d/login"
grep -q 'pam_systemd.so' "$ROOTFS/etc/pam.d/system-session"
grep -q '^sa:' "$ROOTFS/etc/passwd"
test -s "$ROOTFS/usr/lib/modules/6.16.1-alpbahOS/kernel/sound/drivers/snd-aloop.ko"
grep -qx 'CONFIG_SND_ALOOP=m' "$ROOTFS/boot/config-6.16.1-alpbahOS"
test -f "$ROOTFS/usr/lib/systemd/system/systemd-modules-load.service"
test -s "$ROOTFS/home/sa/.ssh/authorized_keys"
[[ $(readlink "$ROOTFS/etc/systemd/system/multi-user.target.wants/sshd.service") == /usr/lib/systemd/system/sshd.service ]]
[[ $(readlink "$ROOTFS/usr/lib/systemd/user/plasma-kwin_wayland.service") == /opt/kf6/lib/systemd/user/plasma-kwin_wayland.service ]]
test -f "$ROOTFS/opt/kf6/lib/systemd/user/plasma-kwin_wayland.service"
test -f "$ROOTFS/etc/systemd/user/plasma-kwin_wayland.service.d/10-wayland-only.conf"

bash "$SCRIPT_DIR/apply-m2-rootfs-fixes.sh" "$ALP_SOURCE"

test -f "$ROOTFS/usr/lib/systemd/user/dbus.service"
test -f "$ROOTFS/usr/lib/systemd/user/dbus.socket"
grep -q '^ExecStart=/usr/bin/dbus-daemon --session --address=systemd:' "$ROOTFS/usr/lib/systemd/user/dbus.service"
grep -q '^ListenStream=%t/bus$' "$ROOTFS/usr/lib/systemd/user/dbus.socket"

modprobe nbd max_part=8
[[ -b $NBD ]] || { echo "$NBD is unavailable." >&2; exit 1; }
if [[ -s /sys/block/nbd0/pid ]]; then
    echo "$NBD is already in use; refusing to attach." >&2
    exit 1
fi

CREATED=1
qemu-img create -f vhdx -o subformat=dynamic "$OUT" "$SIZE"
qemu-nbd --connect="$NBD" --format=vhdx "$OUT"
ATTACHED=1
sgdisk --zap-all "$NBD"
sgdisk --new=1:0:+1G --typecode=1:ef00 --change-name=1:ALP_EFI \
       --new=2:0:0 --typecode=2:8300 --change-name=2:ALP_ROOT "$NBD"
partprobe "$NBD"
udevadm settle
[[ -b ${NBD}p1 && -b ${NBD}p2 ]] || { echo 'GPT partitions did not appear.' >&2; exit 1; }

mkfs.vfat -F 32 -n ALP_EFI "${NBD}p1"
mkfs.ext4 -F -L ALP_ROOT "${NBD}p2"
mkdir -p "$MOUNT"
mount "${NBD}p2" "$MOUNT"
ROOT_MOUNTED=1
mkdir -p "$MOUNT/boot/efi"
mount "${NBD}p1" "$MOUNT/boot/efi"
EFI_MOUNTED=1

# Skip only Builder caches, transient state, and virtual filesystems. Preserve
# ownership, modes, links, and hardlinks in the operating-system rootfs.
tar --numeric-owner --xattrs --acls --one-file-system \
    --exclude='./dev/*' --exclude='./proc/*' --exclude='./sys/*' \
    --exclude='./run/*' --exclude='./tmp/*' --exclude='./mnt/*' \
    --exclude='./media/*' --exclude='./build/*' --exclude='./sources/*' --exclude='./tools/*' \
    --exclude='./home/lfs/*' --exclude='./var/cache/*' \
    -C "$ROOTFS" -cpf - . | tar --numeric-owner --xattrs --acls -xpf - -C "$MOUNT"

# The ALSA loopback driver is carried in the authoritative rootfs, but loaded
# automatically only in this throwaway test image for guest PCM validation.
mkdir -p "$MOUNT/etc/modules-load.d"
printf 'snd-aloop\n' > "$MOUNT/etc/modules-load.d/90-alpbahos-test-audio.conf"
test -s "$MOUNT/usr/lib/modules/6.16.1-alpbahOS/kernel/sound/drivers/snd-aloop.ko"
grep -qx 'snd-aloop' "$MOUNT/etc/modules-load.d/90-alpbahos-test-audio.conf"

ROOT_UUID=$(blkid -s UUID -o value "${NBD}p2")
EFI_UUID=$(blkid -s UUID -o value "${NBD}p1")
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "${NBD}p2")
printf 'UUID=%s / ext4 defaults 0 1\nUUID=%s /boot/efi vfat umask=0077 0 2\n' \
    "$ROOT_UUID" "$EFI_UUID" > "$MOUNT/etc/fstab"
printf 'alpbahos-m2-gen2\n' > "$MOUNT/etc/hostname"
: > "$MOUNT/etc/machine-id"
mkdir -p "$MOUNT/etc/systemd/network" "$MOUNT/etc/systemd/system/multi-user.target.wants"
cat > "$MOUNT/etc/systemd/network/20-wired.network" <<'NETWORK'
[Match]
Name=eth* en*

[Network]
DHCP=yes
IPv6AcceptRA=yes
NETWORK
ln -sfn /usr/lib/systemd/system/systemd-networkd.service \
    "$MOUNT/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"
ln -sfn /usr/lib/systemd/system/sshd.service \
    "$MOUNT/etc/systemd/system/multi-user.target.wants/sshd.service"

# Only the throwaway test image receives a passworded local console account.
# SSH remains key-only and restricted to sa by sshd_config.
if grep -q '^admin:' "$MOUNT/etc/passwd"; then
    echo 'Refusing to reuse an existing admin account in the test image.' >&2
    exit 1
fi
chroot "$MOUNT" /usr/sbin/useradd -m -u 1001 -g users -G wheel -s /bin/bash admin
admin_hash=$(printf '%s' "$ADMIN_PASSWORD" | openssl passwd -6 -stdin)
printf 'admin:%s\n' "$admin_hash" | chroot "$MOUNT" /usr/sbin/chpasswd -e
unset admin_hash
grep -q '^admin:x:1001:' "$MOUNT/etc/passwd"
awk -F: '$1 == "admin" && $2 ~ /^\$6\$/ { ok=1 } END { exit !ok }' "$MOUNT/etc/shadow"
test -d "$MOUNT/home/admin"
grep -q '^AllowUsers sa$' "$MOUNT/etc/ssh/sshd_config"

grub-install --target=x86_64-efi --efi-directory="$MOUNT/boot/efi" \
    --boot-directory="$MOUNT/boot" --bootloader-id=alpbahOS \
    --removable --no-nvram --recheck --root-directory="$MOUNT"
mkdir -p "$MOUNT/boot/grub"
cat > "$MOUNT/boot/grub/grub.cfg" <<GRUB
set default=0
set timeout=3
search --no-floppy --fs-uuid --set=root $ROOT_UUID
menuentry 'alpbahOS M2 Gen2 test (UEFI)' {
    linux /boot/vmlinuz-6.16.1-alpbahOS root=PARTUUID=$ROOT_PARTUUID rootwait rw console=tty1 console=ttyS0,115200n8
}
GRUB

# Make the removable UEFI application self-contained. This avoids relying on
# an EFI-variable entry or on a firmware-specific GRUB prefix in the ESP.
grub-mkstandalone --format=x86_64-efi \
    --output="$MOUNT/boot/efi/EFI/BOOT/BOOTX64.EFI" \
    --install-modules='part_gpt fat ext2 normal linux search search_fs_uuid configfile' \
    --modules='part_gpt fat ext2 normal linux search search_fs_uuid configfile' \
    --locales='' --fonts='' --themes='' \
    "boot/grub/grub.cfg=$MOUNT/boot/grub/grub.cfg"

sync
grub-file --is-x86_64-efi "$MOUNT/boot/efi/EFI/BOOT/BOOTX64.EFI"
test -f "$MOUNT/boot/vmlinuz-6.16.1-alpbahOS"
test -f "$MOUNT/usr/lib/alp/alp.py"
[[ $(sha256sum "$MOUNT/usr/lib/alp/alp.py" | cut -d' ' -f1) == 7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132 ]]
test -f "$MOUNT/home/sa/.ssh/authorized_keys"
test ! -e "$MOUNT/etc/ssh/ssh_host_ed25519_key"
[[ $(readlink "$MOUNT/etc/systemd/system/getty.target.wants/getty@tty1.service") == /usr/lib/systemd/system/getty@.service ]]
[[ $(readlink "$MOUNT/etc/systemd/system/sysinit.target.wants/systemd-resolved.service") == /usr/lib/systemd/system/systemd-resolved.service ]]
[[ $(readlink "$MOUNT/etc/systemd/system/dbus-org.freedesktop.resolve1.service") == /usr/lib/systemd/system/systemd-resolved.service ]]
[[ $(readlink "$MOUNT/etc/resolv.conf") == ../run/systemd/resolve/stub-resolv.conf ]]
[[ $(readlink "$MOUNT/usr/lib/systemd/user/plasma-kwin_wayland.service") == /opt/kf6/lib/systemd/user/plasma-kwin_wayland.service ]]
grep -q '^ExecStart=/opt/kf6/bin/kwin_wayland_wrapper$' "$MOUNT/etc/systemd/user/plasma-kwin_wayland.service.d/10-wayland-only.conf"
test -f "$MOUNT/usr/lib/systemd/user/dbus.service"
test -f "$MOUNT/usr/lib/systemd/user/dbus.socket"
grep -q '^ExecStart=/usr/bin/dbus-daemon --session --address=systemd:' "$MOUNT/usr/lib/systemd/user/dbus.service"
grep -q '^ListenStream=%t/bus$' "$MOUNT/usr/lib/systemd/user/dbus.socket"
printf 'ROOT_UUID=%s\nEFI_UUID=%s\nROOT_PARTUUID=%s\n' "$ROOT_UUID" "$EFI_UUID" "$ROOT_PARTUUID"
printf 'VHDX=%s\n' "$OUT"
sync
umount "$MOUNT/boot/efi"
EFI_MOUNTED=0
umount "$MOUNT"
ROOT_MOUNTED=0
qemu-nbd --disconnect "$NBD"
ATTACHED=0
qemu-img check "$OUT"
qemu-img info "$OUT"
sha256sum "$OUT"
SUCCESS=1
