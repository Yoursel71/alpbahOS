#!/bin/bash
# REBUILD-R5 record driver (run as root): writes the R5 config records into r4-root and records them with alp.
# Records (in this order):
#   session-r5fix    user-session stop order (drop-ins), ksplash stop status, login PAM, live-medium helper
#   autologin-r5fix  /etc/pam.d/sddm-autologin (taken from session-r5fix; the alpha ISO stack)
#   branding-r5fix   /etc/os-release, /etc/lsb-release
# Each record: files written, ownership moved from the earlier record (r4_lib.py transfer), then alp adopt-base.
# Usage on a FRESH r4-root (the driver stops at the first refused adopt-base). The records of 2026-11-09 are on
# r4-root already; there only autologin-r5fix was added by hand with the same commands.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ALP=$WT/docs/handoffs/claude/alp-prototype/alp.py
LIB=$WT/scripts/rebuild/r4/r4_lib.py
HERE=$WT/scripts/rebuild/r5
LEDGER=$SB/r4-ledger/r5

apply_one() {
    local script=$1 name=$2 ver=$3 dir=$LEDGER/$2
    mkdir -p "$dir"
    python3 "$script" "$R4" "$ALP" "$dir"
    local man=$dir/manifest.json
    local sha
    sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["package"]["source"]["sha256"])' "$man")
    python3 "$LIB" transfer --root "$R4" --alp "$ALP" --manifest "$man" --name "$name" --version "$ver" \
        --log "$dir/transfers.tsv"
    python3 "$ALP" --root "$R4" adopt-base --manifest "$man" --name "$name" --version "$ver" \
        --source-sha256 "$sha" > "$dir/adopt.log" 2>&1
    echo "adopted $name $ver"
}

apply_one "$HERE/session-r5fix.py" session-r5fix 13.1-r5fix
apply_one "$HERE/autologin-r5fix.py" autologin-r5fix 13.1-r5fix
apply_one "$HERE/brand-r5fix.py" branding-r5fix 0.9-r5fix
