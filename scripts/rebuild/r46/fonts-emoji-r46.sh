#!/bin/bash
# FONTS-01 (round 46): colour emoji. The image had no emoji font, so emoji in Firefox, LibreOffice and chat apps were
# empty boxes. Noto Color Emoji from the googlefonts/noto-emoji tag v2026-09-24-unicode18_0 (2D/fonts/NotoColorEmoji.ttf
# and LICENSE, SIL OFL 1.1); sha256 of both = Arch's noto-fonts-emoji 1:20260924 PKGBUILD. Prebuilt font file like
# Arch (Fedora builds it with nanoemoji). Record font-noto-emoji 2026.09.24; fc-cache -s afterwards. Run as root.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=${TARGET_ROOT:-$SB/r4-root}
S=$SB/apps01-src/fonts
T=v2026-09-24-unicode18_0
chk() { [ "$(sha256sum < "$S/$1" | cut -c1-64)" = "$2" ] || { echo "sha256 != Arch: $1"; exit 1; }; }
chk NotoColorEmoji-$T.ttf 15671215ab769fdc7162a045d56fd7d7e477c51b04e6b3c761d914d8fdd6cc44
chk noto-emoji-LICENSE-$T 500bb1ccf43df7bbb522112f9133a52b16e1c35e809632f5d8609b179152de5b
ST=$SB/r46/stage-emoji; rm -rf "$ST"
install -D -m 644 "$S/NotoColorEmoji-$T.ttf" "$ST/usr/share/fonts/noto/NotoColorEmoji.ttf"
install -D -m 644 "$S/noto-emoji-LICENSE-$T" "$ST/usr/share/licenses/font-noto-emoji/LICENSE"
chown -R root:root "$ST"
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py font-noto-emoji 2026.09.24 "$ST" font-noto-emoji 2026.09.24
chroot "$R4" /usr/bin/fc-cache -s > /dev/null
chroot "$R4" /usr/bin/fc-match emoji
chroot "$R4" /usr/bin/fc-list : family | grep -i emoji | sort -u
