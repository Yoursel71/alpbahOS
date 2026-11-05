# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: SPIRV-Tools-1.4.321.0   (order.txt row 125, COND)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/spirv-tools.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): ninja test

# --- [BUILD,INSTALL] ---
# Install SPIRV-Tools by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr     \
      -D CMAKE_BUILD_TYPE=Release      \
      -D SPIRV_WERROR=OFF              \
      -D BUILD_SHARED_LIBS=ON          \
      -D SPIRV_TOOLS_BUILD_STATIC=OFF  \
      -D SPIRV-Headers_SOURCE_DIR=/usr \
      -G Ninja .. &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
