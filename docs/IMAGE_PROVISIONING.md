# Image-specific provisioning

`/mnt/lfs` on Builder is the source of truth for development and test images. Do
not copy `/etc/passwd`, `/etc/shadow`, SSH host keys, or machine identity from an
older VHDX. Provision the PAM login stack, test SSH account/key and desktop unit
configuration in the rootfs before producing an image.

`scripts/provision-m2-test-user.sh` provisions the key-only `sa` test account
from an externally supplied password hash and public key. It requires
`LFS_ROOT=/mnt/lfs`, `/etc/shadow`, PAM login/session files, and `pam_systemd`.
Secrets stay outside Git. The current Builder rootfs contains `sa`, its authorized
key, `/etc/shadow`, PAM login, and `pam_systemd`; the test image builder checks
those prerequisites before copying the rootfs.

`scripts/apply-m2-rootfs-fixes.sh` enables tty1 getty and systemd-resolved,
sets the resolved stub `/etc/resolv.conf`, and installs the `alp.py` blob from
commit `e8b0376` after checking its expected SHA-256. The Gen2 image builder
runs this script before creating the image. It also adds `admin` (UID 1001,
`users` and `wheel`, password `admin`) inside the throwaway test image only.
SSH remains restricted to key-only `sa`. Do not use this test builder for a
release image.

A distribution image (M09+) must omit test accounts and developer public keys,
start with an empty `/etc/machine-id`, and create SSH host keys on first boot.
Test that first-boot behavior separately before calling it complete.
