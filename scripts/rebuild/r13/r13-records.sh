#!/bin/bash
# REBUILD-R13 records (run as yrslf; sudo inside). Each step is one alp record through apply-r7.sh and stage-record-r8.py.
#   1 alp: the repo alp.py (default catalog /usr/share/alp/index.json, commit 711d699) replaces the r4 copy (item 2).
#   2 fuse3: fusermount3 mode 4755 (setuid root), the other 15 files unchanged (item 4). Package key kept as in alp.
#   3 sddm: the logo stays visible on the login frame (item 6).
#   4 keyboard: KDE layout defaults for the installed system (item 5): /etc/xdg/kxkbrc, layout tr (Turkish-Q).
set -u
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
R4=$SB/r4-root
W=$SB/r13
L=$W/logs
mkdir -p "$L"
cd "$WT" || exit 1
rec() {
  local name=$1 ver=$2 stage=$3 rep=$4
  if sudo env REPLACE="$rep" KEEP_SHARED=0 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py "$name" "$ver" "$stage" "$name" "$ver" usr/share/info/dir > "$L/rec-$name.log" 2>&1; then
    echo "OK $name $ver"
  else
    echo "FAIL $name $ver rc=$? (log $L/rec-$name.log)"
  fi
}
# 1 alp
S=$W/stage-alp; rm -rf "$S"; mkdir -p "$S/usr/lib/alp" "$S/usr/bin"
install -m 755 "$WT/docs/handoffs/claude/alp-prototype/alp.py" "$S/usr/lib/alp/alp.py"
cp -a "$R4/usr/bin/alp" "$S/usr/bin/alp"
rec alp 0.9-r13 "$S" 1
# 2 fuse3 (package key of the r7 record)
S=$W/stage-fuse; rm -rf "$S"; mkdir -p "$S"
python3 - "$R4" "$S" << 'PY'
import json, os, shutil, sys
R4, S = sys.argv[1], sys.argv[2]
files = json.load(open(os.path.join(R4, "var/lib/alp/db.json")))["packages"]["fuse3-3.18.2-leftover"]["files"]
for rel in files:
    src = os.path.join(R4, rel); dst = os.path.join(S, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.islink(src):
        os.symlink(os.readlink(src), dst)
    else:
        shutil.copy2(src, dst)
print(len(files), "files staged")
PY
sudo chmod 4755 "$S/usr/bin/fusermount3"
stat -c '%a %n' "$S/usr/bin/fusermount3"
rec fuse3-3.18.2-leftover 3.18.2-r13 "$S" 1
# 3 sddm logo
S=$W/stage-sddm; rm -rf "$S"; mkdir -p "$S"
python3 "$WT/scripts/rebuild/r13/sddm-logo-r13.py" "$R4" "$S"
rec sddm-alpbahos-r13 0.9-r13 "$S" 1
# 4 keyboard defaults
S=$W/stage-kbd; rm -rf "$S"; mkdir -p "$S/etc/xdg"
cat > "$S/etc/xdg/kxkbrc" << 'KXK'
[Layout]
DisplayNames=
LayoutList=tr
LayoutLoopCount=-1
Model=pc105
Options=
ResetOldOptions=true
SwitchMode=Global
Use=true
VariantList=
KXK
rec alpbahos-keyboard 0.9-r13 "$S" 0
# checks with the installed alp copy (item 2): check and list without --index
sudo chroot "$R4" /usr/bin/alp check > "$L/alp-check-installed.txt" 2>&1; echo "alp check (installed copy) rc=$?"
sudo chroot "$R4" /usr/bin/alp list > "$L/alp-list-noindex.txt" 2>&1; echo "alp list (no --index) rc=$?"
sudo chroot "$R4" /usr/bin/alp search fastfetch > "$L/alp-search-noindex.txt" 2>&1; echo "alp search (no --index) rc=$?"
echo DONE
