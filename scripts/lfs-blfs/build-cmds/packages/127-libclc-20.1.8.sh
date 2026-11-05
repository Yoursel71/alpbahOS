# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: libclc-20.1.8   (order.txt row 127, COND)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/libclc.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install libclc by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release  \
      -G Ninja ..                  &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
