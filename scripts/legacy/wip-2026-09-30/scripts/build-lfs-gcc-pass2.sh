#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly GCC_SOURCE="$SOURCES/gcc-15.2.0"
readonly BUILD_DIR="$GCC_SOURCE/build-pass2"
readonly HOST_BINUTILS="$DATA/host-tools/lfs-host/binutils-2.45/bin"
readonly BOOK_PATH="$DATA/host-tools/lfs-12.4/bin"
readonly TARGET=x86_64-lfs-linux-gnu

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

verify_source() {
    local archive="$1"
    local -a expected
    mapfile -t expected < <(awk -v file="$archive" '$2 == file { print }' "$SOURCES/md5sums")
    [[ "${#expected[@]}" == 1 ]] || fail "Expected exactly one official checksum for $archive."
    printf '%s\n' "${expected[0]}" | (cd "$SOURCES" && md5sum --check --status -) || fail "Checksum failed: $archive"
    printf 'Verified official LFS checksum: %s\n' "$archive"
}

[[ "$(id -un)" == lfs ]] || fail 'Run this build as the dedicated lfs user, not root.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on the expected ext4 filesystem."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected ext4 build directory."
[[ -x "$HOST_BINUTILS/ld" && -x "/tools/bin/$TARGET-gcc" && -x "/tools/bin/$TARGET-ld" ]] || fail 'Host Binutils 2.45 or Chapter 5 cross toolchain is missing.'
[[ -x "$LFS/usr/bin/ld" && -x "$LFS/usr/bin/as" && -f "$LFS/usr/lib/libstdc++.so.6" ]] || fail 'Chapter 5 C++ runtime or Chapter 6 Binutils Pass 2 output is missing.'
[[ -f "$GCC_SOURCE/gcc/Makefile.in" && -d "$GCC_SOURCE/gmp" && -d "$GCC_SOURCE/mpfr" && -d "$GCC_SOURCE/mpc" ]] || fail 'GCC Pass 2 sources or bundled GMP/MPFR/MPC directories are missing.'
grep -Eq '^MULTILIB_OSDIRNAMES = m64=\.\./lib' "$GCC_SOURCE/gcc/config/i386/t-linux64" || fail 'GCC source is not in the x86_64 lib-directory configuration already used for Pass 1.'
[[ -r "$SOURCES/md5sums" && -r "$SOURCES/gcc-15.2.0.tar.xz" && -r "$SOURCES/gmp-6.3.0.tar.xz" && -r "$SOURCES/mpfr-4.2.2.tar.xz" && -r "$SOURCES/mpc-1.3.1.tar.gz" ]] || fail 'GCC dependency archives or official LFS manifest are missing.'
[[ ! -e "$BUILD_DIR" && ! -e "$LFS/usr/bin/gcc" && ! -e "$LFS/usr/bin/cc" ]] || fail 'Refusing to reuse a GCC Pass 2 build tree or overwrite compiler outputs.'

verify_source gcc-15.2.0.tar.xz
verify_source gmp-6.3.0.tar.xz
verify_source mpfr-4.2.2.tar.xz
verify_source mpc-1.3.1.tar.gz

export LFS
export LFS_TGT="$TARGET"
export LC_ALL=C
export CONFIG_SHELL=/bin/bash
export MAKEFLAGS=-j4
export PATH="/tools/bin:$HOST_BINUTILS:$BOOK_PATH:/usr/bin:/bin"
unset CFLAGS CXXFLAGS LDFLAGS CPPFLAGS

cd "$GCC_SOURCE"
case "$(uname -m)" in
    x86_64) printf 'Reusing GCC Pass 1 x86_64 multilib path configuration (lib64 -> lib).\n' ;;
esac
sed '/thread_header =/s/@.*@/gthr-posix.h/' -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
mkdir -v build-pass2
cd "$BUILD_DIR"

../configure \
    --build="$(../config.guess)" \
    --host="$LFS_TGT" \
    --target="$LFS_TGT" \
    --prefix=/usr \
    --with-build-sysroot="$LFS" \
    --enable-default-pie \
    --enable-default-ssp \
    --disable-nls \
    --disable-multilib \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libsanitizer \
    --disable-libssp \
    --disable-libvtv \
    --enable-languages=c,c++ \
    LDFLAGS_FOR_TARGET="-L$PWD/$LFS_TGT/libgcc"

make
make DESTDIR="$LFS" install
ln -sv gcc "$LFS/usr/bin/cc"

printf 'Installed LFS GCC Pass 2 into %s/usr\n' "$LFS"
