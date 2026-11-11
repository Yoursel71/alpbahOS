#!/bin/bash
# REBUILD-R11 one package step with an explicit source URL (BLFS 13.1 or upstream release, as the round 11 rule says):
# download URL -> sha256 printed -> build (build-pkg-r10.sh) -> alp record (stage-record-r8.py via apply-r7.sh)
# -> alp check -> packages.tsv row (with the version source). Usage:
#   pkg-url-r11.sh <NAME> <VER> <URL> <TARBALL_NAME> <KIND: meson|cmake|configure> <SRCDIR|-> <ROW_NN> <VERSION_SOURCE> [build options...]
# Run as root. Nothing is recorded when the build fails.
set -euo pipefail
export LC_ALL=C
NAME=$1; VER=$2; URL=$3; TNAME=$4; KIND=$5; SRCDIR=$6; NN=$7; VSRC=$8; shift 8
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
DL=$SB/r10/dl; mkdir -p "$DL"
TAR=$DL/$TNAME
[ -s "$TAR" ] || curl -sL --tlsv1.2 --max-time 600 -o "$TAR" "$URL"
[ -s "$TAR" ] || { echo "download failed: $URL"; exit 1; }
echo "download $URL -> $TAR"
bash "$WT/scripts/rebuild/r10/build-pkg-r10.sh" "$NAME" "$VER" "$TAR" "$KIND" "$SRCDIR" "$@"
# Device nodes (e.g. /dev/fuse made by an install) are never recorded.
sudo find "$SB/r10/$NAME/stage" \( -type c -o -type b \) -print -delete
if [ "${KEEP_SHARED:-1}" = 1 ]; then
# Round 12: a file that another record already owns in r4-root is left out of this record (shared file, e.g. the
# libsecret locale files owned by kwallet). Otherwise the record would refuse the whole package part-way.
while read -r f; do
    if [ -e "$R4/$f" ] || [ -L "$R4/$f" ]; then
        sudo rm -f "$SB/r10/$NAME/stage/$f" && echo "shared, left out of the record: $f"
    fi
done < <(cd "$SB/r10/$NAME/stage" && find . \( -type f -o -type l \) | sed "s|^\./||")
fi
SHA=$(sha256sum "$TAR" | cut -d' ' -f1)
cd "$WT"
sudo env REPLACE="${REPLACE:-0}" bash scripts/rebuild/r7/apply-r7.sh "$WT/scripts/rebuild/r8/stage-record-r8.py" "$NAME" "$VER" "$SB/r10/$NAME/stage" "$NAME" "$VER" usr/share/info/dir
# ALP-TRUST-01: the demo index is unsigned, so the repo alp.py (same checkout, signed-catalog version) is told so
# explicitly; this runs under sudo, and --allow-unsigned is root only. check/list read only the database.
sudo python3 docs/handoffs/claude/alp-prototype/alp.py --root "$R4" --allow-unsigned --index docs/handoffs/claude/alp-prototype/demo/index.json check > /tmp/r11-$NAME.txt 2>&1 && RC=0 || RC=$?
echo "alp check rc=$RC; $(tail -1 /tmp/r11-$NAME.txt)"
echo "packages $(sudo python3 docs/handoffs/claude/alp-prototype/alp.py --root "$R4" --allow-unsigned --index docs/handoffs/claude/alp-prototype/demo/index.json list | wc -l)"
printf "%s\t%s-%s\tEXTRA\t%s\t%s\t\t%s\tno\t\tr11-recorded\t\t\t%s; sha256 %s\n" \
  "$NN" "$NAME" "$VER" "$TNAME" "$URL" "$URL" "$VSRC" "$SHA" >> scripts/rebuild/r4/packages.tsv
echo "row $NN $NAME-$VER sha256 $SHA"
