#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A build or package-test process is active.'
fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
    '[[ "$(pkg-config --modversion nss)" == 3.115.0 && -f /usr/lib/pkcs11/p11-kit-trust.so && -f /usr/lib/libnssckbi.so ]]' \
    || fail 'NSS or the p11-kit trust module is missing.'
lfs_acquire_writer_lock "$DATA"
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -s <<'NSS_TRUST'
set -Eeuo pipefail
ln -sfn ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
[[ "$(readlink /usr/lib/libnssckbi.so)" == './pkcs11/p11-kit-trust.so' ]]
[[ -f /usr/lib/libnssckbi.so ]]
printf 'NSS_P11_KIT_TRUST_INTEGRATION=PASS\n'
NSS_TRUST
