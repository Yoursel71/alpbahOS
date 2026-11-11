#!/bin/bash
# APPS-01: the DocBook XML 4.5 install of r4-root keeps its catalog entries in /etc/xml/docbook (older BLFS layout) and
# never got the book's loop that maps the DTD versions 4.1.2, 4.2, 4.3 and 4.4 to the 4.5 files (BLFS 13.1-systemd
# pst/docbook.html, "for DTDVERSION in 4.1.2 4.2 4.3 4.4"; there it edits xml-dtd-4.5/catalog.xml, which this install
# does not have). Without it xmlto cannot validate xdg-utils' DocBook 4.1.2 sources (it tries to fetch the DTD).
# The same public/rewriteSystem/rewriteURI entries are added to a copy of /etc/xml/docbook with the root's own
# xmlcatalog (chroot); record docbook-xml-catalog-apps01 0.9-apps01 takes the file over from docbook-xml (REPLACE=1).
# Run as root.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
T=/tmp/docbook-catalog-apps01
rm -rf "$R4$T" && mkdir -p "$R4$T"
trap 'rm -rf "$R4$T"' EXIT
cp "$R4/etc/xml/docbook" "$R4$T/docbook"
chroot "$R4" /usr/bin/env PATH=/usr/bin:/usr/sbin sh -c "set -e; for V in 4.1.2 4.2 4.3 4.4; do
  xmlcatalog --noout --add public \"-//OASIS//DTD DocBook XML V\$V//EN\" \"http://www.oasis-open.org/docbook/xml/\$V/docbookx.dtd\" $T/docbook
  xmlcatalog --noout --add rewriteSystem \"http://www.oasis-open.org/docbook/xml/\$V\" \"file:///usr/share/xml/docbook/xml-dtd-4.5\" $T/docbook
  xmlcatalog --noout --add rewriteURI \"http://www.oasis-open.org/docbook/xml/\$V\" \"file:///usr/share/xml/docbook/xml-dtd-4.5\" $T/docbook
done"
ST=$SB/apps01/stage-docbook-catalog
rm -rf "$ST" && install -D -m 644 "$R4$T/docbook" "$ST/etc/xml/docbook"
grep -c 'xml/4.1.2' "$ST/etc/xml/docbook"
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py docbook-xml-catalog-apps01 0.9-apps01 \
    "$ST" docbook-xml-catalog-apps01 0.9-apps01
echo "docbook-catalog-apps01 done $(date +%T)"
