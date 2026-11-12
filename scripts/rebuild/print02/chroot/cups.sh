# PRINT-01 step 2: CUPS 2.4.19 again, BLFS 13.1 pst/cups.html (the book's two seds and options) plus --with-dnssd=avahi
# (fails if Avahi is missing): the dnssd backend, network printer discovery and IPP Everywhere temporary queues.
set -e
sed -i 's#@CUPS_HTMLVIEW@#firefox#' desktop/cups.desktop.in
sed -i '/& ipp->prev)/s/prev/& \&\& ipp->prev->next == *attr/' cups/ipp.c
./configure --libdir=/usr/lib --with-rundir=/run/cups --with-system-groups=lpadmin \
    --with-docdir=/usr/share/cups/doc-2.4.19 --with-dnssd=avahi \
    CFLAGS="-O2 -march=x86-64 -mtune=generic" CXXFLAGS="-O2 -march=x86-64 -mtune=generic"
make
make DESTDIR="$STAGE" install
install -d -m 755 "$STAGE/usr/share/doc"
ln -svnf ../cups/doc-2.4.19 "$STAGE/usr/share/doc/cups-2.4.19"
