# APPS-01, in the chroot of r4-root, from the unpacked lynx2.9.3 tree (BLFS 13.1-systemd basicnet/lynx.html).
# Needed by xmlto's text backend, which xdg-utils uses to build its scripts. Documentation is not installed.
set -e
./configure --prefix=/usr --sysconfdir=/etc/lynx --with-zlib --with-bzlib --with-ssl --with-screen=ncursesw \
    --enable-ipv6 --enable-locale-charset --enable-nls --datadir=/usr/share/doc/lynx-2.9.3 \
    CFLAGS='-O2 -march=x86-64 -mtune=generic'
make
make DESTDIR="$STAGE" install
sed -e '/#LOCALE/     a LOCALE_CHARSET:TRUE'     -i "$STAGE/etc/lynx/lynx.cfg"
sed -e '/#DEFAULT_ED/ a DEFAULT_EDITOR:vi'       -i "$STAGE/etc/lynx/lynx.cfg"
sed -e '/#PERSIST/    a PERSISTENT_COOKIES:TRUE' -i "$STAGE/etc/lynx/lynx.cfg"
