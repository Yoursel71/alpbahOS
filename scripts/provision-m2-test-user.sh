#!/bin/sh
set -eu

# Provision the image-specific sa account in the authoritative LFS rootfs.
# Run as root on the Ubuntu Builder only after installing the PAM-enabled
# Shadow login binary and a login/system-session stack that invokes pam_systemd.
# This script never copies account files or password hashes from an old VHDX.

ROOTFS=${LFS_ROOT:-/mnt/lfs}
PASSWORD_HASH=${SA_PASSWORD_HASH:?Set SA_PASSWORD_HASH to a per-image crypt hash}
PUBLIC_KEY_FILE=${SA_AUTHORIZED_KEYS:?Set SA_AUTHORIZED_KEYS to a public-key file}
SA_UID=${SA_UID:-1000}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
KWIN_DROPIN="$SCRIPT_DIR/../configs/systemd/user/plasma-kwin_wayland.service.d/10-wayland-only.conf"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root on the Ubuntu Builder." >&2
    exit 1
fi
if [ ! -d "$ROOTFS" ] || [ -L "$ROOTFS" ] || [ "$(realpath "$ROOTFS")" != /mnt/lfs ]; then
    echo "Refusing unexpected LFS_ROOT; expected the mounted Builder rootfs at /mnt/lfs." >&2
    exit 1
fi
if [ ! -r "$PUBLIC_KEY_FILE" ] || ! grep -Eq '^(ssh-|ecdsa-|sk-)' "$PUBLIC_KEY_FILE"; then
    echo "SA_AUTHORIZED_KEYS must name a readable OpenSSH public-key file." >&2
    exit 1
fi
for required in etc/passwd etc/group etc/shadow etc/pam.d/login etc/pam.d/system-session usr/bin/bash usr/sbin/useradd usr/sbin/usermod usr/sbin/chpasswd; do
    if [ ! -e "$ROOTFS/$required" ]; then
        echo "Missing rootfs prerequisite: /$required" >&2
        exit 1
    fi
done
if [ ! -r "$KWIN_DROPIN" ]; then
    echo "Missing tracked KWin systemd drop-in: $KWIN_DROPIN" >&2
    exit 1
fi
if ! grep -q 'pam_systemd\.so' "$ROOTFS/etc/pam.d/system-session" || ! grep -q 'system-session' "$ROOTFS/etc/pam.d/login"; then
    echo "PAM login/session stack must invoke pam_systemd before provisioning." >&2
    exit 1
fi
if ! awk -F: '$1 == "wheel" { found=1 } END { exit !found }' "$ROOTFS/etc/group"; then
    echo "Expected wheel group is missing from the LFS rootfs." >&2
    exit 1
fi

existing_uid=$(awk -F: '$1 == "sa" { print $3 }' "$ROOTFS/etc/passwd")
if [ -n "$existing_uid" ]; then
    if [ "$existing_uid" != "$SA_UID" ]; then
        echo "Existing sa UID ($existing_uid) does not match requested UID ($SA_UID)." >&2
        exit 1
    fi
    chroot "$ROOTFS" /usr/sbin/usermod -aG wheel sa
else
    if awk -F: -v uid="$SA_UID" '$3 == uid { found=1 } END { exit !found }' "$ROOTFS/etc/passwd"; then
        echo "Requested sa UID $SA_UID is already assigned in the rootfs." >&2
        exit 1
    fi
    if ! awk -F: '$1 == "users" { found=1 } END { exit !found }' "$ROOTFS/etc/group"; then
        echo "Expected users group is missing from the LFS rootfs." >&2
        exit 1
    fi
    chroot "$ROOTFS" /usr/sbin/useradd -m -u "$SA_UID" -g users -G wheel -s /bin/bash sa
fi

printf 'sa:%s\n' "$PASSWORD_HASH" | chroot "$ROOTFS" /usr/sbin/chpasswd -e
sa_gid=$(awk -F: '$1 == "sa" { print $4 }' "$ROOTFS/etc/passwd")
install -d -o "$SA_UID" -g "$sa_gid" -m 0700 "$ROOTFS/home/sa/.ssh"
install -o "$SA_UID" -g "$sa_gid" -m 0600 "$PUBLIC_KEY_FILE" "$ROOTFS/home/sa/.ssh/authorized_keys"
install -d -m 0755 "$ROOTFS/etc/systemd/user/plasma-kwin_wayland.service.d"
install -m 0644 "$KWIN_DROPIN" "$ROOTFS/etc/systemd/user/plasma-kwin_wayland.service.d/10-wayland-only.conf"
echo "Provisioned sa (UID $SA_UID) in /mnt/lfs with wheel access and the supplied public key."
