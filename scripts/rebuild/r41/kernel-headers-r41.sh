#!/bin/bash
# NVIDIA-PKG-01 / D165 (round 41): the kernel headers package, so out-of-tree modules (NVIDIA's open modules) can be
# built on an installed system. The image's /usr/lib/modules/7.1.8-alpbahos/build pointed to /sources/linux-7.1.8,
# which is not in the ISO. This copies the external-module build tree of that configured and built kernel (the file
# list of Arch's linux-headers package: .config, Makefile, Module.symvers, System.map, the scripts with their host
# tools, objtool, include/ and arch/x86/include, Kconfig files; no other architectures, no documentation, no loose .o
# files; vmlinux is left out: no CONFIG_DEBUG_INFO_BTF_MODULES) into /usr/src/linux-headers-7.1.8-alpbahos, and points
# the build link there (record linux-headers 7.1.8-alpbahos, taking the link over from the linux record).
# Usage: kernel-headers-r41.sh [stage|record]   stage: build the stage only; record: stage and record. Run as root.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=${TARGET_ROOT:-$SB/r4-root}
KV=7.1.8-alpbahos
SRC=$SB/r4-root/sources/linux-7.1.8
ST=$SB/r41/stage-linux-headers
D=$ST/usr/src/linux-headers-$KV
[ -s "$SRC/Module.symvers" ] && [ -s "$SRC/.config" ] || { echo "no built kernel tree at $SRC"; exit 1; }
[ "$(make -s -C "$SRC" kernelrelease 2>/dev/null)" = "$KV" ] || echo "note: kernelrelease of $SRC: $(make -s -C "$SRC" kernelrelease 2>/dev/null)"
rm -rf "$ST" && install -d "$D"
cd "$SRC"
install -Dt "$D" -m644 .config Makefile Module.symvers System.map
for f in localversion* version; do [ -e "$f" ] && install -Dt "$D" -m644 "$f"; done
install -Dt "$D/kernel" -m644 kernel/Makefile
install -Dt "$D/arch/x86" -m644 arch/x86/Makefile
[ -e arch/x86/Makefile_32.cpu ] && install -Dt "$D/arch/x86" -m644 arch/x86/Makefile_32.cpu
cp -t "$D" -a scripts
install -Dt "$D/tools/objtool" tools/objtool/objtool
cp -t "$D" -a include
cp -t "$D/arch/x86" -a arch/x86/include
install -Dt "$D/arch/x86/kernel" -m644 arch/x86/kernel/asm-offsets.s
install -Dt "$D/drivers/md" -m644 drivers/md/*.h
install -Dt "$D/net/mac80211" -m644 net/mac80211/*.h
find . -path ./Documentation -prune -o \( -name 'Kconfig*' -o -name 'Kbuild*' \) -type f -print | while read -r f; do
    install -Dm644 "$f" "$D/$f"; done
find "$D" -type f -name '*.o' -delete
find "$D" -type f \( -name '*.cmd' -o -name '.*.cmd' \) -delete
find -L "$D" -type l -delete
install -d "$ST/usr/lib/modules/$KV"
ln -s ../../../src/linux-headers-$KV "$ST/usr/lib/modules/$KV/build"
echo "stage: $(du -sh "$ST" | cut -f1), $(find "$ST" -type f | wc -l) files, ELF: $(find "$D" -type f -exec file {} + | grep -c 'ELF.*executable\|ELF.*shared object')"
"$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh" "$ST" 2>&1 | tail -1
[ "${1:-stage}" = record ] || exit 0
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py linux-headers "$KV" "$ST" linux-headers "$KV"
readlink "$R4/usr/lib/modules/$KV/build"
