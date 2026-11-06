#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.17.1: Tcl-8.6.18.
set -euo pipefail

PKG=tcl8.6.18-src.tar.gz
DOCPKG=tcl8.6.18-html.tar.gz
DIR=tcl8.6.18
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.17.1 Installation of Tcl
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr \
            --mandir=/usr/share/man \
            --disable-rpath
make

sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|" \
    -i tclConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.13|/usr/lib/tdbc1.1.13|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.13/generic|/usr/include|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.13/library|/usr/lib/tcl8.6|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.13|/usr/include|" \
    -i pkgs/tdbc1.1.13/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.7|/usr/lib/itcl4.3.7|" \
    -e "s|$SRCDIR/pkgs/itcl4.3.7/generic|/usr/include|" \
    -e "s|$SRCDIR/pkgs/itcl4.3.7|/usr/include|" \
    -i pkgs/itcl4.3.7/itclConfig.sh
unset SRCDIR

LC_ALL=C.UTF-8 make test > "$TESTS/tcl-test.log" 2>&1 || echo "NOTE tcl test exited $? (see $TESTS/tcl-test.log)"
tail -n 3 "$TESTS/tcl-test.log"
make install
chmod -v 644 /usr/lib/libtclstub8.6.a
chmod -v u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sfv tclsh8.6 /usr/bin/tclsh
mv -v /usr/share/man/man3/{Thread,Tcl_Thread}.3

cd ..
tar -xf ../$DOCPKG --strip-components=1
mkdir -v -p /usr/share/doc/tcl-8.6.18
cp -v -r ./html/* /usr/share/doc/tcl-8.6.18

cd /sources
rm -rf "$DIR"
echo "OK 15-tcl"
