#!/bin/bash
# Round 39 (user's ASCII drawing of the logo, 2026-11-11): fastfetch shows it instead of the half-block picture.
# Record alpbahos-fastfetch-ascii-r39 takes over /usr/share/fastfetch/alpbahos-logo.txt (from fastfetch-logo-r9) and
# /etc/fastfetch/config.jsonc (from alpbahos-name; only "logo.color" is added: the $1..$4 colours of
# branding/alpbahos-brand/tools/build_ascii_logo.py). Run as root on the host.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ST=$SB/r39/stage-fastfetch
cd "$WT"
python3 -B branding/alpbahos-brand/tools/build_ascii_logo.py --check
rm -rf "$ST" && install -d "$ST/usr/share/fastfetch" "$ST/etc/fastfetch"
install -m 644 branding/alpbahos-brand/terminal/alpbahos-logo.fastfetch.txt "$ST/usr/share/fastfetch/alpbahos-logo.txt"
python3 - "$R4/etc/fastfetch/config.jsonc" "$ST/etc/fastfetch/config.jsonc" <<'PY'
import json, sys
sys.path.insert(0, "branding/alpbahos-brand/tools")
from build_ascii_logo import COLOURS
cfg = json.load(open(sys.argv[1]))
cfg["logo"]["color"] = COLOURS
open(sys.argv[2], "w").write(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
PY
chmod 644 "$ST/etc/fastfetch/config.jsonc"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-fastfetch-ascii-r39 0.9-r39 \
    "$ST" alpbahos-fastfetch-ascii-r39 0.9-r39
chown -R yrslf: "$SB/r39"
