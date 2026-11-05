# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: llvm-20.1.8   (order.txt row 123, COND)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/llvm.html

# --- [BUILD] ---
# Two additional tarballs llvm-cmake-20.1.8.src.tar.xz and llvm-third-party-20.1.8.src.tar.xz are
# needed by LLVM building system. The upstream expects them extracted at the same level as the
# llvm-20.1.8.src.tar.xz tarball, and the extracted directories renamed to cmake and third-party.
# Extract them and modify the build system to avoid creating ambiguously-named directories outside
# the llvm-20.1.8.src hierarchy:
tar -xf ../llvm-cmake-20.1.8.src.tar.xz                              &&
tar -xf ../llvm-third-party-20.1.8.src.tar.xz                        &&
sed '/LLVM_COMMON_CMAKE_UTILS/s@../cmake@cmake-20.1.8.src@'          \
    -i CMakeLists.txt                                                &&
sed '/LLVM_THIRD_PARTY_DIR/s@../third-party@third-party-20.1.8.src@' \
    -i cmake/modules/HandleLLVMOptions.cmake

# --- [INSTALL] ---
# Install clang into the source tree by running the following commands:
tar -xf ../clang-20.1.8.src.tar.xz -C tools &&
mv tools/clang-20.1.8.src tools/clang

# --- [INSTALL] ---
# If you have downloaded compiler-rt, install it into the source tree by running the following
# commands:
tar -xf ../compiler-rt-20.1.8.src.tar.xz -C projects    &&
mv projects/compiler-rt-20.1.8.src projects/compiler-rt

# --- [BUILD] ---
# There are many Python scripts in this package which use /usr/bin/env python to access the system
# Python which on LFS is Python-3.13.7. Use the following command to fix these scripts:
grep -rl '#!.*python' | xargs sed -i '1s/python$/python3/'

# --- [TEST] ---
# Ensure installing the FileCheck program which is needed by the test suite of some packages (for
# example rustc-1.89.0):
sed 's/utility/tool/' -i utils/FileCheck/CMakeLists.txt

# --- [BUILD,INSTALL] ---
# Install LLVM by running the following commands:
mkdir -v build &&
cd       build &&

CC=gcc CXX=g++                               \
cmake -D CMAKE_INSTALL_PREFIX=/usr           \
      -D CMAKE_SKIP_INSTALL_RPATH=ON         \
      -D LLVM_ENABLE_FFI=ON                  \
      -D CMAKE_BUILD_TYPE=Release            \
      -D LLVM_BUILD_LLVM_DYLIB=ON            \
      -D LLVM_LINK_LLVM_DYLIB=ON             \
      -D LLVM_ENABLE_RTTI=ON                 \
      -D LLVM_TARGETS_TO_BUILD="host;AMDGPU" \
      -D LLVM_BINUTILS_INCDIR=/usr/include   \
      -D LLVM_INCLUDE_BENCHMARKS=OFF         \
      -D CLANG_DEFAULT_PIE_ON_LINUX=ON       \
      -D CLANG_CONFIG_FILE_SYSTEM_DIR=/etc/clang \
      -W no-dev -G Ninja ..                  &&
ninja

# --- [TEST,OPTIONAL] ---
# If you wish to run the test suite and you've downloaded compiler-rt, work around an issue
# causing test failures when building LLVM with GCC and -D CLANG_CONFIG_FILE_SYSTEM_DIR and
# prevent some test suite from using ld.gold that the LFS Binutils package no longer provides:
sed -e 's/config.has_no_default_config_flag/True/' \
    -e 's/"-fuse-ld=gold"//'                       \
    -i ../projects/compiler-rt/test/lit.common.cfg.py

# --- [TEST] ---
# LLVM test suite can produce many core dump files. They will occupy a large amount of disk space,
# and the core dump process can significantly slow down the testing. To test the results with core
# dump disabled, ensure Systemd-257.8 and Shadow-4.18.0 have been rebuilt with Linux-PAM-1.7.1
# support (if you are interacting via a SSH or graphical session, also ensure the OpenSSH-10.0p1
# server or the desktop manager has been built with Linux-PAM-1.7.1) and the current login session
# is started after updating the /etc/pam.d/system-session file to include pam_systemd.so, then
# issue:
systemctl   --user start dbus &&
systemd-run --user --pty -d -G -p LimitCORE=0 ninja check-all

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [CONFIG,ROOT] ---
# If you've built Clang, as the root user create two configuration files to make SSP enabled by
# default for clang and clang++, so the default configuration of their SSP feature will be
# consistent with GCC-15.2.0:
mkdir -pv /etc/clang &&
for i in clang clang++; do
  echo -fstack-protector-strong > /etc/clang/$i.cfg
done
