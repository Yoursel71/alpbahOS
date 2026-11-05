# BLFS 12.4-systemd build commands for libei-1.4.1 (added 2026-11-05 as order row 279e; required by kwin)
# source: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/libei.html  md5 1bed8a57a52c3ff38baa90c57661dbbf

# --- [BUILD] ---
mkdir build &&
cd    build &&
meson setup --prefix=/usr --buildtype=release -D tests=disabled &&
ninja

# --- [INSTALL,ROOT] ---
ninja install
