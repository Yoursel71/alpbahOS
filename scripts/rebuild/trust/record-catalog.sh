#!/bin/bash
# ALP-TRUST-01: regenerate the image catalog of a root and record it as the alp record `alp-catalog` (run as root).
#
# Usage: record-catalog.sh <ROOT> <LEDGER_DIR> [SIGNING_DIR]
# Steps:
#   1. scripts/rebuild/r8/make-catalog-r8.py writes <stage>/usr/share/alp/index.json from ROOT's alp database; at its
#      end it calls resign-catalog.py, which signs the stage copy if (and only if) ROOT uses signed catalogs.
#   2. the stage (index.json, and index.json.sig when signed) is recorded as `alp-catalog <date>-v<catalog_version>`
#      (or `<date>-unsigned`) with stage-record-r8.py + r4_lib.py transfer + alp adopt-base, like apply-r7.sh. The
#      record's manifest then holds the sha256 of exactly these files, so the database and the files agree.
#   3. an unsigned root's old index.json.sig (if any) is not left behind: the record replaces the files it owns.
# The live r4-root is refused unless ALLOW_LIVE_R4=1.
set -euo pipefail
export LC_ALL=C
[ "$(id -u)" -eq 0 ] || { echo "record-catalog: run as root" >&2; exit 1; }
ROOT=$(realpath "${1:?usage: record-catalog.sh <ROOT> <LEDGER_DIR> [SIGNING_DIR]}"); LEDGER=${2:?ledger dir}
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
SIGNING=${3:-$SB/alp-signing}
WT=$(cd "$(dirname "$0")/../../.." && pwd)
ALP=$WT/docs/handoffs/ai/alp-prototype/alp.py
LIB=$WT/scripts/rebuild/r4/r4_lib.py
REC=$WT/scripts/rebuild/r8/stage-record-r8.py
die() { echo "record-catalog: $*" >&2; exit 1; }
if [ "$ROOT" = "$(realpath "$SB/r4-root")" ] && [ "${ALLOW_LIVE_R4:-0}" != 1 ]; then
    die "ROOT is the live r4-root; set ALLOW_LIVE_R4=1 only when that is intended and no other writer is active"
fi
W=$(mktemp -d /var/tmp/alp-record-catalog.XXXXXX)
trap 'rm -rf "$W"' EXIT
S=$W/stage
python3 "$WT/scripts/rebuild/r8/make-catalog-r8.py" "$ROOT" "$S" "$SIGNING"
VER=$(python3 -c 'import json,sys; v=json.load(open(sys.argv[1])).get("catalog_version"); print(f"v{v}" if v else "unsigned")' "$S/usr/share/alp/index.json")
VER=$(date -u +%Y.%m.%d)-$VER
name=alp-catalog; dir=$LEDGER/$name-$VER
[ ! -e "$dir" ] || die "$dir exists"
mkdir -p "$dir"
REPLACE=1 python3 "$REC" "$ROOT" "$ALP" "$dir" "$S" "$name" "$VER" > "$dir/record.log" 2>&1 || { cat "$dir/record.log"; die "record failed"; }
man=$dir/manifest.json
sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["package"]["source"]["sha256"])' "$man")
python3 "$LIB" transfer --root "$ROOT" --alp "$ALP" --manifest "$man" --name "$name" --version "$VER" --log "$dir/transfers.tsv"
python3 "$ALP" --root "$ROOT" adopt-base --manifest "$man" --name "$name" --version "$VER" --source-sha256 "$sha" > "$dir/adopt.log" 2>&1 \
    || { cat "$dir/adopt.log"; die "adopt-base failed"; }
# a signature left from an earlier signed record must not survive next to an unsigned catalog
if [ ! -f "$S/usr/share/alp/index.json.sig" ] && [ -e "$ROOT/usr/share/alp/index.json.sig" ]; then
    die "$ROOT/usr/share/alp/index.json.sig is left from an earlier record although the new catalog is unsigned"
fi
echo "record-catalog: recorded $name $VER ($(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["entries"]))' "$man") files)"
