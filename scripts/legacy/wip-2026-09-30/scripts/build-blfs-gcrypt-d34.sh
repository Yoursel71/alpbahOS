#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly PACKAGE="${ALPBAHOS_D34_PACKAGE:?D34 runner must set ALPBAHOS_D34_PACKAGE}"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd" WORK="/dev/shm/alpbahos-d34-$PACKAGE-$STAMP"
case "$PACKAGE" in
  libgpg-error) readonly VERSION=1.55 ARCHIVE=libgpg-error-1.55.tar.bz2 ;;
  libgcrypt) readonly VERSION=1.11.2 ARCHIVE=libgcrypt-1.11.2.tar.bz2 ;;
  *) printf 'Unsupported gcrypt prerequisite: %s\n' "$PACKAGE" >&2; exit 2 ;;
esac
readonly LOG="$LOG_DIR/$PACKAGE-d34-$STAMP.log" BACKUP="$DATA/backups/$PACKAGE-d34-$STAMP"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as the regular user against the D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 \
  /bin/bash -s -- "$PACKAGE" "$VERSION" "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
package="$1"; version="$2"; archive="$3"; work="$4"
source="$work/$package-$version"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -x "$source/configure" ]]
cd "$source"
./configure --prefix=/usr > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
make -j8 > "$work/compile.log" 2>&1 || { tail -n 140 "$work/compile.log"; exit 1; }
if [[ "$package" == libgcrypt ]]; then
  make -C doc html > "$work/docs-html.log" 2>&1
  makeinfo --html --no-split -o doc/gcrypt_nochunks.html doc/gcrypt.texi > "$work/docs-nochunks.log" 2>&1
  makeinfo --plaintext -o doc/gcrypt.txt doc/gcrypt.texi > "$work/docs-text.log" 2>&1
fi
mkdir -p "$stage"; make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 100 "$work/staged-install.log"; exit 1; }
if [[ "$package" == libgpg-error ]]; then
  install -m 0644 -D README "$stage/usr/share/doc/libgpg-error-1.55/README"
  [[ -f "$stage/usr/lib/libgpg-error.so" && -f "$stage/usr/include/gpg-error.h" ]]
else
  doc="$stage/usr/share/doc/libgcrypt-1.11.2"; mkdir -p "$doc/html"
  install -m 0644 README doc/README.apichanges doc/fips* doc/libgcrypt* "$doc/"
  install -m 0644 doc/gcrypt.html/* "$doc/html/"
  install -m 0644 doc/gcrypt_nochunks.html doc/gcrypt.txt doc/gcrypt.texi "$doc/"
  [[ -f "$stage/usr/lib/libgcrypt.so" && -f "$stage/usr/include/gcrypt.h" ]]
fi
BUILD
sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'MANIFEST'
import os,sys
root,src,dst=sys.argv[1:]; paths=[p for p in open(src,'rb').read().split(b'\0') if p]
existing=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in existing))
print(f'Staged paths: {len(paths)}; existing paths: {len(existing)}')
unexpected=[p for p in existing if p != b'usr/share/info/dir']
if unexpected: raise SystemExit(f'Refusing unexpected existing targets: {unexpected[:12]!r}')
MANIFEST
if [[ -s "$BACKUP/existing.list0" ]]; then
  sudo -n tar --create --file="$BACKUP/preexisting-info-dir.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/existing.list0"
  sudo -n tar --list --file="$BACKUP/preexisting-info-dir.tar" > "$BACKUP/preexisting-info-dir.list"
  [[ -s "$BACKUP/preexisting-info-dir.list" ]] || fail 'Pre-install info index backup is empty.'
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX PKG_CONFIG_PATH=/usr/lib/pkgconfig LD_LIBRARY_PATH=/usr/lib \
  /bin/bash -s -- "$WORK/stage" "$PACKAGE" "$VERSION" <<'INSTALL'
set -Eeuo pipefail
stage="$1"; package="$2"; version="$3"
cp -a "$stage/." /; ldconfig
case "$package" in
  libgpg-error) [[ "$(pkg-config --modversion gpg-error)" == "$version" && -f /usr/lib/libgpg-error.so && -f /usr/include/gpg-error.h ]] ;;
  libgcrypt) [[ "$(pkg-config --modversion libgcrypt)" == "$version" && -f /usr/lib/libgcrypt.so && -f /usr/include/gcrypt.h ]] ;;
esac
INSTALL
printf 'D34_RESULT=PASS PACKAGE=%s VERSION=%s LOG=%s\n' "$PACKAGE" "$VERSION" "$LOG"
