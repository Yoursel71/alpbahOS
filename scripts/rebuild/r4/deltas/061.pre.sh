# libxml2 2.15 (026 in this list) does not apply the catalog's rewriteURI for the docbook XSL URL that
# systemd's man/custom-man.xsl imports ("Catalog error: Unregistered error message"). An exact uri entry
# resolves it (tested in the r4 chroot). The entry is added to /etc/xml/catalog (a hook file: not in manifests).
xmlcatalog --noout --add uri http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl file:///usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/manpages/docbook.xsl /etc/xml/catalog
