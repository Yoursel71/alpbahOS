# BLFS 12.4-systemd build commands for libva-2.22.0 (added 2026-11-05 as order row 279d; required by kpipewire)
# source: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/libva.html  md5 8dba13313d724b5e930f06e65b7437e2
# NOTE: the upstream tarball already ships a build/ directory, so the build dir is libva-build (not build).

# --- [BUILD] ---
mkdir libva-build &&
cd    libva-build &&
meson setup --prefix=$XORG_PREFIX --buildtype=release .. &&
ninja

# --- [INSTALL,ROOT] ---
ninja install
