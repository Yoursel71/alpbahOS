#!/bin/bash
# WELCOME-02 (round 44; since 2026-11-12 only the chosen design 4, Main.qml, D177): the Hoş Geldin window. Builds the app in a WRITABLE btrfs snapshot of r4-root
# (welcome02/root; r4-root itself is not touched), runs the qmltestrunner tests (tests/welcome) offscreen with a fake
# backend, and saves screenshots of each design with a fake alpbah-hosgeldin-uygula (no settings are changed).
# Output: scratch-lfs-bench/welcome02/{build.log,test.log,shots/}. Run as root on the host. Env KEEP=1 keeps the snapshot.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
W=$SB/welcome02
R=$W/root
mkdir -p "$W"
[ -e "$R" ] || btrfs subvolume snapshot "$SB/r4-root" "$R" > /dev/null
cleanup() {
    for m in "$R/dev/pts" "$R/dev" "$R/proc" "$R/sys" "$R/run"; do mountpoint -q "$m" && umount -l "$m"; done
    if [ "${KEEP:-0}" != 1 ]; then btrfs subvolume delete "$R" > /dev/null; fi
}
trap cleanup EXIT
trap 'echo "failed at line $LINENO"' ERR
mount --bind /dev "$R/dev"; mount -t devpts devpts "$R/dev/pts" -o gid=5,mode=620 2>/dev/null || true
mount -t proc proc "$R/proc"; mount -t sysfs sysfs "$R/sys"; mount -t tmpfs tmpfs "$R/run"

# Source tree and QML module directory for the tests
rm -rf "$R/tmp/hg-src" "$R/tmp/hg-build" "$R/tmp/hg-mod" "$R/tmp/hg-shots" "$R/tmp/hg-sahte" "$R/tmp/hg-home"
mkdir -p "$R/tmp/hg-src" "$R/tmp/hg-mod/AlpbahHosgeldin" "$R/tmp/hg-shots" "$R/tmp/hg-sahte" "$R/tmp/hg-home/xdg"
chmod 700 "$R/tmp/hg-home/xdg"
cp "$WT"/profiles/welcome/app/{CMakeLists.txt,main.cpp} "$WT"/profiles/welcome/app/*.qml "$R/tmp/hg-src/"
cp "$WT/branding/plymouth-theme/alpbahos/mark.png" "$R/tmp/hg-src/mark.png"
cp "$WT"/profiles/welcome/app/*.qml "$R/tmp/hg-src/mark.png" "$R/tmp/hg-mod/AlpbahHosgeldin/"
{ echo "module AlpbahHosgeldin"; for f in "$WT"/profiles/welcome/app/*.qml; do b=$(basename "$f" .qml); echo "$b 1.0 $b.qml"; done; } \
    > "$R/tmp/hg-mod/AlpbahHosgeldin/qmldir"
cp "$WT/tests/welcome/tst_hosgeldin_tasarim.qml" "$R/tmp/hg-mod/"

# Fake apply tool: durum from SAHTE_* variables, everything else only logged.
cat > "$R/tmp/hg-sahte/alpbah-hosgeldin-uygula" << 'X'
#!/bin/sh
echo "$*" >> /tmp/hg-sahte/log
case "$1" in
durum)
  if [ "${SAHTE_GLASS:-1}" = 1 ]; then g=true; n=""; else g=false; n="ekran kartı hızlandırması yok"; fi
  printf '{"glass_kullanilabilir": %s, "glass_neden": "%s", "tema": "%s", "gorunum": "%s", "cubuk": "%s", "onizleme": {"alpbahos": "/usr/share/wallpapers/alpbahOS-Brand/contents/screenshot.png", "ataturk": "/usr/share/wallpapers/alpbahOS-Ataturk/contents/screenshot.png"}}\n' \
    "$g" "$n" "${SAHTE_TEMA:-alpbahos}" "${SAHTE_GORUNUM:-solid}" "${SAHTE_CUBUK:-sol}" ;;
esac
exit 0
X
chmod 755 "$R/tmp/hg-sahte/alpbah-hosgeldin-uygula"

E=(env -i PATH=/tmp/hg-sahte:/opt/qt6/bin:/usr/bin:/bin HOME=/tmp/hg-home XDG_RUNTIME_DIR=/tmp/hg-home/xdg
   LANG=tr_TR.UTF-8 QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR=1)
echo "== build $(date +%T)"
chroot "$R" "${E[@]}" sh -c 'cmake -S /tmp/hg-src -B /tmp/hg-build -DCMAKE_PREFIX_PATH=/opt/qt6 -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-O2 -march=x86-64 -mtune=generic" && cmake --build /tmp/hg-build --parallel 8' > "$W/build.log" 2>&1 \
    || { tail -30 "$W/build.log"; exit 1; }
echo "build ok"
echo "== tests $(date +%T)"
set +e
chroot "$R" "${E[@]}" sh -c 'cd /tmp/hg-mod && qmltestrunner -import /tmp/hg-mod -input /tmp/hg-mod/tst_hosgeldin_tasarim.qml' > "$W/test.log" 2>&1
TRC=$?
set -e
grep -E "^Totals|^FAIL|^QWARN|Error" "$W/test.log" | head -40
echo "test rc=$TRC"

echo "== screenshots $(date +%T)"
shot() {  # NAME TASARIM [env/ozellik ...]
    local n=$1 t=$2; shift 2
    local envs=() oz=()
    for a in "$@"; do case "$a" in SAHTE_*=*) envs+=("$a") ;; *) oz+=(--ozellik "$a") ;; esac; done
    chroot "$R" "${E[@]}" "${envs[@]}" /tmp/hg-build/alpbah-hosgeldin "${oz[@]}" \
        --ekran-goruntusu "/tmp/hg-shots/$n.png" > "$W/shot-$n.log" 2>&1 && echo "shot $n" || echo "shot $n FAILED rc=$?"
}
shot 1-alpbahos Main ad=Bahadır
shot 2-ataturk Main ad=Bahadır SAHTE_TEMA=ataturk
shot 3-glass-yok Main ad=Bahadır SAHTE_GLASS=0
rm -rf "$W/shots"; cp -r "$R/tmp/hg-shots" "$W/shots"
cp "$R/tmp/hg-sahte/log" "$W/sahte.log" 2>/dev/null || true
chown -R yrslf: "$W/shots" "$W"/*.log
echo "done $(date +%T) test rc=$TRC"
exit $TRC
