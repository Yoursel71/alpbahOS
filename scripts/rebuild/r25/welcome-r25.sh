#!/bin/bash
# Round 25 (WELCOME-01 fix): the round 24 build could not load its QML ("Module AlpbahHosgeldin contains no type named
# Main": NO_RESOURCE_TARGET_PATH put the module outside qrc:/qt/qml). Rebuilds the app from profiles/welcome/app and
# records alpbah-hosgeldin-r25 0.9-r25, which takes over /usr/bin/alpbah-hosgeldin, alpbah-hosgeldin-uygula (short
# Glass reason) and the two desktop entries from alpbah-hosgeldin 0.9-r24 (REPLACE=1). Run as root on the host.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
if [ "${STEP2:-0}" != 1 ]; then
T=$SB/r25/src/alpbah-hosgeldin-0.9.1
rm -rf "$SB/r25/src"; mkdir -p "$T"
cp profiles/welcome/app/CMakeLists.txt profiles/welcome/app/main.cpp profiles/welcome/app/*.qml "$T/"
cp branding/plymouth-theme/alpbahos/mark.png "$T/mark.png"
tar -C "$SB/r25/src" --sort=name --owner=0 --group=0 --mtime=2026-11-11 -czf "$SB/r25/alpbah-hosgeldin-0.9.1.tar.gz" alpbah-hosgeldin-0.9.1
bash scripts/rebuild/r10/build-pkg-r10.sh alpbah-hosgeldin-r25 0.9.1 "$SB/r25/alpbah-hosgeldin-0.9.1.tar.gz" cmake - \
    -DCMAKE_PREFIX_PATH=/opt/qt6
S=$SB/r10/alpbah-hosgeldin-r25/stage
install -D -m 755 profiles/welcome/bin/alpbah-hosgeldin-uygula "$S/usr/bin/alpbah-hosgeldin-uygula"
install -D -m 644 profiles/welcome/data/alpbah-hosgeldin.desktop "$S/usr/share/applications/alpbah-hosgeldin.desktop"
install -D -m 644 profiles/welcome/data/alpbah-hosgeldin-autostart.desktop "$S/etc/xdg/autostart/alpbah-hosgeldin.desktop"
chown -R root:root "$S"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbah-hosgeldin-r25 0.9-r25 "$S" \
    alpbah-hosgeldin-r25 0.9-r25
tail -1 "$SB/r10/alpbah-hosgeldin-r25/audit-isa.txt"
fi
# Second step (same round): alpbah-hosgeldin-uygula shows "durum okunamadı" when alpbah-gorunum itself fails (seen in
# the chroot check without a session); record alpbahos-welcome-tool-r25b takes the script over.
if [ "${STEP2:-0}" = 1 ]; then
    S2=$SB/r25/stage-tool; rm -rf "$S2"
    install -D -m 755 profiles/welcome/bin/alpbah-hosgeldin-uygula "$S2/usr/bin/alpbah-hosgeldin-uygula"
    REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-welcome-tool-r25b 0.9-r25b \
        "$S2" alpbahos-welcome-tool-r25b 0.9-r25b
fi
