#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.55.1: Python-3.14.7.
# Book: the test suite is run with a 2-minute timeout per test; test_urllib2 and test_urllibnet fail
# without name resolution (book). The pip configuration is written as the book shows.
set -euo pipefail

PKG=Python-3.14.7.tar.xz
DIR=Python-3.14.7
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.55.1 Installation of Python 3
patch -Np1 -i ../Python-3.14.7-openssl_4-1.patch
./configure --prefix=/usr \
            --enable-shared \
            --with-system-expat \
            --enable-optimizations \
            --without-static-libpython
make
make test TESTOPTS="--timeout 120" > "$TESTS/python-test.log" 2>&1 || echo "NOTE python test exited $? (book: test_urllib2 and test_urllibnet fail offline; see $TESTS/python-test.log)"
tail -n 3 "$TESTS/python-test.log"
make install

cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF

install -v -dm755 /usr/share/doc/python-3.14.7/html
tar --strip-components=1 \
    --no-same-owner \
    --no-same-permissions \
    -C /usr/share/doc/python-3.14.7/html \
    -xvf ../python-3.14.7-docs-html.tar.bz2

cd /sources
rm -rf "$DIR"
echo "OK 53-python"
