#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 ]]; then
    printf 'Usage: %s /path/to/alpbahOS-live-rootfs\n' "$0" >&2
    exit 2
fi

rootfs=$(realpath -e -- "$1")
if [[ $rootfs == / || ! -f $rootfs/etc/os-release || ! -f $rootfs/etc/passwd || ! -d $rootfs/etc/polkit-1/rules.d ]]; then
    printf 'Refusing target without an alpbahOS root filesystem layout: %s\n' "$rootfs" >&2
    exit 1
fi
if ! grep -Fxq 'ID=alpbahos' "$rootfs/etc/os-release"; then
    printf 'Refusing non-alpbahOS target: %s\n' "$rootfs/etc/os-release" >&2
    exit 1
fi
if ! awk -F: '$1 == "alpbahos" && $3 == 1000 { found=1 } END { exit !found }' "$rootfs/etc/passwd"; then
    printf 'Expected the live alpbahos account (UID 1000) in %s/etc/passwd\n' "$rootfs" >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source_rule="$script_dir/../configs/polkit/10-alpbahos-live-packagekit.rules"
target_rule="$rootfs/etc/polkit-1/rules.d/10-alpbahos-live-packagekit.rules"
[[ -r $source_rule ]]
install -o root -g root -m 0644 -- "$source_rule" "$target_rule"
cmp -s -- "$source_rule" "$target_rule"
printf 'Installed live-only PackageKit authorization rule: %s\n' "$target_rule"
