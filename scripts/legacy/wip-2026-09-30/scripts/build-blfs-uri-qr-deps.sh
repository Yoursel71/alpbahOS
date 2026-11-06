#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')" LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/uri-qr-dependencies-$STAMP.log" STATUS="$LOG_DIR/uri-qr-dependencies-$STAMP.status"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" && "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]]
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]]
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]]
sudo -n true
if ps -eo comm= | awk '$1=="make"||$1=="ninja"||$1=="expect"||$1=="runtest"{f=1} END{exit f?0:1}'; then fail 'Another build/test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '
  for module in MIME::Base32 URI; do perl -M"$module" -e 1 >/dev/null 2>&1 && { echo "Already installed: $module" >&2; exit 1; } || :; done
  pkg-config --exists libqrencode && { echo "libqrencode already installed" >&2; exit 1; } || :
  for tool in perl make gcc autoconf automake libtoolize pkg-config; do command -v "$tool" >/dev/null; done
' || fail 'Target package exists or build prerequisite is missing.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads"
exec 9>"$DATA/locks/lfs-build-writer.lock"; flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if ((rc==0)); then printf 'URI_QR_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'URI_QR_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
printf 'BLFS 12.4 Perl URI prerequisites and libqrencode; package tests/checksum calculations skipped.\n'
fetch() {
  local archive="$1" url="$2" tmp="$DATA/downloads/$1.partial-$STAMP"
  if ! sudo -n test -r "$LFS/sources/$archive"; then
    curl --fail --location --retry 3 --output "$tmp" "$url"
    sudo -n install -o 0 -g 0 -m 0644 "$tmp" "$LFS/sources/$archive"
  else printf 'Using existing source: %s\n' "$LFS/sources/$archive"; fi
}
fetch MIME-Base32-1.303.tar.gz https://cpan.metacpan.org/authors/id/R/RE/REHSACK/MIME-Base32-1.303.tar.gz
fetch URI-5.32.tar.gz https://www.cpan.org/authors/id/O/OA/OALDERS/URI-5.32.tar.gz
fetch libqrencode-4.1.1.tar.gz https://github.com/fukuchi/libqrencode/archive/v4.1.1/libqrencode-4.1.1.tar.gz

build_perl() {
  local dist="$1" ver="$2" archive="$3" module="$4"
  local work="/sources/$dist-$ver-blfs-$STAMP" source="/sources/$dist-$ver-blfs-$STAMP/$dist-$ver"
  local stage="/sources/$dist-$ver-blfs-$STAMP/stage" pkglog="/sources/$dist-$ver-blfs-$STAMP/package.log"
  local backup="$DATA/backups/$dist-$ver-before-final-$STAMP"
  mkdir -p "$backup"; printf '\n--- %s %s ---\n' "$dist" "$ver"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$source" "$stage" "$pkglog" "$module" "$ver" <<'PERL'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"; pkglog="$5"; module="$6"; ver="$7"
[[ ! -e "$work" ]] || { echo "Refusing existing build tree: $work" >&2; exit 1; }
mkdir -pv "$work"; exec > >(tee "$pkglog") 2>&1
tar -xf "/sources/$archive" -C "$work"; [[ -f "$source/Makefile.PL" ]]; cd "$source"
perl Makefile.PL > "$work/configure.log" 2>&1 || { tail -n 100 "$work/configure.log"; exit 1; }
make -j4 > "$work/compile.log" 2>&1 || { tail -n 100 "$work/compile.log"; exit 1; }
mkdir -pv "$stage"; make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1
[[ -d "$stage/usr/lib/perl5" ]]; printf 'PERL_STAGED_INSTALL=PASS\n'
PERL
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOG_DIR/$dist-$ver-blfs-$STAMP.package.log"
  sudo -n find "$LFS$stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$backup/staged-paths.list0"
  python3 - "$LFS" "$backup/staged-paths.list0" "$backup/preexisting-paths.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
with open(src,'rb') as f: paths=[p for p in f.read().split(b'\0') if p]
existing=[]
for p in paths:
 r=os.fsdecode(p)
 if os.path.isabs(r) or '..' in r.split('/'): raise SystemExit('Unsafe path: '+r)
 if os.path.lexists(os.path.join(root,r)): existing.append(p)
with open(dst,'wb') as f:
 for p in sorted(set(existing)): f.write(p+b'\0')
print(f'Staged paths: {len(paths)}; existing paths: {len(set(existing))}')
PY
  if [[ -s "$backup/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$backup/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$backup/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$backup/preexisting-files.tar"
    sudo -n tar --list -f "$backup/preexisting-files.tar" > "$backup/preexisting-files.list"
    [[ -s "$backup/preexisting-files.list" ]] || fail "Empty backup for $dist"
  else printf 'No pre-existing targets.\n' > "$backup/no-preexisting-files.txt"; fi
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$source" "$pkglog" "$module" "$ver" <<'INSTALL'
set -Eeuo pipefail
source="$1"; pkglog="$2"; module="$3"; ver="$4"; exec > >(tee -a "$pkglog") 2>&1
cd "$source"; make -j1 install
perl -M"$module" -e 'my $v=eval("$ARGV[0]->VERSION"); print "$v\n"; exit(($v // "") eq $ARGV[1] ? 0 : 1)' "$module" "$ver"
printf 'PERL_INSTALL=PASS module=%s version=%s\n' "$module" "$ver"
INSTALL
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOG_DIR/$dist-$ver-blfs-$STAMP.package.log"
  printf 'PACKAGE=%s VERSION=%s RESULT=PASS BACKUP=%s\n' "$dist" "$ver" "$backup" >> "$LOG_DIR/uri-qr-dependencies-$STAMP.packages"
}
build_perl MIME-Base32 1.303 MIME-Base32-1.303.tar.gz MIME::Base32
build_perl URI 5.32 URI-5.32.tar.gz URI

printf '\n--- libqrencode 4.1.1 ---\n'
readonly QR_WORK="/sources/libqrencode-4.1.1-blfs-$STAMP" QR_SOURCE="/sources/libqrencode-4.1.1-blfs-$STAMP/libqrencode-4.1.1" QR_STAGE="/sources/libqrencode-4.1.1-blfs-$STAMP/stage" QR_LOG="/sources/libqrencode-4.1.1-blfs-$STAMP/package.log" QR_BACKUP="$DATA/backups/libqrencode-4.1.1-before-final-$STAMP"
mkdir -p "$QR_BACKUP"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- libqrencode-4.1.1.tar.gz "$QR_WORK" "$QR_SOURCE" "$QR_STAGE" "$QR_LOG" <<'QR'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"; pkglog="$5"
[[ ! -e "$work" ]] || { echo "Refusing existing build tree: $work" >&2; exit 1; }
mkdir -pv "$work"; exec > >(tee "$pkglog") 2>&1
tar -xf "/sources/$archive" -C "$work"; [[ -x "$source/autogen.sh" ]]; cd "$source"
sh autogen.sh > "$work/autogen.log" 2>&1 || { tail -n 100 "$work/autogen.log"; exit 1; }
./configure --prefix=/usr --without-tools --disable-static > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
make -j4 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -pv "$stage"; make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1
[[ -f "$stage/usr/lib/libqrencode.so" && -f "$stage/usr/include/qrencode.h" ]]
[[ -f "$stage/usr/lib/pkgconfig/libqrencode.pc" || -f "$stage/usr/lib64/pkgconfig/libqrencode.pc" ]]
printf 'QR_STAGED_INSTALL=PASS\n'
QR
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$QR_LOG" "$LOG_DIR/libqrencode-4.1.1-blfs-$STAMP.package.log"
sudo -n find "$LFS$QR_STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$QR_BACKUP/staged-paths.list0"
python3 - "$LFS" "$QR_BACKUP/staged-paths.list0" "$QR_BACKUP/preexisting-paths.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
with open(src,'rb') as f: paths=[p for p in f.read().split(b'\0') if p]
existing=[]
for p in paths:
 r=os.fsdecode(p)
 if os.path.isabs(r) or '..' in r.split('/'): raise SystemExit('Unsafe path: '+r)
 if os.path.lexists(os.path.join(root,r)): existing.append(p)
with open(dst,'wb') as f:
 for p in sorted(set(existing)): f.write(p+b'\0')
print(f'Staged paths: {len(paths)}; existing paths: {len(set(existing))}')
PY
if [[ -s "$QR_BACKUP/preexisting-paths.list0" ]]; then
  sudo -n tar --create --file="$QR_BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$QR_BACKUP/preexisting-paths.list0"
  sudo -n chown "$(id -u):$(id -g)" "$QR_BACKUP/preexisting-files.tar"
  sudo -n tar --list -f "$QR_BACKUP/preexisting-files.tar" > "$QR_BACKUP/preexisting-files.list"
  [[ -s "$QR_BACKUP/preexisting-files.list" ]] || fail 'Empty libqrencode backup.'
else printf 'No pre-existing targets.\n' > "$QR_BACKUP/no-preexisting-files.txt"; fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$QR_SOURCE" "$QR_LOG" <<'QRINSTALL'
set -Eeuo pipefail
source="$1"; pkglog="$2"; exec > >(tee -a "$pkglog") 2>&1
cd "$source"; make -j1 install; ldconfig
[[ "$(pkg-config --modversion libqrencode)" == 4.1.1 ]]
[[ -f /usr/include/qrencode.h && -f /usr/lib/libqrencode.so ]]
readelf -h /usr/lib/libqrencode.so | grep -F 'Advanced Micro Devices X86-64'
if ldd /usr/lib/libqrencode.so | grep -F 'not found'; then exit 1; fi
printf 'QR_INSTALL=PASS\n'
QRINSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$QR_LOG" "$LOG_DIR/libqrencode-4.1.1-blfs-$STAMP.package.log"
printf 'PACKAGE=libqrencode VERSION=4.1.1 RESULT=PASS BACKUP=%s\n' "$QR_BACKUP" >> "$LOG_DIR/uri-qr-dependencies-$STAMP.packages"
printf 'URI_QR_RESULT=PASS\nLOG=%s\nTESTS=SKIPPED\nCHECKSUMS=SKIPPED\n' "$LOG" > "$STATUS"
printf 'URI and QR dependencies installed.\nLog: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

