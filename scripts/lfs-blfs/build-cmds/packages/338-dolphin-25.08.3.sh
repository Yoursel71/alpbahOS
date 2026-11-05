# Dolphin 25.08.3 build commands (added 2026-11-05 as order row 338; not in BLFS 12.4 book; Meta+E dosya yöneticisi).
# source: https://download.kde.org/stable/release-service/25.08.3/src/dolphin-25.08.3.tar.xz
# verification: GPG signature (dolphin-25.08.3.tar.xz.sig) by KDE key D81C0CB38EB725EF6691C385BB463350D6EF31EF (Heiko Becker); sha256 1abd632ebe3837df5616216f69c3ca9f6240165f9f84502422203275eaa8ee09
# standard KDE build (KF6 prefix /usr; Qt 6.9.2 from /opt/qt6)
# Opsiyonel bağımlılıklar derlenmedi: KF6BalooWidgets (metadata/bilgi paneli özellikleri), KF6UserFeedback, PackageKit.

# --- [BUILD] ---
mkdir build &&
cd    build &&
cmake -D CMAKE_INSTALL_PREFIX=$KF6_PREFIX \
      -D CMAKE_BUILD_TYPE=Release         \
      -D BUILD_TESTING=OFF                \
      -W no-dev .. &&
make

# --- [INSTALL,ROOT] ---
make install
