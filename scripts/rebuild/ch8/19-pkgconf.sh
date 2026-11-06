#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.21.1: Pkgconf-3.0.5 (built with the Meson tarball, as in the book).
set -euo pipefail

PKG=pkgconf-3.0.5.tar.xz
DIR=pkgconf-3.0.5
MESON=meson-1.12.0
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR" "$MESON"
tar -xf "$PKG"
tar -xf meson-1.12.0.tar.gz
cd "$DIR"

# 8.21.1 Installation of Pkgconf
mkdir build
cd build
python3 ../../$MESON/meson.py setup --prefix=/usr --buildtype=release ..
ninja
ninja test > "$TESTS/pkgconf-test.log" 2>&1 || echo "NOTE pkgconf test exited $? (see $TESTS/pkgconf-test.log)"
tail -n 3 "$TESTS/pkgconf-test.log"
ninja install
mv /usr/share/doc/pkgconf{,-3.0.5}
ln -sv pkgconf /usr/bin/pkg-config
ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1

# Pkg-config personalities for the multilib build (book).
ln -sv pkgconf /usr/bin/i686-pc-linux-gnu-pkg-config
ln -sv pkgconf /usr/bin/x86_64-pc-linux-gnu-pkg-config
mkdir -pv /usr/share/pkgconfig/personality.d
cat > /usr/share/pkgconfig/personality.d/i686-pc-linux-gnu.personality << EOF
Triplet: i686-pc-linux-gnu
SysrootDir: /
DefaultSearchPaths: /usr/lib32/pkgconfig:/usr/share/pkgconfig
SystemIncludePaths: /usr/include
SystemLibraryPaths: /usr/lib32
EOF
cat > /usr/share/pkgconfig/personality.d/x86_64-pc-linux-gnu.personality << EOF
Triplet: x86_64-pc-linux-gnu
SysrootDir: /
DefaultSearchPaths: /usr/lib/pkgconfig:/usr/share/pkgconfig
SystemIncludePaths: /usr/include
SystemLibraryPaths: /usr/lib
EOF

cd /sources
rm -rf "$DIR" "$MESON"
echo "OK 19-pkgconf"
