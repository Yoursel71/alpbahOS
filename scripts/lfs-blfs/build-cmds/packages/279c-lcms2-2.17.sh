# BLFS 12.4-systemd build commands for Little CMS2-2.17 (added 2026-11-05 as order row 279c; required by kwin color management)
# source: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/lcms2.html  md5 9f44275ee8ac122817e94fdc50ecce13

# --- [BUILD] ---
./configure --prefix=/usr --disable-static &&
make

# --- [INSTALL,ROOT] ---
make install
