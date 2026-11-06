#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.83.1: E2fsprogs-1.47.4.
# The book's optional mke2fs.conf edit (only for tools that cannot read metadata_csum_seed) is not applied.
set -euo pipefail

PKG=e2fsprogs-1.47.4.tar.gz
DIR=e2fsprogs-1.47.4
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.83.1 Installation of E2fsprogs
mkdir -v build
cd build
../configure --prefix=/usr \
             --sysconfdir=/etc \
             --enable-elf-shlibs \
             --disable-libblkid \
             --disable-libuuid \
             --disable-uuidd \
             --disable-fsck
make
make check > "$TESTS/e2fsprogs-check.log" 2>&1 || echo "NOTE e2fsprogs check exited $? (book: m_assume_storage_prezeroed and m_rootdir_acl may fail; see $TESTS/e2fsprogs-check.log)"
tail -n 3 "$TESTS/e2fsprogs-check.log"
make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info

cd /sources
rm -rf "$DIR"
echo "OK 81-e2fsprogs"
