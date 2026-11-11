#!/bin/bash
# REBUILD-R7 record driver (run as root): one alp record per call, same steps as scripts/rebuild/r5/apply-records.sh:
# write the files and manifest, move ownership (r4_lib.py transfer), then alp adopt-base.
# Usage: apply-r7.sh <record-script> <name> <version> [extra args...]   (R4 root, alp and ledger paths are fixed below)
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
# Opt-in (2026-11-11, updating the user's real install): TARGET_ROOT and LEDGER_DIR point the same record at another
# root and ledger; defaults unchanged.
R4=${TARGET_ROOT:-$SB/r4-root}
ALP=$WT/docs/handoffs/claude/alp-prototype/alp.py
LIB=$WT/scripts/rebuild/r4/r4_lib.py
script=$1; name=$2; ver=$3; shift 3
dir=${LEDGER_DIR:-$SB/r4-ledger/r7}/$name
mkdir -p "$dir"
python3 "$script" "$R4" "$ALP" "$dir" "$@"
man=$dir/manifest.json
sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["package"]["source"]["sha256"])' "$man")
python3 "$LIB" transfer --root "$R4" --alp "$ALP" --manifest "$man" --name "$name" --version "$ver" --log "$dir/transfers.tsv"
python3 "$ALP" --root "$R4" adopt-base --manifest "$man" --name "$name" --version "$ver" --source-sha256 "$sha" > "$dir/adopt.log" 2>&1
echo "adopted $name $ver"
