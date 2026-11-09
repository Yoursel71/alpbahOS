#!/bin/bash
# REBUILD-R10 one package step (Flatpak chain): newest stable GitHub release -> source tarball (API, sha256 printed)
# -> build (build-pkg-r10.sh) -> alp record (stage-record-r8.py via apply-r7.sh) -> alp check -> packages.tsv row.
# Usage: pkg-step-r10.sh <ALP_NAME> <GH_OWNER/REPO> <meson|cmake|configure> <SRCDIR|-> <ROW_NN> [build options...]
# The packages.tsv row is appended with the upstream url and the sha256. Run as root.
set -euo pipefail
export LC_ALL=C
NAME=$1; REPO=$2; KIND=$3; SRCDIR=$4; NN=$5; shift 5
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
TAG=$(curl -s --max-time 30 "https://api.github.com/repos/$REPO/releases/latest" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')
VER=${TAG#v}
DL=$SB/r10/dl; mkdir -p "$DL"
TAR=$DL/$NAME-$VER.tar.gz
URL="https://api.github.com/repos/$REPO/tarball/$TAG"
curl -sL --max-time 300 -o "$TAR" "$URL"
echo "release $REPO $TAG -> version $VER, url $URL"
bash "$WT/scripts/rebuild/r10/build-pkg-r10.sh" "$NAME" "$VER" "$TAR" "$KIND" "$SRCDIR" "$@"
SHA=$(sha256sum "$TAR" | cut -d' ' -f1)
cd "$WT"
sudo bash scripts/rebuild/r7/apply-r7.sh "$WT/scripts/rebuild/r8/stage-record-r8.py" "$NAME" "$VER" "$SB/r10/$NAME/stage" "$NAME" "$VER"
sudo python3 docs/handoffs/claude/alp-prototype/alp.py --root "$R4" --index docs/handoffs/claude/alp-prototype/demo/index.json check > /tmp/r10-$NAME.txt 2>&1 && RC=0 || RC=$?
echo "alp check rc=$RC; $(tail -1 /tmp/r10-$NAME.txt)"
echo "packages $(sudo python3 docs/handoffs/claude/alp-prototype/alp.py --root "$R4" --index docs/handoffs/claude/alp-prototype/demo/index.json list | wc -l)"
printf "%s\t%s-%s\tEXTRA\t%s-%s.tar.gz\t%s\t\thttps://github.com/%s/releases/tag/%s\tno\t\tr10-recorded\t\t\tnot in BLFS 13.1 as a package; newest stable upstream %s; sha256 %s\n" \
  "$NN" "$NAME" "$VER" "$NAME" "$VER" "$URL" "$REPO" "$TAG" "$VER" "$SHA" >> scripts/rebuild/r4/packages.tsv
echo "row $NN $NAME-$VER sha256 $SHA"
