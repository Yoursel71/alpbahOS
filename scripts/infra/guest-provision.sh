#!/usr/bin/env bash
set -euo pipefail
umask 022
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
[[ $(id -u) == 0 && $(systemd-detect-virt --vm) == kvm ]] || { echo 'KVM guest required'; exit 1; }
readonly disk=/dev/disk/by-id/virtio-ALP_LFS_V1
[[ -b $disk ]] || { echo 'Dedicated virtio disk missing'; exit 1; }
apt-get update
apt-get install -y --no-install-recommends build-essential bison gawk texinfo \
    python3 rsync xz-utils file patch wget ca-certificates openssh-server \
    bzip2 gzip cpio bc ninja-build pkg-config meson cmake git \
    dejagnu expect libssl-dev zstd unzip
# This modifies the disposable Debian builder, never the Fedora host or product.
ln -sf bash /bin/sh
update-alternatives --set awk /usr/bin/gawk
[[ -e /usr/bin/yacc ]] || ln -s bison /usr/bin/yacc
id lfs >/dev/null 2>&1 || useradd -m -s /bin/bash -u 1001 lfs
# LFS runs several package test suites as an unprivileged tester account.
id tester >/dev/null 2>&1 || useradd -m -s /bin/bash tester
mkdir -p /srv/infra /srv/lfs
if ! blkid "$disk" >/dev/null 2>&1; then mkfs.ext4 -L alp-lfs "$disk"; fi
[[ $(blkid -s TYPE -o value "$disk") == ext4 ]] || { echo 'Unexpected disk filesystem'; exit 1; }
mountpoint -q /srv/lfs || mount "$disk" /srv/lfs
if [[ -e /srv/lfs/.infra-volume ]]; then
    [[ $(cat /srv/lfs/.infra-volume) == alpbahOS-infra-v1 ]] || exit 1
else
    printf 'alpbahOS-infra-v1\n' > /srv/lfs/.infra-volume
fi
uuid=$(blkid -s UUID -o value "$disk")
grep -q ' /srv/lfs ' /etc/fstab || printf 'UUID=%s /srv/lfs ext4 defaults 0 2\n' "$uuid" >> /etc/fstab
printf 'alpbahOS-infra-builder-v1\n' > /etc/alp-infra-builder
mkdir -p /srv/lfs/{sources,build,stage,results,smoke-root}
chown lfs:lfs /srv/lfs/{sources,build,stage}
dpkg-query -W -f='${binary:Package}\t${Version}\n' > /srv/infra/builder-packages.tsv
sha256sum /srv/infra/builder-packages.tsv
