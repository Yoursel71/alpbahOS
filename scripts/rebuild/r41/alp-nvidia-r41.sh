#!/bin/bash
# NVIDIA-PKG-01 / D165 (round 41): alp with recipe "unpack": false, @KERNEL_RELEASE@/@KERNEL_BUILD@, TMPDIR in the
# build tree and the ldconfig/depmod triggers, plus /usr/lib/alp/helpers/nvidia-stage.py (record alp-r41b
# 0.9-trust1.6, takes alp.py over from alp-r41); then the catalogue is regenerated and re-signed with the nvidia offer
# (profiles/alp-catalog: recipes/nvidia.recipe.json pinned by recipe_sha256). Run as root; r4-root's only writer.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=${TARGET_ROOT:-$SB/r4-root}
ST=$SB/r41/stage-alp-nvidia
rm -rf "$ST"
install -D -m 755 "$WT/docs/handoffs/ai/alp-prototype/alp.py" "$ST/usr/lib/alp/alp.py"
install -D -m 755 "$WT/docs/handoffs/ai/alp-prototype/helpers/nvidia-stage.py" "$ST/usr/lib/alp/helpers/nvidia-stage.py"
grep -q '_unpack_source' "$ST/usr/lib/alp/alp.py"
[ "${ALP_REC:-}" != alp-r42 ] || grep -q '_kutu_env' "$ST/usr/lib/alp/alp.py"
cd "$WT"
REC=${ALP_REC:-alp-r41b} VER=${ALP_VER:-0.9-trust1.6}   # round 42: ALP_REC=alp-r42 ALP_VER=0.9-trust1.7 (KUTU-LOCALE-01)
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py "$REC" "$VER" "$ST" "$REC" "$VER"
ALLOW_LIVE_R4=1 bash scripts/rebuild/trust/record-catalog.sh "$R4" "$SB/r4-ledger/r41"
python3 -c 'import json,sys; e=json.load(open(sys.argv[1]))["entries"]["nvidia"]; print("catalogue offer:", e["version"], e["recipe"], e["recipe_sha256"][:16], e["triggers"])' "$R4/usr/share/alp/index.json"
bash scripts/rebuild/trust/iso-gate.sh --auto "$R4" | tail -1
