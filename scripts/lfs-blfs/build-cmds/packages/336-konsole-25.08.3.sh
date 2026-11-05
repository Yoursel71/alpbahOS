# Konsole 25.08.3 build commands (added 2026-11-05 as order row 336; not in BLFS 12.4 book).
# source: https://download.kde.org/stable/release-service/25.08.3/src/konsole-25.08.3.tar.xz
# verification: GPG signature (konsole-25.08.3.tar.xz.sig) by KDE key D81C0CB38EB725EF6691C385BB463350D6EF31EF; sha256 095a7ff10df3c70779b356fb3b5984062bbc698bbed966230e3dbccf6af36615
# standard KDE build (KF6 prefix /usr; Qt 6.9.2 from /opt/qt6)

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
