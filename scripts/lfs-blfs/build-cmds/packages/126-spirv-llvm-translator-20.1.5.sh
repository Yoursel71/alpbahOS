# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: spirv-llvm-translator-20.1.5   (order.txt row 126, COND)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/spirv-llvm-translator.html

# --- [BUILD,INSTALL] ---
# Install SPIRV-LLVM-Translator by running the following commands:
mkdir build &&
cd    build &&

cmake -D CMAKE_INSTALL_PREFIX=/usr                   \
      -D CMAKE_BUILD_TYPE=Release                    \
      -D BUILD_SHARED_LIBS=ON                        \
      -D CMAKE_SKIP_INSTALL_RPATH=ON                 \
      -D LLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR=/usr \
      -G Ninja ..                                    &&
ninja

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install
