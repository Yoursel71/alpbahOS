# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: cmake-4.1.0   (order.txt row 009, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/cmake.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): bin/ctest -j$(nproc)

# --- [BUILD] ---
# Install CMake by running the following commands:
sed -i '/"lib64"/s/64//' Modules/GNUInstallDirs.cmake &&

./bootstrap --prefix=/usr        \
            --system-libs        \
            --mandir=/share/man  \
            --no-system-jsoncpp  \
            --no-system-cppdap   \
            --no-system-librhash \
            --docdir=/share/doc/cmake-4.1.0 &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install
