# BLFS 12.4-systemd build commands for PyCairo-1.28.0 (added 2026-11-05 as order row 279b; required by breeze-gtk PythonCairo)
# source: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/python-modules.html  md5 f1bb0ee59ddd78a452f27ffda3ed68ae

# --- [BUILD] ---
mkdir build &&
cd    build &&
meson setup --prefix=/usr --buildtype=release .. &&
ninja

# --- [INSTALL,ROOT] ---
ninja install
