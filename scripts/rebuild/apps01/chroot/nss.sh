# APPS-01, in the chroot of r4-root, from the unpacked nss-3.126 tree (BLFS 13.1-systemd postlfs/nss.html).
# The book installs from ../dist by hand; the same files go to $STAGE. NSS's make is run without -j (MAKEFLAGS cleared).
set -e
export MAKEFLAGS=
patch -Np1 -i ../nss-standalone-1.patch
cd nss
make BUILD_OPT=1 NSPR_INCLUDE_DIR=/usr/include/nspr USE_SYSTEM_ZLIB=1 ZLIB_LIBS=-lz NSS_ENABLE_WERROR=0 \
     NSS_USE_SYSTEM_SQLITE=1 USE_64=1
cd ../dist
install -v -m755 -d "$STAGE/usr/lib" "$STAGE/usr/bin" "$STAGE/usr/include/nss" "$STAGE/usr/lib/pkgconfig"
install -v -m755 Linux*/lib/*.so "$STAGE/usr/lib"
install -v -m644 Linux*/lib/*.chk "$STAGE/usr/lib"
cp -v -RL public/nss/* private/nss/* "$STAGE/usr/include/nss"
install -v -m755 Linux*/bin/certutil Linux*/bin/nss-config Linux*/bin/pk12util "$STAGE/usr/bin"
install -v -m644 Linux*/lib/pkgconfig/nss.pc "$STAGE/usr/lib/pkgconfig"
# the book: use p11-kit's trust module (system CA store) as NSS's built-in root list
ln -sfv ./pkcs11/p11-kit-trust.so "$STAGE/usr/lib/libnssckbi.so"
