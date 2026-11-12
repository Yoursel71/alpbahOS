# PRINT-01 step 2: nss-mdns 0.15.1 (not in BLFS 13.1): resolves *.local host names through avahi-daemon, so the
# printer queues cups-browsed creates (ipp://<name>.local/...) can be reached. Upstream autotools build.
set -e
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static CFLAGS="-O2 -march=x86-64 -mtune=generic"
make
make DESTDIR="$STAGE" install
rm -f "$STAGE"/usr/lib/*.la
