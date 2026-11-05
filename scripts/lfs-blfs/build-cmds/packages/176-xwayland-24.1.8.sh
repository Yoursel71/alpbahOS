# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: xwayland-24.1.8   (order.txt row 176, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/x/xwayland.html

# --- [BUILD,INSTALL] ---
# Install xwayland by running the following commands:
sed -i '/install_man/,$d' meson.build &&

mkdir build &&
cd    build &&

meson setup ..              \
      --prefix=$XORG_PREFIX \
      --buildtype=release   \
      -D xkb_output_dir=/var/lib/xkb &&
ninja

# --- [BUILD,TEST,INSTALL,OPTIONAL] ---
# Running the tests involves downloading two other frameworks, in addition to the mentioned
# optional dependencies:
mkdir tools &&
pushd tools &&

git clone https://gitlab.freedesktop.org/mesa/piglit.git --depth 1 &&
cat > piglit/piglit.conf << EOF                                    &&
[xts]
path=$(pwd)/xts
EOF

git clone https://gitlab.freedesktop.org/xorg/test/xts --depth 1   &&

export DISPLAY=:22           &&
../hw/vfb/Xvfb $DISPLAY &
VFB_PID=$!                   &&
cd xts                       &&
CFLAGS=-fcommon ./autogen.sh &&
make                         &&
kill $VFB_PID                &&
unset DISPLAY VFB_PID        &&
popd

# --- [TEST] ---
# Then the tests can be run with:
XTEST_DIR=$(pwd)/tools/xts PIGLIT_DIR=$(pwd)/tools/piglit ninja test

# --- [INSTALL,ROOT] ---
# Now, as the root user:
ninja install

# --- [INSTALL,ROOT] ---
# If Xorg-Server-21.1.18 is not installed and you do not plan to install it later, you can install
# Xvfb from this package. As the root user:
install -vm755 hw/vfb/Xvfb /usr/bin
