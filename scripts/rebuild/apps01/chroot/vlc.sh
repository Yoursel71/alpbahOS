# APPS-01, in the chroot of r4-root, from the unpacked vlc-3.0.23 tree (BLFS 13.1-systemd multimedia/vlc.html).
# Qt 6 is under /opt/qt6 in alpbahOS. Generic x86-64 flags (D146); VLC selects SIMD code at run time.
set -e
export PATH=/opt/qt6/bin:$PATH PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:/opt/qt6/lib64/pkgconfig
sed -i 's/gstvideopool.h/video.h/' modules/codec/gstreamer/gstvlcvideopool.h
BUILDCC=gcc ./configure --prefix=/usr CFLAGS='-O2 -march=x86-64 -mtune=generic' \
    CXXFLAGS='-O2 -march=x86-64 -mtune=generic'
make -j"$JOBS"
make DESTDIR="$STAGE" docdir=/usr/share/doc/vlc-3.0.23 install
