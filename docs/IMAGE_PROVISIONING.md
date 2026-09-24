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
sets the resolved stub `/etc/resolv.conf`, installs the D-Bus 1.16.2 upstream
user-bus systemd units from the checksum-verified source archive, and installs
the `alp.py` blob from commit `e8b0376` after checking its expected SHA-256.
The D-Bus user units are required by the packaged PipeWire user service. The
Gen2 image builder runs this script before creating the image and checks that
both units are present. It also adds `admin` (UID 1001,
`users` and `wheel`, password `admin`) inside the throwaway test image only.
SSH remains restricted to key-only `sa`. Do not use this test builder for a
release image.

The Gen2 audio test variant also requires the rootfs-built Linux
`snd-aloop.ko` and `CONFIG_SND_ALOOP=m`; it loads that virtual PCM through
`systemd-modules-load` and adds only the test accounts `sa`/`admin` to the
`audio` group. This proves guest virtual ALSA PCM access, not physical audio
hardware. PipeWire device discovery has been observed, but its capture
roundtrip remains unverified; see
`docs/verification/m06-gen2-audio-2026-09-24.md`.

A distribution image (M09+) must omit test accounts and developer public keys,
start with an empty `/etc/machine-id`, and create SSH host keys on first boot.
Test that first-boot behavior separately before calling it complete.
