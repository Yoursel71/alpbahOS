#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapters 8.53.1-8.53.2: SQLite-3530400 (64-bit, then 32-bit).
set -euo pipefail

PKG=sqlite-autoconf-3530400.tar.gz
DIR=sqlite-autoconf-3530400

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"
python3 -m zipfile -e ../sqlite-doc-3530400.zip .

# 8.53.1 Installation of SQLite
./configure --prefix=/usr \
            --disable-static \
            --enable-fts{4,5} \
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1 \
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1 \
                      -D SQLITE_SECURE_DELETE=1"
make LDFLAGS.rpath=""
make install
cp -v -R sqlite-doc-3530400 -T /usr/share/doc/sqlite-3.53.4

# 8.53.2 Installation of SQLite - 32-bit
make distclean
CC="gcc -m32" CXX="g++ -m32" \
./configure --prefix=/usr \
            --libdir=/usr/lib32 \
            --host=i686-pc-linux-gnu \
            --disable-static \
            --enable-fts{4,5} \
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1 \
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1 \
                      -D SQLITE_SECURE_DELETE=1"
make LDFLAGS.rpath=""
make DESTDIR=$PWD/DESTDIR install
cp -Rv DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR

cd /sources
rm -rf "$DIR"
echo "OK 51-sqlite"
