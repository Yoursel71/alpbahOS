# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: extra-cmake-modules-6.17.0   (order.txt row 196, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/kde/extra-cmake-modules.html

# --- [BUILD] ---
# First, fix the package to be compatible with the latest Python release:
patch -Np1 -i ../extra-cmake-modules-6.17.0-upstream_fix-1.patch

# --- [BUILD,INSTALL] ---
# Install Extra Cmake Modules by running the following commands:
sed -i '/"lib64"/s/64//' kde-modules/KDEInstallDirsCommon.cmake &&

sed -e '/PACKAGE_INIT/i set(SAVE_PACKAGE_PREFIX_DIR "${PACKAGE_PREFIX_DIR}")' \
    -e '/^include/a set(PACKAGE_PREFIX_DIR "${SAVE_PACKAGE_PREFIX_DIR}")' \
    -i ECMConfig.cmake.in &&

mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr -D BUILD_WITH_QT6=ON .. &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
