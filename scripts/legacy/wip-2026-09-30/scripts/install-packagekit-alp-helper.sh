#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 ]]; then
    printf 'Usage: %s /path/to/alpbahOS-rootfs\n' "$0" >&2
    exit 2
fi

rootfs=$(realpath -e -- "$1")
if [[ $rootfs == / || ! -f $rootfs/etc/os-release || ! -d $rootfs/usr/share/PackageKit/helpers/alp ]]; then
    printf 'Refusing target without the expected alpbahOS PackageKit helper layout: %s\n' "$rootfs" >&2
    exit 1
fi
if ! grep -Fxq 'ID=alpbahos' "$rootfs/etc/os-release"; then
    printf 'Refusing non-alpbahOS target: %s\n' "$rootfs/etc/os-release" >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source_helper="$script_dir/packagekit/alpBackend.py"
target_helper="$rootfs/usr/share/PackageKit/helpers/alp/alpBackend.py"
install -o root -g root -m 0755 -- "$source_helper" "$target_helper"
cmp -s -- "$source_helper" "$target_helper"
printf 'Installed Alp PackageKit helper: %s\n' "$target_helper"
