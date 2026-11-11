# APPS-01, in the chroot of r4-root (as root), from the unpacked libreoffice-26.2.5.2 tree (BLFS 13.1-systemd
# xsoft/libreoffice.html). Build as the unprivileged user alpbuild, install into $STAGE as root. Changes from the
# book: vendor alpbahOS; UI languages Turkish (+ en-US, always built); no offline help (--without-help) and no Java
# (no JDK in alpbahOS); Qt 6 / KF6 integration for Plasma (--enable-qt6 --enable-kf6, Qt 6 under /opt/qt6) next to
# GTK 3; no MariaDB or PostgreSQL SDBC drivers and no Kerberos (the bundled PostgreSQL client needs krb5, not in
# alpbahOS); no GStreamer media playback (gst-plugins-base not in alpbahOS); HarfBuzz bundled (a system HarfBuzz needs a system graphite2, not in alpbahOS); system libraries only where r4-root has them, the rest are LibreOffice's bundled copies. The build downloads
# those copies from dev-www.libreoffice.org; LibreOffice checks each against the sha256 in its download.lst.
# Name resolution: see cbindgen.sh (systemd-resolved stub on 127.0.0.53).
set -e
mkdir -p /run/systemd/resolve
echo 'nameserver 127.0.0.53' > /run/systemd/resolve/stub-resolv.conf
sed -i '/icuuc \\/a zlib\\' writerperfect/Library_wpftdraw.mk
sed -i "/distro-install-file-lists/d" Makefile.in
sed -e "/gzip -f/d" -e "s|.1.gz|.1|g" -i bin/distro-install-desktop-integration
install -dm755 external/tarballs
cp ../libreoffice-dictionaries-26.2.5.2.tar.xz ../libreoffice-translations-26.2.5.2.tar.xz external/tarballs/
# the book: the modules are found through these links; the build unpacks the tarballs into src/
ln -sv src/libreoffice-dictionaries-26.2.5.2/dictionaries/ dictionaries
ln -sv src/libreoffice-translations-26.2.5.2/translations/ translations
mkdir -p .home
chown -R alpbuild:alpbuild .
B=$PWD
chroot --userspec=alpbuild:alpbuild / /usr/bin/env -i HOME="$B/.home" LANG=C.UTF-8 \
    PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 \
    PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig sh -c "cd '$B' && ./autogen.sh --prefix=/usr \
      --sysconfdir=/etc --with-vendor=alpbahOS --with-lang='tr' --without-help --with-myspell-dicts \
      --without-junit --without-java --without-system-dicts --disable-dconf --disable-odk \
      --disable-mariadb-sdbc --disable-postgresql-sdbc --without-krb5 --without-gssapi --disable-gstreamer-1-0 --enable-release-build=yes --enable-python=system --enable-qt6 --enable-kf6 \
      --with-parallelism=$JOBS \
      --with-system-boost --with-system-curl --with-system-epoxy --with-system-expat \
      --with-system-icu --with-system-jpeg --with-system-lcms2 --with-system-libpng --with-system-libxml \
      --with-system-nss --with-system-openssl --with-system-zlib --with-system-zstd && make build"
make DESTDIR="$STAGE" distro-pack-install
