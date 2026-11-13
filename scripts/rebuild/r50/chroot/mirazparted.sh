#!/bin/bash
# MIRAZPARTED-01 (round 50), in the chroot of r4-root: KDE Partition Manager 26.08.3 (same KDE Gear as the installed
# kpmcore 26.08.3, which Calamares uses: no kpmcore upgrade) shown to the user as "MirazParted". Only the visible names
# change; the binary, translation domain, rc file, polkit action and D-Bus ids of kpmcore stay (renaming them would
# break the root helper). GPL-3.0-or-later: the about dialog keeps the KDE authors and says it is derived from KDE
# Partition Manager. BLFS 13.1 has no page for it; the build follows the kde/ark.html pattern.
set -e
# 1. visible name in the about dialog
sed -i 's|<application>KDE Partition Manager</application>|<application>MirazParted</application>|' src/main.cpp
grep -q '<application>MirazParted</application>' src/main.cpp
# add a "derived from" line to the about dialog text (kept after the existing description, translated strings untouched)
sed -i '0,/aboutData.setProductName/s||aboutData.setOtherText(QStringLiteral("MirazParted is alpbahOS'"'"'s name for KDE Partition Manager; derived from KDE Partition Manager, GPL-3.0-or-later."));\n    aboutData.setProductName|' src/main.cpp
grep -q 'setOtherText' src/main.cpp
mkdir build && cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_PREFIX_PATH=/opt/qt6 -D CMAKE_BUILD_TYPE=Release -D BUILD_TESTING=OFF \
      -W no-author ..
make
make DESTDIR="$STAGE" install
# 2. names the menu shows: own desktop entry, own icon, own launcher; the stock entry is not installed
rm -f "$STAGE/usr/share/applications/org.kde.partitionmanager.desktop"
install -d "$STAGE/usr/share/applications" "$STAGE/usr/share/icons/hicolor/scalable/apps" "$STAGE/usr/bin"
cat > "$STAGE/usr/share/applications/org.alpbahos.mirazparted.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=MirazParted
Name[tr]=MirazParted
GenericName=Partition Manager
GenericName[tr]=Disk Bölümü Yöneticisi
Comment=Create, resize, move and format disk partitions
Comment[tr]=Disk bölümlerini oluştur, boyutlandır, taşı ve biçimlendir
Exec=mirazparted %f
Icon=mirazparted
Terminal=false
Categories=Qt;KDE;System;Filesystem;
Keywords=partition;disk;format;resize;bölüm;disk;biçimlendir;
StartupNotify=true
StartupWMClass=partitionmanager
EOF
chmod 644 "$STAGE/usr/share/applications/org.alpbahos.mirazparted.desktop"
install -m 644 /tmp/mirazparted.svg "$STAGE/usr/share/icons/hicolor/scalable/apps/mirazparted.svg"
# launcher: asks before touching the disk the running system is on is done by the app's own device list; the red warning
# for the mounted root is MIRAZPARTED-02 (kdialog wrapper)
ln -s partitionmanager "$STAGE/usr/bin/mirazparted"
