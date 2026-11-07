#!/bin/bash
# CONTEXT: chroot
# REBUILD-R2 chapter 10: read-only check of the GRUB module directories built in chapter 8 (64-grub.sh).
# Reports only. grub-install is not run in this phase.
set -euo pipefail

for plat in i386-pc x86_64-efi i386-efi; do
    d=/usr/lib/grub/$plat
    if [ -d "$d" ]; then
        echo "$d: $(ls "$d"/*.mod 2>/dev/null | wc -l) modules, $(ls "$d"/*.img 2>/dev/null | wc -l) images"
    else
        echo "$d: MISSING"
        exit 1
    fi
done
test -x /usr/sbin/grub-install
echo "OK 07-grub-modules"
