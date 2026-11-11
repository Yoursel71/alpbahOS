# APPS-01, in the chroot of r4-root, from the unpacked nspr-4.40 tree (BLFS 13.1-systemd general/nspr.html).
set -e
cd nspr
sed -i '/^RELEASE/s|^|#|' pr/src/misc/Makefile.in
sed -i 's|$(LIBRARY) ||' config/rules.mk
./configure --prefix=/usr --with-mozilla --with-pthreads --enable-64bit
make
make DESTDIR="$STAGE" install
