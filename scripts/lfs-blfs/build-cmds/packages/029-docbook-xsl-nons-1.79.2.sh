# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: docbook-xsl-nons-1.79.2   (order.txt row 029, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/pst/docbook-xsl.html

# --- [BUILD] ---
# First, fix a problem that causes stack overflows when doing recursion:
patch -Np1 -i ../docbook-xsl-nons-1.79.2-stack_fix-1.patch

# --- [BUILD,OPTIONAL] ---
# If you downloaded the optional documentation tarball, unpack it with the following command:
tar -xf ../docbook-xsl-doc-1.79.2.tar.bz2 --strip-components=1

# --- [INSTALL,ROOT] ---
# Install DocBook XSL Stylesheets by running the following commands as the root user:
install -v -m755 -d /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2 &&

cp -v -R VERSION assembly common eclipse epub epub3 extensions fo        \
         highlighting html htmlhelp images javahelp lib manpages params  \
         profiling roundtrip slides template tests tools webhelp website \
         xhtml xhtml-1_1 xhtml5                                          \
    /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2 &&

ln -s VERSION /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/VERSION.xsl &&

install -v -m644 -D README \
                    /usr/share/doc/docbook-xsl-nons-1.79.2/README.txt &&

install -v -m644    RELEASE-NOTES* NEWS* \
                    /usr/share/doc/docbook-xsl-nons-1.79.2

# --- [INSTALL,ROOT,OPTIONAL] ---
# If you downloaded the optional documentation tarball, install the documentation by issuing the
# following command as the root user:
cp -v -R doc/* /usr/share/doc/docbook-xsl-nons-1.79.2

# --- [CONFIG,ROOT] ---
# Create (or append) and populate the XML catalog file using the following commands as the root
# user (both http and https forms are used because upstream have had both in their documentation):
if [ ! -d /etc/xml ]; then install -v -m755 -d /etc/xml; fi &&
if [ ! -f /etc/xml/catalog ]; then
    xmlcatalog --noout --create /etc/xml/catalog
fi &&

xmlcatalog --noout --add "rewriteSystem"                        \
           "http://cdn.docbook.org/release/xsl-nons/1.79.2"     \
           "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
           /etc/xml/catalog &&

xmlcatalog --noout --add "rewriteSystem"                        \
           "https://cdn.docbook.org/release/xsl-nons/1.79.2"    \
           "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
           /etc/xml/catalog &&

xmlcatalog --noout --add "rewriteURI"                           \
           "http://cdn.docbook.org/release/xsl-nons/1.79.2"     \
           "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
           /etc/xml/catalog &&

xmlcatalog --noout --add "rewriteURI"                           \
           "https://cdn.docbook.org/release/xsl-nons/1.79.2"    \
           "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
           /etc/xml/catalog &&

xmlcatalog --noout --add "rewriteSystem"                        \
           "http://cdn.docbook.org/release/xsl-nons/current"    \
           "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
           /etc/xml/catalog &&

xmlcatalog --noout --add "rewriteSystem"                        \
           "https://cdn.docbook.org/release/xsl-nons/current"   \
           "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
           /etc/xml/catalog &&

xmlcatalog --noout --add "rewriteURI"                           \
           "http://cdn.docbook.org/release/xsl-nons/current"    \
           "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
           /etc/xml/catalog &&

xmlcatalog --noout --add "rewriteURI"                           \
           "https://cdn.docbook.org/release/xsl-nons/current"   \
           "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
           /etc/xml/catalog &&

xmlcatalog --noout --add "rewriteSystem"                        \
           "http://docbook.sourceforge.net/release/xsl/current" \
           "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
           /etc/xml/catalog &&

xmlcatalog --noout --add "rewriteURI"                           \
           "http://docbook.sourceforge.net/release/xsl/current" \
           "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
           /etc/xml/catalog

# --- [CONFIG] ---
# Occasionally, you may find the need to install other versions of the XSL stylesheets as some
# projects reference a specific version. One example is BLFS-6.0, which required the 1.67.2
# version. In these instances you should install any other required version in its own versioned
# directory and create catalog entries as follows (substitute the desired version number for
# <version>):
xmlcatalog --noout --add "rewriteSystem"                          \
           "http://docbook.sourceforge.net/release/xsl/<version>" \
           "/usr/share/xml/docbook/xsl-stylesheets-<version>"     \
           /etc/xml/catalog &&

xmlcatalog --noout --add "rewriteURI"                             \
           "http://docbook.sourceforge.net/release/xsl/<version>" \
           "/usr/share/xml/docbook/xsl-stylesheets-<version>"     \
           /etc/xml/catalog
