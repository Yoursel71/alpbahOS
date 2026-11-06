#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly LOGDIR="$DATA/logs/blfs-12.4-systemd" VERSION=0.21.7
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG="$LOGDIR/libsecret-$VERSION-$STAMP.log" STATUS="$LOGDIR/libsecret-$VERSION-$STAMP.status"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" && -d "$DATA/lfs" && "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail 'Expected ext4 LFS target is unavailable.'
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not the expected HDD bind mount.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1=="make"||$1=="ninja"||$1=="expect"||$1=="runtest"{f=1} END{exit f?0:1}'; then fail 'Another build/test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec 'pkg-config --exists glib-2.0 libgcrypt && meson --version >/dev/null'
mkdir -p "$LOGDIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads"
exec 9>"$DATA/locks/lfs-build-writer.lock"; flock -n 9 || fail 'Another LFS writer holds the lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if ((rc==0)); then printf 'LIBSECRET_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'LIBSECRET_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
printf 'BLFS libsecret %s; tests and manual checksums skipped.\n' "$VERSION"
archive="libsecret-$VERSION.tar.xz"
if ! sudo -n test -r "$LFS/sources/$archive"; then
  tmp="$DATA/downloads/$archive.partial-$STAMP"
  curl --fail --location --retry 3 --output "$tmp" "https://download.gnome.org/sources/libsecret/0.21/$archive"
  sudo -n install -o 0 -g 0 -m 0644 "$tmp" "$LFS/sources/$archive"
fi
work="/sources/libsecret-$VERSION-blfs-$STAMP"
source="$work/libsecret-$VERSION"; build="$work/build"; stage="$work/stage"; pkglog="$work/package.log"
backup="$DATA/backups/libsecret-$VERSION-before-final-$STAMP"
mkdir -p "$backup"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$archive" "$work" "$source" "$build" "$stage" "$pkglog" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; pkglog="$6"
[[ ! -e "$work" ]] || { printf 'Refusing existing work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"; exec > "$pkglog" 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/meson.build" ]]
meson setup "$build" "$source" --prefix=/usr --buildtype=release -D gtk_doc=false -D manpage=false -D introspection=false -D vapi=false > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
meson compile -C "$build" --jobs 4 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -pv "$stage"
DESTDIR="$stage" meson install -C "$build" > "$work/staged-install.log" 2>&1 || { tail -n 100 "$work/staged-install.log"; exit 1; }
[[ -e "$stage/usr/lib/libsecret-1.so" && -e "$stage/usr/lib/pkgconfig/libsecret-1.pc" ]]
printf 'LIBSECRET_STAGED_INSTALL=PASS\n'
BUILD
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOGDIR/libsecret-$VERSION-$STAMP.package.log"
sudo -n find "$LFS$stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$backup/staged.list0"
python3 - "$LFS" "$backup/staged.list0" "$backup/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
with open(src,'rb') as f: paths=[p for p in f.read().split(b'\0') if p]
old=[]
for p in paths:
 r=os.fsdecode(p)
 if os.path.isabs(r) or '..' in r.split('/'): raise SystemExit('Unsafe staged path')
 if os.path.lexists(os.path.join(root,r)): old.append(p)
with open(dst,'wb') as f:
 for p in sorted(set(old)): f.write(p+b'\0')
print('staged',len(paths),'existing',len(set(old)))
PY
if [[ -s "$backup/existing.list0" ]]; then
  sudo -n tar -c --numeric-owner --acls --xattrs -f "$backup/preexisting.tar" -C "$LFS" --null -T "$backup/existing.list0"
  sudo -n chown "$(id -u):$(id -g)" "$backup/preexisting.tar"
  sudo -n tar -tf "$backup/preexisting.tar" > "$backup/preexisting.list"
  [[ -s "$backup/preexisting.list" ]] || fail 'Pre-install backup archive is empty.'
else printf 'No pre-existing target paths.\n' > "$backup/no-preexisting.txt"; fi
if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$build" "$pkglog" <<'INSTALL'
set -Eeuo pipefail
build="$1"; pkglog="$2"; exec >> "$pkglog" 2>&1
meson install -C "$build"
ldconfig
[[ "$(pkg-config --modversion libsecret-1)" == 0.21.7 ]]
[[ -e /usr/lib/libsecret-1.so && -f /usr/include/libsecret-1/libsecret/secret.h && -x /usr/bin/secret-tool ]]
printf 'LIBSECRET_FINAL_INSTALL=PASS version=0.21.7\n'
INSTALL
then
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOGDIR/libsecret-$VERSION-$STAMP.package.log"
  sudo -n tail -n 120 "$LFS$pkglog" || true
  fail 'libsecret final install or metadata check failed; backup retained.'
fi
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOGDIR/libsecret-$VERSION-$STAMP.package.log"
printf 'LIBSECRET_RESULT=PASS\nLOG=%s\nBACKUP=%s\nTESTS=SKIPPED\nCHECKSUMS=SKIPPED\n' "$LOG" "$backup" > "$STATUS"
printf 'libsecret %s installed.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
