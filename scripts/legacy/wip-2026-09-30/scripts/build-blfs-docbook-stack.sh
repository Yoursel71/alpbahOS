#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly XML=docbook-xml-4.5.zip
readonly XSL=docbook-xsl-nons-1.79.2.tar.bz2
readonly FIX=docbook-xsl-nons-1.79.2-stack_fix-1.patch
readonly WORK="/sources/docbook-stack-blfs-$STAMP"
readonly LOGDIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOGDIR/docbook-stack-blfs-$STAMP.log"
readonly STATUS="$LOGDIR/docbook-stack-blfs-$STAMP.status"
readonly BACKUP="$DATA/backups/docbook-stack-before-final-$STAMP"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'Chroot /dev is not mounted.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not all mounted.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
mkdir -p "$LOGDIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_DOCBOOK_STACK_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'BLFS_DOCBOOK_STACK_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
[[ ! -e "$LFS$WORK" ]] || fail "Refusing to overwrite $WORK"
for path in /usr/share/xml/docbook/xml-dtd-4.5 /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2; do
  sudo -n test ! -e "$LFS$path" || fail "DocBook destination already exists: $path"
done
printf 'Installing BLFS 12.4 DocBook XML 4.5 and non-namespaced XSL 1.79.2. Package tests/checksum calculations are skipped.\n'
for pair in \
  "$XML|https://docs.oasis-open.org/docbook/xml/4.5/docbook-xml-4.5.zip" \
  "$XSL|https://github.com/docbook/xslt10-stylesheets/releases/download/release/1.79.2/docbook-xsl-nons-1.79.2.tar.bz2" \
  "$FIX|https://www.linuxfromscratch.org/patches/blfs/12.4/docbook-xsl-nons-1.79.2-stack_fix-1.patch"; do
  name="$(cut -d '|' -f1 <<< "$pair")"
  url="$(cut -d '|' -f2- <<< "$pair")"
  if [[ ! -r "$LFS/sources/$name" ]]; then
    printf 'Downloading %s from %s\n' "$name" "$url"
    tmp="$DATA/downloads/$name.part-$STAMP"
    curl --fail --location --retry 3 --output "$tmp" "$url"
    sudo -n install -o 0 -g 0 -m 0644 "$tmp" "$LFS/sources/$name"
    rm -f "$tmp"
  fi
done
: > "$BACKUP/paths.list0"
for path in etc/xml/catalog etc/xml/docbook; do
  if sudo -n test -e "$LFS/$path"; then printf '%s\0' "$path" >> "$BACKUP/paths.list0"; fi
done
if [[ -s "$BACKUP/paths.list0" ]]; then
  sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/paths.list0"
  sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
  sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
  [[ -s "$BACKUP/archive.list" ]] || fail 'Pre-install backup archive is empty.'
else
  printf 'No pre-existing XML catalogs needed backup.\n' > "$BACKUP/no-preexisting-files.txt"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
  /bin/bash -s -- "$WORK" "$XML" "$XSL" "$FIX" <<'CHROOT'
set -Eeuo pipefail
work="$1"; xml="$2"; xsl="$3"; fix="$4"
mkdir -pv "$work/xml" "$work/xsl"
exec > >(tee "$work/package.log") 2>&1
python3 -m zipfile -e "/sources/$xml" "$work/xml"
tar -xjf "/sources/$xsl" -C "$work/xsl"
[[ -f "$work/xml/docbook.cat" && -f "$work/xml/docbookx.dtd" ]]
cd "$work/xsl/docbook-xsl-nons-1.79.2"
patch -Np1 -i "/sources/$fix"
install -v -d -m755 /usr/share/xml/docbook/xml-dtd-4.5 /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2 /usr/share/doc/docbook-xsl-nons-1.79.2 /etc/xml
cp -v -af --no-preserve=ownership "$work/xml/docbook.cat" "$work/xml"/*.dtd "$work/xml/ent" "$work/xml"/*.mod /usr/share/xml/docbook/xml-dtd-4.5/
cp -v -R VERSION assembly common eclipse epub epub3 extensions fo highlighting html htmlhelp images javahelp lib manpages params profiling roundtrip slides template tests tools webhelp website xhtml xhtml-1_1 xhtml5 /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/
ln -sv VERSION /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/VERSION.xsl
install -v -m644 -D README /usr/share/doc/docbook-xsl-nons-1.79.2/README.txt
install -v -m644 RELEASE-NOTES* NEWS* /usr/share/doc/docbook-xsl-nons-1.79.2/
xmlcatalog --noout --create /etc/xml/docbook
xmlcatalog --noout --create /etc/xml/catalog
xmlcatalog --noout --add public '-//OASIS//DTD DocBook XML V4.5//EN' 'http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd' /etc/xml/docbook
xmlcatalog --noout --add public '-//OASIS//DTD DocBook XML CALS Table Model V4.5//EN' 'file:///usr/share/xml/docbook/xml-dtd-4.5/calstblx.dtd' /etc/xml/docbook
xmlcatalog --noout --add public '-//OASIS//DTD XML Exchange Table Model 19990315//EN' 'file:///usr/share/xml/docbook/xml-dtd-4.5/soextblx.dtd' /etc/xml/docbook
xmlcatalog --noout --add public '-//OASIS//ELEMENTS DocBook XML Information Pool V4.5//EN' 'file:///usr/share/xml/docbook/xml-dtd-4.5/dbpoolx.mod' /etc/xml/docbook
xmlcatalog --noout --add public '-//OASIS//ELEMENTS DocBook XML Document Hierarchy V4.5//EN' 'file:///usr/share/xml/docbook/xml-dtd-4.5/dbhierx.mod' /etc/xml/docbook
xmlcatalog --noout --add public '-//OASIS//ELEMENTS DocBook XML HTML Tables V4.5//EN' 'file:///usr/share/xml/docbook/xml-dtd-4.5/htmltblx.mod' /etc/xml/docbook
xmlcatalog --noout --add public '-//OASIS//ENTITIES DocBook XML Notations V4.5//EN' 'file:///usr/share/xml/docbook/xml-dtd-4.5/dbnotnx.mod' /etc/xml/docbook
xmlcatalog --noout --add public '-//OASIS//ENTITIES DocBook XML Character Entities V4.5//EN' 'file:///usr/share/xml/docbook/xml-dtd-4.5/dbcentx.mod' /etc/xml/docbook
xmlcatalog --noout --add public '-//OASIS//ENTITIES DocBook XML Additional General Entities V4.5//EN' 'file:///usr/share/xml/docbook/xml-dtd-4.5/dbgenent.mod' /etc/xml/docbook
xmlcatalog --noout --add rewriteSystem 'http://www.oasis-open.org/docbook/xml/4.5' file:///usr/share/xml/docbook/xml-dtd-4.5 /etc/xml/docbook
xmlcatalog --noout --add rewriteURI 'http://www.oasis-open.org/docbook/xml/4.5' file:///usr/share/xml/docbook/xml-dtd-4.5 /etc/xml/docbook
xmlcatalog --noout --add delegatePublic '-//OASIS//ENTITIES DocBook XML' file:///etc/xml/docbook /etc/xml/catalog
xmlcatalog --noout --add delegatePublic '-//OASIS//DTD DocBook XML' file:///etc/xml/docbook /etc/xml/catalog
xmlcatalog --noout --add delegateSystem http://www.oasis-open.org/docbook/ file:///etc/xml/docbook /etc/xml/catalog
xmlcatalog --noout --add delegateURI http://www.oasis-open.org/docbook/ file:///etc/xml/docbook /etc/xml/catalog
for v in 4.1.2 4.2 4.3 4.4; do
  xmlcatalog --noout --add public "-//OASIS//DTD DocBook XML V$v//EN" "http://www.oasis-open.org/docbook/xml/$v/docbookx.dtd" /etc/xml/docbook
  xmlcatalog --noout --add rewriteSystem "http://www.oasis-open.org/docbook/xml/$v" file:///usr/share/xml/docbook/xml-dtd-4.5 /etc/xml/docbook
  xmlcatalog --noout --add rewriteURI "http://www.oasis-open.org/docbook/xml/$v" file:///usr/share/xml/docbook/xml-dtd-4.5 /etc/xml/docbook
  xmlcatalog --noout --add delegateSystem "http://www.oasis-open.org/docbook/xml/$v/" file:///etc/xml/docbook /etc/xml/catalog
  xmlcatalog --noout --add delegateURI "http://www.oasis-open.org/docbook/xml/$v/" file:///etc/xml/docbook /etc/xml/catalog
done
for u in 'http://cdn.docbook.org/release/xsl-nons/1.79.2' 'https://cdn.docbook.org/release/xsl-nons/1.79.2' 'http://cdn.docbook.org/release/xsl-nons/current' 'https://cdn.docbook.org/release/xsl-nons/current'; do
  xmlcatalog --noout --add rewriteSystem "$u" /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2 /etc/xml/catalog
  xmlcatalog --noout --add rewriteURI "$u" /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2 /etc/xml/catalog
done
xmlcatalog --noout --add rewriteSystem http://docbook.sourceforge.net/release/xsl/current /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2 /etc/xml/catalog
xmlcatalog --noout --add rewriteURI http://docbook.sourceforge.net/release/xsl/current /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2 /etc/xml/catalog
[[ -f /usr/share/xml/docbook/xml-dtd-4.5/docbookx.dtd && -f /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/VERSION.xsl ]]
grep -Fq 'docbookx.dtd' /etc/xml/docbook
grep -Fq 'xsl-stylesheets-nons-1.79.2' /etc/xml/catalog
printf 'DOCBOOK_XML_4_5=PASS\nDOCBOOK_XSL_NONS_1_79_2=PASS\nXML_CATALOGS=PASS\n'
CHROOT
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$LOGDIR/docbook-stack-blfs-$STAMP.package.log"
printf 'BLFS_DOCBOOK_STACK_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LOGDIR/docbook-stack-blfs-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$STATUS"
printf '\nDocBook XML/XSL catalogs installed; no package test suites or checksum calculations ran.\nStatus: %s\nFinished: %s\n' "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
