#!/usr/bin/env bash
set -euo pipefail
umask 022
export LC_ALL=C LANG=C TZ=UTC SOURCE_DATE_EPOCH=1756684800
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
readonly INFRA=/srv/infra
readonly LFS=/srv/lfs
readonly TARGET_DISK=/dev/disk/by-id/virtio-ALP_LFS_V1

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
guest_guard() {
    [[ $(id -u) == 0 ]] || die 'Guest orchestrator requires root inside Builder VM.'
    [[ $(systemd-detect-virt --vm) == kvm || $(systemd-detect-virt --vm) == qemu ]] || die 'QEMU/KVM VM required.'
    [[ -b $TARGET_DISK ]] || die 'Dedicated ALP_LFS_V1 virtio disk missing.'
    [[ -f /etc/alp-infra-builder ]] || die 'Provisioned Builder identity missing.'
    [[ ! -L $INFRA && ! -L $LFS ]] || die 'Symlink root rejected.'
    # Never expose a shared host filesystem to recipes.
    if findmnt -rn -t 9p,virtiofs,nfs,nfs4,cifs | read -r _; then die 'Host/shared filesystem found.'; fi
    [[ $(findmnt -rn -o SOURCE --target "$LFS") == "$(readlink -f "$TARGET_DISK")" ]] || die 'LFS is not the dedicated guest disk.'
    [[ $(findmnt -rn -o FSTYPE --target "$LFS") == ext4 ]] || die 'LFS filesystem mismatch.'
    [[ $(cat "$LFS/.infra-volume") == alpbahOS-infra-v1 ]] || die 'LFS volume marker mismatch.'
    check_space
    exec 9>"$INFRA/writer.lock"
    flock -n 9 || die 'Another Builder writer holds the lock.'
}
check_space() {
    local root total available
    for root in / "$LFS"; do
        read -r total available < <(df -B1 --output=size,avail "$root" | tail -n1)
        (( available * 100 >= total * 15 )) || die "Free space below 15%: $root"
    done
}
