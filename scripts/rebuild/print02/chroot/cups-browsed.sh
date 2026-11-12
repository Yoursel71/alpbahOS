# PRINT-01 step 2: BLFS 13.1 pst/cups-browsed.html; remote browsing pinned to DNS-SD (the upstream default; the legacy
# CUPS browsing protocol on UDP 631 was the CVE-2024-47176 path).
set -e
./configure --prefix=/usr --with-cups-rundir=/run/cups --without-rcdir --disable-static \
    --docdir=/usr/share/doc/cups-browsed-2.1.1 --with-browseremoteprotocols=dnssd CFLAGS="-O2 -march=x86-64 -mtune=generic"
make
make DESTDIR="$STAGE" install
install -v -D -m 644 daemon/cups-browsed.service "$STAGE/usr/lib/systemd/system/cups-browsed.service"
