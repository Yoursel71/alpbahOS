# APPS-01, in the chroot of r4-root, from the unpacked node-v24.19.0 tree (BLFS 13.1-systemd general/nodejs.html).
# Shared: OpenSSL, zlib, system ICU (in r4-root). brotli, c-ares, libuv, nghttp2 and simdutf: bundled copies (the
# book's --shared-* options need those libraries, which r4-root does not have or has in another version).
set -e
./configure --prefix=/usr --shared-openssl --shared-zlib --with-intl=system-icu
make -j"$JOBS"
make DESTDIR="$STAGE" install
