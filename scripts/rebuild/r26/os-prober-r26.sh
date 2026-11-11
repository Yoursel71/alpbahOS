#!/bin/bash
# INSTALL-DUALBOOT-01 (round 26): os-prober 1.85 as an alp package, so grub-mkconfig can list Windows (and other systems)
# next to alpbahOS. Source: Debian (deb.debian.org pool, HTTPS); the tarball sha256 matches the .dsc
# (f06094db841a214f975e79d66e2a79ea8c2b39b0f762e9d384b2feffd4ae7447); the .dsc signature key was not available.
# Not in BLFS 13.1. Install layout as debian/rules does for x86 (common + x86 probes, x86/efi -> mounted/efi).
# newns (one C file) is built in the r4-root chroot with generic x86-64 flags (D146). Run as root on the host.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
TAR=$SB/r10/dl/os-prober_1.85.tar.xz
echo "f06094db841a214f975e79d66e2a79ea8c2b39b0f762e9d384b2feffd4ae7447  $TAR" | sha256sum -c -
W=$SB/r26/os-prober; ST=$W/stage
rm -rf "$W" "$R4/tmp/os-prober-1.85"; mkdir -p "$W"
tar -xf "$TAR" -C "$R4/tmp"
chroot "$R4" /usr/bin/env PATH=/usr/bin:/usr/sbin sh -c 'cd /tmp/os-prober-1.85 && gcc -O2 -march=x86-64 -mtune=generic -Wall newns.c -o newns' > "$W/build.log" 2>&1
S=$R4/tmp/os-prober-1.85
install -D -m 755 "$S/os-prober" "$ST/usr/bin/os-prober"
# Round 29 (os-prober-locale-r29) adds "export LC_ALL=C" to os-prober and linux-boot-prober (Turkish i/I in grep -i).
install -D -m 755 "$S/linux-boot-prober" "$ST/usr/bin/linux-boot-prober"
install -D -m 755 "$S/newns" "$ST/usr/lib/os-prober/newns"
install -D -m 644 "$S/common.sh" "$ST/usr/share/os-prober/common.sh"
for probes in os-probes os-probes/mounted os-probes/init linux-boot-probes linux-boot-probes/mounted; do
    install -d -m 755 "$ST/usr/lib/$probes"
    for f in "$S/$probes/common/"*; do [ -f "$f" ] && install -m 755 "$f" "$ST/usr/lib/$probes/"; done
    if [ -d "$S/$probes/x86" ]; then
        for f in "$S/$probes/x86/"*; do
            if [ -f "$f" ]; then install -m 755 "$f" "$ST/usr/lib/$probes/"
            elif [ -d "$f" ]; then install -d -m 755 "$ST/usr/lib/$probes/$(basename "$f")"
                for g in "$f"/*; do install -m 755 "$g" "$ST/usr/lib/$probes/$(basename "$f")/"; done; fi
        done
    fi
done
install -m 755 "$S/os-probes/mounted/powerpc/20macosx" "$ST/usr/lib/os-probes/mounted/"
install -D -m 644 "$S/debian/copyright" "$ST/usr/share/licenses/os-prober/copyright"
rm -rf "$S"
"$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh" "$ST" > "$W/audit-isa.txt" 2>&1 || true
tail -1 "$W/audit-isa.txt"
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py os-prober 1.85 "$ST" os-prober 1.85
printf "%s\t%s-%s\tEXTRA\t%s\t%s\t\t%s\tno\t\tr26-recorded\t\t\t%s; sha256 %s\n" 403 os-prober 1.85 os-prober_1.85.tar.xz \
  https://deb.debian.org/debian/pool/main/o/os-prober/os-prober_1.85.tar.xz \
  https://deb.debian.org/debian/pool/main/o/os-prober/os-prober_1.85.tar.xz \
  "Debian source 1.85, sha256 matches the .dsc; not in BLFS 13.1; INSTALL-DUALBOOT-01" \
  f06094db841a214f975e79d66e2a79ea8c2b39b0f762e9d384b2feffd4ae7447 >> scripts/rebuild/r4/packages.tsv
find "$ST" -type f | sed "s|$ST||" | sort
