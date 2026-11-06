#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly PACKAGE="${ALPBAHOS_D34_PACKAGE:?D34 runner must set ALPBAHOS_D34_PACKAGE}"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-$PACKAGE-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/$PACKAGE-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/$PACKAGE-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/$PACKAGE-d34-$STAMP"
case "$PACKAGE" in
  docbook-xml)
    readonly VERSION=4.5 ARCHIVE=docbook-xml-4.5.zip
    ;;
  docbook-xsl)
    readonly VERSION=1.79.2 ARCHIVE=docbook-xsl-nons-1.79.2.tar.bz2
    readonly PATCH=docbook-xsl-nons-1.79.2-stack_fix-1.patch
    ;;
  docbook-catalogs)
    readonly VERSION=alpbahOS-1 ARCHIVE=''
    ;;
  *) printf 'Unsupported D34 DocBook package: %s\n' "$PACKAGE" >&2; exit 2 ;;
esac

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular host user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another package build is active.'
fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$STATUS"; else printf 'D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

if [[ -n "$ARCHIVE" && ! -r "$DATA/downloads/$ARCHIVE" ]]; then
    temp="$DATA/downloads/$ARCHIVE.part-$STAMP"
    case "$PACKAGE" in
      docbook-xml) url=https://docs.oasis-open.org/docbook/xml/4.5/docbook-xml-4.5.zip ;;
      docbook-xsl) url=https://github.com/docbook/xslt10-stylesheets/releases/download/release/1.79.2/docbook-xsl-nons-1.79.2.tar.bz2 ;;
    esac
    curl --fail --location --retry 3 --output "$temp" "$url"
    mv -- "$temp" "$DATA/downloads/$ARCHIVE"
fi
if [[ -n "$ARCHIVE" ]]; then sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"; fi
if [[ "$PACKAGE" == docbook-xsl ]]; then
    patch_archive="$DATA/downloads/$PATCH"
    if [[ ! -r "$patch_archive" ]]; then
        curl --fail --location --retry 3 --output "$patch_archive.part-$STAMP" \
            https://www.linuxfromscratch.org/patches/blfs/12.4/docbook-xsl-nons-1.79.2-stack_fix-1.patch
        mv -- "$patch_archive.part-$STAMP" "$patch_archive"
    fi
    sudo -n install -o 0 -g 0 -m 0644 "$patch_archive" "$LFS/sources/$PATCH"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    LC_ALL=POSIX /bin/bash -s -- "$PACKAGE" "$WORK" "${ARCHIVE:-}" "${PATCH:-}" <<'BUILD'
set -Eeuo pipefail
package="$1"; work="$2"; archive="$3"; patch_file="$4"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work" "$stage"
case "$package" in
  docbook-xml)
    mkdir -p "$work/xml"
    python3 -m zipfile -e "/sources/$archive" "$work/xml"
    [[ -f "$work/xml/docbook.cat" && -f "$work/xml/docbookx.dtd" ]]
    install -v -d "$stage/usr/share/xml/docbook/xml-dtd-4.5"
    cp -a --no-preserve=ownership "$work/xml/docbook.cat" "$work/xml"/*.dtd "$work/xml/ent" \
        "$work/xml"/*.mod "$stage/usr/share/xml/docbook/xml-dtd-4.5/"
    ;;
  docbook-xsl)
    mkdir -p "$work/xsl"
    tar -xjf "/sources/$archive" -C "$work/xsl"
    src="$work/xsl/docbook-xsl-nons-1.79.2"
    [[ -f "$src/VERSION" ]]
    cd "$src"
    patch -Np1 -i "/sources/$patch_file"
    dest="$stage/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2"
    install -v -d "$dest" "$stage/usr/share/doc/docbook-xsl-nons-1.79.2"
    cp -R VERSION assembly common eclipse epub epub3 extensions fo highlighting html htmlhelp images javahelp \
      lib manpages params profiling roundtrip slides template tests tools webhelp website xhtml xhtml-1_1 xhtml5 "$dest/"
    ln -s VERSION "$dest/VERSION.xsl"
    install -v -m644 README "$stage/usr/share/doc/docbook-xsl-nons-1.79.2/README.txt"
    install -v -m644 RELEASE-NOTES* NEWS* "$stage/usr/share/doc/docbook-xsl-nons-1.79.2/"
    ;;
  docbook-catalogs)
    install -v -d "$stage/etc/xml"
    if [[ -f /etc/xml/catalog ]]; then cp -a /etc/xml/catalog "$stage/etc/xml/catalog"; else xmlcatalog --noout --create "$stage/etc/xml/catalog"; fi
    xmlcatalog --noout --create "$stage/etc/xml/docbook"
    xmlcatalog --noout --add public '-//OASIS//DTD DocBook XML V4.5//EN' \
      'http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd' "$stage/etc/xml/docbook"
    xmlcatalog --noout --add public '-//OASIS//DTD DocBook XML CALS Table Model V4.5//EN' \
      file:///usr/share/xml/docbook/xml-dtd-4.5/calstblx.dtd "$stage/etc/xml/docbook"
    xmlcatalog --noout --add rewriteSystem 'http://www.oasis-open.org/docbook/xml/4.5' \
      file:///usr/share/xml/docbook/xml-dtd-4.5 "$stage/etc/xml/docbook"
    xmlcatalog --noout --add rewriteURI 'http://www.oasis-open.org/docbook/xml/4.5' \
      file:///usr/share/xml/docbook/xml-dtd-4.5 "$stage/etc/xml/docbook"
    xmlcatalog --noout --add delegatePublic '-//OASIS//ENTITIES DocBook XML' file:///etc/xml/docbook "$stage/etc/xml/catalog"
    xmlcatalog --noout --add delegatePublic '-//OASIS//DTD DocBook XML' file:///etc/xml/docbook "$stage/etc/xml/catalog"
    xmlcatalog --noout --add delegateSystem http://www.oasis-open.org/docbook/ file:///etc/xml/docbook "$stage/etc/xml/catalog"
    xmlcatalog --noout --add delegateURI http://www.oasis-open.org/docbook/ file:///etc/xml/docbook "$stage/etc/xml/catalog"
    xmlcatalog --noout --add rewriteSystem http://docbook.sourceforge.net/release/xsl/current \
      /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2 "$stage/etc/xml/catalog"
    xmlcatalog --noout --add rewriteURI http://docbook.sourceforge.net/release/xsl/current \
      /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2 "$stage/etc/xml/catalog"
    ;;
esac
[[ -n "$(find "$stage" -mindepth 1 -print -quit)" ]]
BUILD

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$PACKAGE" "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
package,root,src,dst=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
allowed={b'etc/xml/catalog',b'etc/xml/docbook'} if package=='docbook-catalogs' else set()
unexpected=[p for p in collisions if p not in allowed]
open(dst,'wb').write(b''.join(collisions))
print(f"{package} staged paths={len(paths)} collisions={len(collisions)}")
if unexpected: raise SystemExit(f"Refusing unexpected existing candidate paths: {unexpected!r}")
PY
if [[ -s "$BACKUP/existing.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$BACKUP/existing.list0"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/preexisting-files.list"
    [[ -s "$BACKUP/preexisting-files.list" ]] || fail 'DocBook catalog pre-install backup is empty.'
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$PACKAGE" "$WORK/stage" <<'INSTALL'
set -Eeuo pipefail
package="$1"; stage="$2"
cp -a "$stage/." /
case "$package" in
  docbook-xml) [[ -f /usr/share/xml/docbook/xml-dtd-4.5/docbookx.dtd ]] ;;
  docbook-xsl) [[ -f /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/VERSION.xsl ]] ;;
  docbook-catalogs)
    [[ -f /etc/xml/catalog && -f /etc/xml/docbook ]]
    xmllint --nonet --noout /etc/xml/catalog /etc/xml/docbook
    grep -Fq 'docbookx.dtd' /etc/xml/docbook
    ;;
esac
INSTALL
printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$STATUS"
