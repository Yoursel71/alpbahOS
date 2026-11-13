#!/bin/bash
# FONT-SYMBOLS-01 (round 50): Adwaita Mono 51.0 (OFL-1.1) has U+23BF and U+23F5 (checked with fc-query 2026-11-13); no other
# installed font has them. Only the monospace family is shipped; fontconfig falls back to it for the missing code points.
# The font licence text (OFL, in the tarball's LICENSE) is installed next to it.
set -e
install -d "$STAGE/usr/share/fonts/adwaita-mono" "$STAGE/usr/share/licenses/adwaita-fonts"
install -m 644 mono/AdwaitaMono-*.ttf "$STAGE/usr/share/fonts/adwaita-mono/"
install -m 644 LICENSE "$STAGE/usr/share/licenses/adwaita-fonts/LICENSE"
