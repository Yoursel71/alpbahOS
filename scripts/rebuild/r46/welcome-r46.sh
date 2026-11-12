#!/bin/bash
# Round 46 (WELCOME-02, D135): the Welcome app with the design the user picked (design 4, "Başlangıç merkezi", now
# Main.qml; the other four designs are gone) on Qt Quick's software renderer. Record alpbah-hosgeldin-r46 takes
# /usr/bin/alpbah-hosgeldin over from alpbah-hosgeldin-r45 (REPLACE=1). Built in the r4-root chroot (Qt 6 under
# /opt/qt6). Run as root on the host.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
T=$SB/r46/src/alpbah-hosgeldin-0.9.2
rm -rf "$SB/r46/src"; mkdir -p "$T"
cp profiles/welcome/app/CMakeLists.txt profiles/welcome/app/main.cpp profiles/welcome/app/*.qml "$T/"
cp branding/plymouth-theme/alpbahos/mark.png "$T/mark.png"
tar -C "$SB/r46/src" --sort=name --owner=0 --group=0 --mtime=2026-11-12 -czf "$SB/r46/alpbah-hosgeldin-0.9.2.tar.gz" alpbah-hosgeldin-0.9.2
NICE=10 bash scripts/rebuild/r10/build-pkg-r10.sh alpbah-hosgeldin-r46 0.9.2 "$SB/r46/alpbah-hosgeldin-0.9.2.tar.gz" cmake - \
    -DCMAKE_PREFIX_PATH=/opt/qt6
S=$SB/r10/alpbah-hosgeldin-r46/stage
[ -x "$S/usr/bin/alpbah-hosgeldin" ] || { echo "binary missing"; exit 1; }
find "$S" -type f ! -path "*/usr/bin/alpbah-hosgeldin" -delete
chown -R root:root "$S"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbah-hosgeldin-r46 0.9-r46 "$S" \
    alpbah-hosgeldin-r46 0.9-r46
tail -1 "$SB/r10/alpbah-hosgeldin-r46/audit-isa.txt"
chown -R yrslf: "$SB/r46"
