#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly LOGDIR="$DATA/logs/blfs-12.4-systemd"
readonly VERSION=0.60.8.1
readonly EN_VERSION=2020.12.07-0
readonly TR_VERSION=0.50-0
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG="$LOGDIR/aspell-$VERSION-$STAMP.log"
readonly STATUS="$LOGDIR/aspell-$VERSION-$STAMP.status"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" && "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail 'The expected ext4 LFS target is unavailable.'
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not the expected HDD bind mount.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1=="make"||$1=="ninja"||$1=="expect"||$1=="runtest"{f=1} END{exit f?0:1}'; then fail 'Another build/test process is active.'; fi

mkdir -p "$LOGDIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads"
exec 9>"$DATA/locks/lfs-build-writer.lock"; flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
CURRENT=initial
record_result() {
  local rc=$?
  if ((rc == 0)); then printf 'ASPELL_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
  else printf 'ASPELL_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$CURRENT" "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

printf 'BLFS Aspell %s plus GNU English and Turkish dictionaries.\n' "$VERSION"
printf 'Package suites and manual checksums are skipped. Sources, work trees, logs, and backups are retained.\n'

fetch() {
  local archive="$1" url="$2" tmp="$DATA/downloads/$1.partial-$STAMP"
  if ! sudo -n test -r "$LFS/sources/$archive"; then
    curl --fail --location --retry 3 --output "$tmp" "$url"
    sudo -n install -o 0 -g 0 -m 0644 "$tmp" "$LFS/sources/$archive"
  else printf 'Using existing source: %s\n' "$LFS/sources/$archive"; fi
}

backup_stage() {
  local stage="$1" backup="$2"
  sudo -n find "$LFS$stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$backup/staged-paths.list0"
  python3 - "$LFS" "$backup/staged-paths.list0" "$backup/preexisting-paths.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
with open(src,'rb') as f: paths=[p for p in f.read().split(b'\0') if p]
existing=[]
for p in paths:
 r=os.fsdecode(p)
 if os.path.isabs(r) or '..' in r.split('/'): raise SystemExit('Unsafe staged path: '+r)
 if os.path.lexists(os.path.join(root,r)): existing.append(p)
with open(dst,'wb') as f:
 for p in sorted(set(existing)): f.write(p+b'\0')
print(f'Staged paths: {len(paths)}; existing targets: {len(set(existing))}')
PY
  if [[ -s "$backup/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$backup/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$backup/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$backup/preexisting-files.tar"
    sudo -n tar --list -f "$backup/preexisting-files.tar" > "$backup/preexisting-files.list"
    [[ -s "$backup/preexisting-files.list" ]] || fail 'Pre-install backup archive is empty.'
  else printf 'No pre-existing target paths.\n' > "$backup/no-preexisting-files.txt"; fi
}

build_aspell() {
  CURRENT=aspell
  if sudo -n test -x "$LFS/usr/bin/aspell"; then
    local installed
    installed="$(sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX aspell --version | head -n1)"
    [[ "$installed" == *"$VERSION"* ]] || fail "An unexpected Aspell is already present: $installed"
    printf 'Aspell %s already present; continuing with dictionaries.\n' "$VERSION"
    return
  fi

  local archive="aspell-$VERSION.tar.gz" work="/sources/aspell-$VERSION-blfs-$STAMP"
  local source="$work/aspell-$VERSION" stage="$work/stage" pkglog="$work/package.log"
  local backup="$DATA/backups/aspell-$VERSION-before-final-$STAMP"
  fetch "$archive" "https://ftp.gnu.org/gnu/aspell/$archive"
  mkdir -p "$backup"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$source" "$stage" "$pkglog" <<'ASPELL_BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"; pkglog="$5"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -pv "$work"; exec > >(tee "$pkglog") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/modules/speller/default/vector_hash-t.hpp" && -x "$source/configure" ]]
cd "$source"
sed -e 's/; i.*size)/, e = end(); i != e; ++i, ++size_)/' -i modules/speller/default/vector_hash-t.hpp
./configure --prefix=/usr > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
make -j4 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -pv "$stage"
make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1
install -v -d "$stage/usr/lib" "$stage/usr/share/doc/aspell-0.60.8.1/aspell.html" "$stage/usr/share/doc/aspell-0.60.8.1/aspell-dev.html"
ln -svfn aspell-0.60 "$stage/usr/lib/aspell"
install -v -m644 manual/aspell.html/* "$stage/usr/share/doc/aspell-0.60.8.1/aspell.html/"
install -v -m644 manual/aspell-dev.html/* "$stage/usr/share/doc/aspell-0.60.8.1/aspell-dev.html/"
install -v -m755 scripts/ispell "$stage/usr/bin/ispell"
install -v -m755 scripts/spell "$stage/usr/bin/spell"
find "$stage" -mindepth 1 -print -quit | grep -q .
printf 'ASPELL_STAGED_INSTALL=PASS\n'
ASPELL_BUILD
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOGDIR/aspell-$VERSION-$STAMP.package.log"
  backup_stage "$stage" "$backup"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$source" "$pkglog" <<'ASPELL_INSTALL'
set -Eeuo pipefail
source="$1"; pkglog="$2"; exec > >(tee -a "$pkglog") 2>&1
cd "$source"
make -j1 install
ln -svfn aspell-0.60 /usr/lib/aspell
install -v -d /usr/share/doc/aspell-0.60.8.1/aspell.html /usr/share/doc/aspell-0.60.8.1/aspell-dev.html
install -v -m644 manual/aspell.html/* /usr/share/doc/aspell-0.60.8.1/aspell.html/
install -v -m644 manual/aspell-dev.html/* /usr/share/doc/aspell-0.60.8.1/aspell-dev.html/
install -v -m755 scripts/ispell /usr/bin/ispell
install -v -m755 scripts/spell /usr/bin/spell
ldconfig
[[ "$(aspell --version | head -n1)" == *"0.60.8.1"* ]]
[[ -f /usr/include/aspell.h && -e /usr/lib/libaspell.so && -x /usr/bin/aspell ]]
printf 'ASPELL_FINAL_INSTALL=PASS version=0.60.8.1\n'
ASPELL_INSTALL
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOGDIR/aspell-$VERSION-$STAMP.package.log"
  printf 'PACKAGE=aspell VERSION=%s RESULT=PASS BACKUP=%s\n' "$VERSION" "$backup" >> "$LOG"
}

build_dictionary() {
  local lang="$1" archive="$2" url="$3"
  CURRENT="aspell-dictionary-$lang"
  local work="/sources/aspell-dict-$lang-$STAMP"
  local stage="$work/stage" pkglog="$work/package.log"
  local backup="$DATA/backups/aspell-dict-$lang-before-final-$STAMP"
  if sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX aspell dump dicts 2>/dev/null | grep -Fxq "$lang"; then
    printf 'Aspell %s dictionary already present.\n' "$lang"
    return
  fi
  fetch "$archive" "$url"
  mkdir -p "$backup"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$stage" "$pkglog" <<'DICT_BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; stage="$3"; pkglog="$4"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -pv "$work"; exec > >(tee "$pkglog") 2>&1
first="$(tar -tf "/sources/$archive" | sed -n '1{s#/.*##;p;}')"
[[ -n "$first" && "$first" != . && "$first" != .. ]]
tar -xf "/sources/$archive" -C "$work"
source="$work/$first"
[[ -x "$source/configure" ]]
cd "$source"
./configure > "$work/configure.log" 2>&1 || { tail -n 100 "$work/configure.log"; exit 1; }
make -j4 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -pv "$stage"
make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1
find "$stage" -mindepth 1 -print -quit | grep -q .
printf 'DICT_STAGED_INSTALL=PASS source=%s\n' "$first"
DICT_BUILD
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOGDIR/aspell-dict-$lang-$STAMP.package.log"
  backup_stage "$stage" "$backup"
  local source
  source="$(sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX find "$work" -mindepth 2 -maxdepth 2 -type f -name configure -printf '%h\n' | head -n1)"
  [[ -n "$source" ]] || fail "Dictionary configure script not found in $work"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$source" "$pkglog" <<'DICT_INSTALL'
set -Eeuo pipefail
source="$1"; pkglog="$2"; exec > >(tee -a "$pkglog") 2>&1
[[ -n "$source" && -x "$source/configure" ]]
cd "$source"
make -j1 install
ldconfig
printf 'DICT_FINAL_INSTALL=PASS source=%s\n' "${source##*/}"
DICT_INSTALL
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOGDIR/aspell-dict-$lang-$STAMP.package.log"
  if ! sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX aspell dump dicts | grep -Fxq "$lang"; then
    fail "Installed dictionary '$lang' was not listed by Aspell."
  fi
  printf 'PACKAGE=aspell-dictionary-%s RESULT=PASS BACKUP=%s\n' "$lang" "$backup" >> "$LOG"
}

build_aspell
build_dictionary en aspell6-en-$EN_VERSION.tar.bz2 "https://ftp.gnu.org/gnu/aspell/dict/en/aspell6-en-$EN_VERSION.tar.bz2"
build_dictionary tr aspell-tr-$TR_VERSION.tar.bz2 "https://ftp.gnu.org/gnu/aspell/dict/tr/aspell-tr-$TR_VERSION.tar.bz2"

sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '
  aspell dump dicts | grep -Fxq en
  aspell dump dicts | grep -Fxq tr
  aspell --version | head -n1 | grep -Fq 0.60.8.1
'
printf 'ASPELL_RESULT=PASS\nLOG=%s\nDICTIONARIES=en,tr\nTESTS=NOT_PROVIDED_BY_PACKAGE\nCHECKSUMS=SKIPPED\n' "$LOG" > "$STATUS"
printf 'Aspell and dictionaries are ready.\nLog: %s\nStatus: %s\n' "$LOG" "$STATUS"
