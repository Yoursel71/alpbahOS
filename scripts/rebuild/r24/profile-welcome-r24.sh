#!/bin/bash
# Round 24: LIVE-PROFILE-01 and WELCOME-01 (D121) in r4-root. Run as root on the host.
#   1. alpbahos-desktop-profile 0.9-r24: profiles/desktop/install-desktop-profile.sh staged into a tree (look-and-feel
#      org.alpbahos.solid.desktop with the single bottom taskbar, alpbah-dark colours, alpbahOS-Brand and Atatürk
#      wallpapers, icons, /etc/xdg kdeglobals/kwinrc/mimeapps.list, skel shortcuts, alpbah-gorunum) plus
#      /etc/xdg/kded6rc (KDE Welcome Center launcher off).
#   2. alpbah-hosgeldin 0.9-r24: the Welcome app (profiles/welcome/app, Qt 6 under /opt/qt6, built in the chroot by
#      build-pkg-r10.sh, ISA audit) plus alpbah-hosgeldin-uygula, the menu entry and the XDG autostart entry.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
ST=$SB/r24/stage
# ALP-TRUST-01: through alp-host.sh (the root's own catalog keys, when it has them). A failing or empty `alp list`
# stops the run: an empty DONE would make every record below look "not done yet" and be applied again.
DONE=$(bash "$WT/scripts/rebuild/trust/alp-host.sh" "$WT/docs/handoffs/ai/alp-prototype/alp.py" --root "$R4" list) \
    || { echo "alp list failed on $R4; stopping" >&2; exit 1; }
DONE=$(cut -f1 <<< "$DONE")
[ -n "$DONE" ] || { echo "alp list on $R4 returned nothing; stopping" >&2; exit 1; }
mkdir -p "$SB/r24"
cd "$WT"
if ! grep -qx alpbahos-desktop-profile <<< "$DONE"; then
    rm -rf "$ST/profile"; mkdir -p "$ST/profile"
    bash profiles/desktop/install-desktop-profile.sh --destdir "$ST/profile" --datadir /usr/share --sysconfdir /etc \
        --bindir /usr/bin --manifest "$SB/r24/desktop-profile.manifest"
    install -m 644 profiles/welcome/data/kded6rc "$ST/profile/etc/xdg/kded6rc"
    # Files that r4-root already has with the same bytes (wallpapers, look-and-feel package and icons, recorded in
    # earlier rounds) stay with their records; a file with different bytes stops the run.
    while read -r f; do
        if [ -e "$R4/$f" ]; then
            cmp -s "$ST/profile/$f" "$R4/$f" || { echo "differs from r4-root: $f"; exit 1; }
            rm -f "$ST/profile/$f"; echo "already in r4-root (same bytes): $f"
        fi
    done < <(cd "$ST/profile" && find . -type f | sed "s|^\./||")
    chown -R root:root "$ST/profile"
    bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-desktop-profile 0.9-r24 \
        "$ST/profile" alpbahos-desktop-profile 0.9-r24
fi
if ! grep -qx alpbah-hosgeldin <<< "$DONE"; then
    T=$SB/r24/src/alpbah-hosgeldin-0.9
    rm -rf "$SB/r24/src"; mkdir -p "$T"
    cp profiles/welcome/app/CMakeLists.txt profiles/welcome/app/main.cpp profiles/welcome/app/*.qml "$T/"
    cp branding/plymouth-theme/alpbahos/mark.png "$T/mark.png"
    tar -C "$SB/r24/src" --sort=name --owner=0 --group=0 --mtime=2026-11-10 -czf "$SB/r24/alpbah-hosgeldin-0.9.tar.gz" alpbah-hosgeldin-0.9
    bash scripts/rebuild/r10/build-pkg-r10.sh alpbah-hosgeldin 0.9 "$SB/r24/alpbah-hosgeldin-0.9.tar.gz" cmake - \
        -DCMAKE_PREFIX_PATH=/opt/qt6
    S=$SB/r10/alpbah-hosgeldin/stage
    install -D -m 755 profiles/welcome/bin/alpbah-hosgeldin-uygula "$S/usr/bin/alpbah-hosgeldin-uygula"
    install -D -m 644 profiles/welcome/data/alpbah-hosgeldin.desktop "$S/usr/share/applications/alpbah-hosgeldin.desktop"
    install -D -m 644 profiles/welcome/data/alpbah-hosgeldin-autostart.desktop "$S/etc/xdg/autostart/alpbah-hosgeldin.desktop"
    chown -R root:root "$S"
    bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbah-hosgeldin 0.9-r24 "$S" \
        alpbah-hosgeldin 0.9-r24
fi
ls -l "$R4/usr/bin/alpbah-hosgeldin" "$R4/usr/bin/alpbah-hosgeldin-uygula" "$R4/usr/bin/alpbah-gorunum"
ls "$R4/usr/share/wallpapers" | grep alpbahOS
cat "$SB/r10/alpbah-hosgeldin/audit-isa.txt" | tail -3
