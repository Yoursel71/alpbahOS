#!/bin/bash
# Round 40 (D163, ALP-FLATHUB-01): alp.py with the Flathub offer ('alp install <name>' looks the name up on Flathub when
# the alp catalogue has no such package; --no-flathub for the PackageKit backend). Record alp-flathub-r40 0.9-trust1.1
# takes /usr/lib/alp/alp.py over from the alp record (REPLACE=1). The signed-catalogue code is unchanged, so the ISO
# trust gate keeps passing. Run as root. Env TARGET_ROOT/LEDGER_DIR (apply-r7.sh) for another root.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
ST=$SB/r40/stage-alp-flathub
rm -rf "$ST" && install -D -m 755 "$WT/docs/handoffs/claude/alp-prototype/alp.py" "$ST/usr/lib/alp/alp.py"
grep -q 'def flathub_candidates' "$ST/usr/lib/alp/alp.py"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alp-flathub-r40 0.9-trust1.1 "$ST" \
    alp-flathub-r40 0.9-trust1.1
