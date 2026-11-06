#!/bin/bash
# Multilib LFS 13.1, chapter 6, section 6.18: GCC-16.2.0 - Pass 2
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../config.sh"
lfs_guard

PKG=gcc-16.2.0.tar.xz
PKG_DIR=gcc-16.2.0

cd $LFS/sources
rm -rf $PKG_DIR
tar -xf $PKG
cd $PKG_DIR

# 6.18.1 Installation of GCC
# As in the first build of GCC, the GMP, MPFR, and MPC packages are required.
# Unpack the tarballs and move them into the required directories:
tar -xf ../mpfr-4.2.2.tar.xz
mv -v mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz
mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.4.1.tar.xz
mv -v mpc-1.4.1 mpc

# Change the default directory name for the libraries
sed -e '/m64=/s/lib64/lib/' \
    -e '/m32=/s/m32=.*/m32=..\/lib32$(call if_multiarch,:i386-linux-gnu)/' \
    -i.orig gcc/config/i386/t-linux64

# Make -mstackrealign a default for 32-bit objects
sed '/STACK_REALIGN_DEFAULT/s/0/(!TARGET_64BIT \&\& TARGET_SSE)/' \
      -i gcc/config/i386/i386.h

# Create a separate build directory again
mkdir -v build
cd       build

../configure                     \
    --build=$(../config.guess)   \
    --host=$LFS_TGT              \
    --target=$LFS_TGT            \
    --prefix=/usr                \
    --with-build-sysroot=$LFS    \
    --enable-default-pie         \
    --enable-default-ssp         \
    --disable-fixincludes        \
    --disable-nls                \
    --enable-multilib            \
    --with-multilib-list=m64,m32 \
    --disable-libatomic          \
    --disable-libgomp            \
    --disable-libquadmath        \
    --disable-libsanitizer       \
    --disable-libssp             \
    --disable-libvtv             \
    --enable-languages=c,c++     \
    CXX_FOR_TARGET="$LFS_TGT-gcc -nostdinc++" \
    LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc \
    target_configargs=gcc_cv_target_thread_file=posix

make

make DESTDIR=$LFS install

# As a finishing touch, create a utility symlink
ln -sv gcc $LFS/usr/bin/cc

cd $LFS/sources && rm -rf $PKG_DIR
echo "OK 17-gcc-pass2"
