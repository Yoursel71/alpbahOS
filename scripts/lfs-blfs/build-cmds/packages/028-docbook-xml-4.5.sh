# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: docbook-xml-4.5   (order.txt row 028, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/pst/docbook.html

# --- [INSTALL,ROOT] ---
# Install DocBook XML DTD by running the following commands as the root user:
install -v -d -m755 /usr/share/xml/docbook/xml-dtd-4.5         &&
install -v -d -m755 /etc/xml                                   &&
cp -v -af --no-preserve=ownership docbook.cat *.dtd ent/ *.mod \
    /usr/share/xml/docbook/xml-dtd-4.5

# --- [INSTALL,ROOT] ---
# Create (or update) and populate the /etc/xml/docbook catalog file by running the following
# commands as the root user:
if [ ! -e /etc/xml/docbook ]; then
    xmlcatalog --noout --create /etc/xml/docbook
fi &&

xmlcatalog --noout --add "public"                            \
    "-//OASIS//DTD DocBook XML V4.5//EN"                     \
    "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd" \
    /etc/xml/docbook &&

xmlcatalog --noout --add "public"                            \
    "-//OASIS//DTD DocBook XML CALS Table Model V4.5//EN"    \
    "file:///usr/share/xml/docbook/xml-dtd-4.5/calstblx.dtd" \
    /etc/xml/docbook &&

xmlcatalog --noout --add "public"                            \
    "-//OASIS//DTD XML Exchange Table Model 19990315//EN"    \
    "file:///usr/share/xml/docbook/xml-dtd-4.5/soextblx.dtd" \
    /etc/xml/docbook &&

xmlcatalog --noout --add "public"                              \
    "-//OASIS//ELEMENTS DocBook XML Information Pool V4.5//EN" \
    "file:///usr/share/xml/docbook/xml-dtd-4.5/dbpoolx.mod"    \
    /etc/xml/docbook &&

xmlcatalog --noout --add "public"                                \
    "-//OASIS//ELEMENTS DocBook XML Document Hierarchy V4.5//EN" \
    "file:///usr/share/xml/docbook/xml-dtd-4.5/dbhierx.mod"      \
    /etc/xml/docbook &&

xmlcatalog --noout --add "public"                            \
    "-//OASIS//ELEMENTS DocBook XML HTML Tables V4.5//EN"    \
    "file:///usr/share/xml/docbook/xml-dtd-4.5/htmltblx.mod" \
    /etc/xml/docbook &&

xmlcatalog --noout --add "public"                           \
    "-//OASIS//ENTITIES DocBook XML Notations V4.5//EN"     \
    "file:///usr/share/xml/docbook/xml-dtd-4.5/dbnotnx.mod" \
    /etc/xml/docbook &&

xmlcatalog --noout --add "public"                                \
    "-//OASIS//ENTITIES DocBook XML Character Entities V4.5//EN" \
    "file:///usr/share/xml/docbook/xml-dtd-4.5/dbcentx.mod"      \
    /etc/xml/docbook &&

xmlcatalog --noout --add "public"                                         \
    "-//OASIS//ENTITIES DocBook XML Additional General Entities V4.5//EN" \
    "file:///usr/share/xml/docbook/xml-dtd-4.5/dbgenent.mod"              \
    /etc/xml/docbook &&

xmlcatalog --noout --add "rewriteSystem"        \
    "http://www.oasis-open.org/docbook/xml/4.5" \
    "file:///usr/share/xml/docbook/xml-dtd-4.5" \
    /etc/xml/docbook &&

xmlcatalog --noout --add "rewriteURI"           \
    "http://www.oasis-open.org/docbook/xml/4.5" \
    "file:///usr/share/xml/docbook/xml-dtd-4.5" \
    /etc/xml/docbook

# --- [INSTALL,ROOT] ---
# Create (or update) and populate the /etc/xml/catalog catalog file by running the following
# commands as the root user:
if [ ! -e /etc/xml/catalog ]; then
    xmlcatalog --noout --create /etc/xml/catalog
fi &&

xmlcatalog --noout --add "delegatePublic" \
    "-//OASIS//ENTITIES DocBook XML"      \
    "file:///etc/xml/docbook"             \
    /etc/xml/catalog                      &&

xmlcatalog --noout --add "delegatePublic" \
    "-//OASIS//DTD DocBook XML"           \
    "file:///etc/xml/docbook"             \
    /etc/xml/catalog                      &&

xmlcatalog --noout --add "delegateSystem" \
    "http://www.oasis-open.org/docbook/"  \
    "file:///etc/xml/docbook"             \
    /etc/xml/catalog                      &&

xmlcatalog --noout --add "delegateURI"    \
    "http://www.oasis-open.org/docbook/"  \
    "file:///etc/xml/docbook"             \
    /etc/xml/catalog

# --- [CONFIG,ROOT] ---
# The above installation creates the files and updates the catalogs. In order to utilize DocBook
# XML DTD V4.5 when any version 4.x is requested in the System Identifier, you need to add
# additional statements to the catalog files. If you have any of the DocBook XML DTD's referenced
# below already installed on your system, remove those entries from the for command below (issue
# the commands as the root user):
for DTDVERSION in 4.1.2 4.2 4.3 4.4
do
  xmlcatalog --noout --add "public"                                  \
    "-//OASIS//DTD DocBook XML V$DTDVERSION//EN"                     \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION/docbookx.dtd" \
    /etc/xml/docbook

  xmlcatalog --noout --add "rewriteSystem"              \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION" \
    "file:///usr/share/xml/docbook/xml-dtd-4.5"         \
    /etc/xml/docbook
  
  xmlcatalog --noout --add "rewriteURI"                 \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION" \
    "file:///usr/share/xml/docbook/xml-dtd-4.5"         \
    /etc/xml/docbook
  
  xmlcatalog --noout --add "delegateSystem"              \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION/" \
    "file:///etc/xml/docbook"                            \
    /etc/xml/catalog
  
  xmlcatalog --noout --add "delegateURI"                 \
    "http://www.oasis-open.org/docbook/xml/$DTDVERSION/" \
    "file:///etc/xml/docbook"                            \
    /etc/xml/catalog
done
