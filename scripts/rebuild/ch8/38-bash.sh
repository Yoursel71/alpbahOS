#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.40.1: Bash-5.3.
# The book's shell restart (exec bash --login) is not run in a script.
set -euo pipefail

PKG=bash-5.3.tar.gz
DIR=bash-5.3
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.40.1 Installation of Bash
./configure --prefix=/usr \
            --without-bash-malloc \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-5.3
make
chown -R tester .
# The book runs the tests under expect so the tester user has a controlling terminal.
LC_ALL=C.UTF-8 su -s /usr/bin/expect tester << "EOF" > "$TESTS/bash-check.log" 2>&1 || echo "NOTE bash test exited $? (see $TESTS/bash-check.log)"
set timeout -1
spawn make tests
expect eof
lassign [wait] _ _ _ value
exit $value
EOF
tail -n 3 "$TESTS/bash-check.log"
make install

cd /sources
rm -rf "$DIR"
echo "OK 38-bash"
