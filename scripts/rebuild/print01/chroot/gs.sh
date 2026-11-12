# PRINT-01, in the chroot of r4-root: BLFS 13.1 pst/gs.html (bundled freetype/lcms2mt/jpeg/libpng/openjpeg/zlib
# removed; generic x86-64 flags instead of the book's default -O3), plus the book's two font archives.
set -e
rm -rf freetype lcms2mt jpeg libpng openjpeg zlib
./configure --prefix=/usr --disable-compile-inits --with-system-libtiff CFLAGS="-O2 -march=x86-64 -mtune=generic -fPIC"
make
make so
make DESTDIR="$STAGE" install
make DESTDIR="$STAGE" soinstall
install -v -m644 base/*.h "$STAGE/usr/include/ghostscript"
ln -sfvn ghostscript "$STAGE/usr/include/ps"
install -d "$STAGE/usr/share/ghostscript"
tar -xf ../ghostscript-fonts-std-8.11.tar.gz -C "$STAGE/usr/share/ghostscript" --no-same-owner
tar -xf ../gnu-gs-fonts-other-6.0.tar.gz -C "$STAGE/usr/share/ghostscript" --no-same-owner
