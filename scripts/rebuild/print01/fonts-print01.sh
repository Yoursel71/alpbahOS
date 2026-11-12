#!/bin/bash
# PRINT-01 / FONTS-01 (round 44): DejaVu 2.37 (wide script coverage; libcupsfilters' build needs it) and Liberation
# 2.1.5 (metric-compatible with Arial, Times New Roman and Courier New, so .docx files keep their layout in
# LibreOffice, D131). The image had only Inter, JetBrains Mono and X11 bitmap fonts. Upstream release tarballs
# (BLFS 13.1 x/TTF-and-OTF-fonts.html names them, without checksums); sha512 = Fedora's sources files. Records
# font-dejavu 2.37, font-liberation 2.1.5; fc-cache -s in r4-root afterwards (as product-d1.sh). Run as root.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=${TARGET_ROOT:-$SB/r4-root}
S=$SB/apps01-src/fonts
chk() { [ "$(sha512sum < "$S/$1" | cut -c1-128)" = "$2" ] || { echo "sha512 != Fedora: $1"; exit 1; }; }
chk dejavu-fonts-ttf-2.37.tar.bz2 bafa39321021097432777f0825d700190c23f917d754a4504722cd8946716c22c083836294dab7f3ae7cf20af63c4d0944f3423bf4aa25dbca562d1f30e00654
chk liberation-fonts-ttf-2.1.5.tar.gz b9f178fae43c9214ba6de36c6da613fcf59bd98084058afaaa9151d00f2406942bc360430be0a8f35ea6b5529146eef371c7cf75bdd7910403d449254f943fed
W=$SB/print01/fonts; rm -rf "$W" && mkdir -p "$W"
tar -xjf "$S/dejavu-fonts-ttf-2.37.tar.bz2" -C "$W"; tar -xzf "$S/liberation-fonts-ttf-2.1.5.tar.gz" -C "$W"
D=$W/stage-dejavu; L=$W/stage-liberation
install -d "$D/usr/share/fonts/dejavu" "$D/usr/share/licenses/font-dejavu" "$L/usr/share/fonts/liberation" "$L/usr/share/licenses/font-liberation"
install -m 644 "$W"/dejavu-fonts-ttf-2.37/ttf/*.ttf "$D/usr/share/fonts/dejavu/"
install -m 644 "$W"/dejavu-fonts-ttf-2.37/LICENSE "$D/usr/share/licenses/font-dejavu/"
install -m 644 "$W"/liberation-fonts-ttf-2.1.5/*.ttf "$L/usr/share/fonts/liberation/"
install -m 644 "$W"/liberation-fonts-ttf-2.1.5/LICENSE "$L/usr/share/licenses/font-liberation/"
chown -R root:root "$D" "$L"
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py font-dejavu 2.37 "$D" font-dejavu 2.37
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py font-liberation 2.1.5 "$L" font-liberation 2.1.5
chroot "$R4" /usr/bin/fc-cache -s > /dev/null
chroot "$R4" /usr/bin/fc-list : family | grep -E '^(DejaVu Sans|Liberation (Sans|Serif|Mono))$' | sort -u
chroot "$R4" /usr/bin/fc-match Arial; chroot "$R4" /usr/bin/fc-match "Times New Roman"
