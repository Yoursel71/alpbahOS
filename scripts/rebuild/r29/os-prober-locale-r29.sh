#!/bin/bash
# INSTALL-DUALBOOT-01 (round 29): os-prober found no Windows on a Turkish system. Its probes match names with
# "grep -i" (item_in_dir in common.sh: "^efi$" against "EFI"); in tr_TR the case-insensitive match of "i"/"I" fails
# (dotted/dotless i), so 05efi exited with "/boot/efi does not have /EFI directory" (round 28, DB2 journal).
# Fix: /usr/bin/os-prober and /usr/bin/linux-boot-prober export LC_ALL=C before anything else; every probe they run
# inherits it (Calamares and grub-mkconfig call these two). Record os-prober-locale-r29 takes both files over from
# os-prober 1.85 (REPLACE=1). Run as root on the host.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ST=$SB/r29/stage-osprober
rm -rf "$ST"; mkdir -p "$ST/usr/bin" "$SB/r29"
for f in os-prober linux-boot-prober; do
    src=$R4/usr/bin/$f
    head -n 1 "$src" | grep -q '^#!/bin/sh' || { echo "$f: unexpected first line"; exit 1; }
    grep -q '^export LC_ALL=C' "$src" && { echo "$f: already patched"; exit 1; }
    { head -n 1 "$src"
      echo '# alpbahOS (round 29): the probes match file names with "grep -i"; in tr_TR "i" and "I" are not the same letter.'
      echo 'export LC_ALL=C'
      tail -n +2 "$src"; } > "$ST/usr/bin/$f"
    chmod 755 "$ST/usr/bin/$f"; sh -n "$ST/usr/bin/$f"
done
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py os-prober-locale-r29 1.85-alp1 "$ST" \
    os-prober-locale-r29 1.85-alp1
head -3 "$R4/usr/bin/os-prober"
