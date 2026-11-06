#!/bin/sh
# Check that the live ISO root has the tools listed in packages-required.txt.
# Usage: check-live-tools.sh <rootfs-dir>   (default: /mnt/lfs)
# Exit 1 if any required binary is missing. Read-only; does not install anything.
# Status 2026-11-06: rsync, unsquashfs and mksquashfs are MISSING from /mnt/lfs, so this check fails today.
set -eu
ROOT=${1:-/mnt/lfs}
R=$(dirname "$(readlink -f "$0")")
missing=0
while read -r bin pkg _; do
    case "$bin" in ''|\#*) continue ;; esac
    if [ -x "$ROOT$bin" ]; then
        echo "ok      $bin ($pkg)"
    else
        echo "MISSING $bin (package $pkg) in $ROOT" >&2
        missing=1
    fi
done < "$R/packages-required.txt"
[ "$missing" = 0 ] || { echo "DURDU: canlı ISO kökünde eksik araçlar var (paket listesi: $R/packages-required.txt)" >&2; exit 1; }
echo "tüm gerekli araçlar mevcut: $ROOT"
