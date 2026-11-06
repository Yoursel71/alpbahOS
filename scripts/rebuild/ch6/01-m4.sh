#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.2: M4-1.4.21
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=m4-1.4.21.tar.xz
PKG_DIR=m4-1.4.21

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.2.1 Installation of M4
cat > $LFS/usr/share/config.site << EOF
ac_cv_func_posix_spawn_file_actions_addchdir=yes
ac_cv_func_posix_spawn_file_actions_addfchdir=yes
EOF

./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make

make DESTDIR=$LFS install

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 01-m4"
