#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')" LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/kf6-dependencies-$STAMP.log" STATUS="$LOG_DIR/kf6-dependencies-$STAMP.status"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" && "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail 'The expected ext4 LFS target is unavailable.'
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not the expected HDD bind mount.'
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1=="make"||$1=="ninja"||$1=="expect"||$1=="runtest"{f=1} END{exit f?0:1}'; then fail 'Another build/test process is active.'; fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads"
exec 9>"$DATA/locks/lfs-build-writer.lock"; flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if ((rc==0)); then printf 'KF6_DEPENDENCIES_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'KF6_DEPENDENCIES_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
printf 'Preparing remaining required BLFS 12.4 KDE Frameworks dependencies.\n'
printf 'Package suites and manual checksum calculations are skipped.\nStarted: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

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
record_package() { printf 'PACKAGE=%s VERSION=%s RESULT=%s BACKUP=%s\n' "$1" "$2" "$3" "$4" >> "$LOG_DIR/kf6-dependencies-$STAMP.packages"; }

build_autotools() {
  local name="$1" ver="$2" archive="$3" url="$4" options="$5" marker="$6" pc="$7" patchfile="$8" installopts="$9"
  shift 9
  local docs=""
  if (($# > 0)); then docs="$1"; fi
  if sudo -n test -e "$LFS$marker"; then
    printf 'Skipping %s: target marker already exists at %s\n' "$name" "$marker"
    record_package "$name" "$ver" SKIP_EXISTING "$DATA/backups/$name-$ver-before-final-$STAMP"
    return
  fi
  fetch "$archive" "$url"
  local work="/sources/$name-$ver-blfs-$STAMP" source="/sources/$name-$ver-blfs-$STAMP/$name-$ver"
  local stage="/sources/$name-$ver-blfs-$STAMP/stage" pkglog="/sources/$name-$ver-blfs-$STAMP/package.log"
  local backup="$DATA/backups/$name-$ver-before-final-$STAMP"
  mkdir -p "$backup"; printf '\n--- %s %s ---\n' "$name" "$ver"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$source" "$stage" "$pkglog" "$options" "$patchfile" "$installopts" "$docs" <<'AUTOTOOLS'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"; pkglog="$5"; options="$6"; patchfile="$7"; installopts="$8"; docs="$9"
[[ ! -e "$work" ]] || { echo "Refusing existing build tree: $work" >&2; exit 1; }
mkdir -pv "$work"; exec > >(tee "$pkglog") 2>&1
tar -xf "/sources/$archive" -C "$work"; [[ -x "$source/configure" ]]; cd "$source"
if [[ -n "$patchfile" ]]; then patch -Np1 -i "/sources/$patchfile"; fi
./configure $options > "$work/configure.log" 2>&1 || { tail -n 120 "$work/configure.log"; exit 1; }
make -j4 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -pv "$stage"
if [[ -n "$installopts" ]]; then make -j1 DESTDIR="$stage" $installopts install > "$work/staged-install.log" 2>&1
else make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1; fi
if [[ "$docs" == vorbis ]]; then
  install -v -d "$stage/usr/share/doc/libvorbis-1.3.7"
  install -v -m644 doc/Vorbis* "$stage/usr/share/doc/libvorbis-1.3.7"
fi
find "$stage" -mindepth 1 -print -quit | grep -q .
printf 'AUTOTOOLS_STAGED_INSTALL=PASS\n'
AUTOTOOLS
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOG_DIR/$name-$ver-blfs-$STAMP.package.log"
  backup_stage "$stage" "$backup"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$source" "$pkglog" "$pc" "$ver" "$installopts" "$docs" <<'AUTOTOOLS_INSTALL'
set -Eeuo pipefail
source="$1"; pkglog="$2"; pc="$3"; ver="$4"; installopts="$5"; docs="$6"; exec > >(tee -a "$pkglog") 2>&1
cd "$source"
  if [[ -n "$installopts" ]]; then make -j1 $installopts install
else make -j1 install; fi
if [[ "$docs" == vorbis ]]; then install -v -d /usr/share/doc/libvorbis-1.3.7; install -v -m644 doc/Vorbis* /usr/share/doc/libvorbis-1.3.7; fi
ldconfig
if [[ -n "$pc" ]]; then [[ "$(pkg-config --modversion "$pc")" == "$ver" ]]; fi
printf 'AUTOTOOLS_FINAL_INSTALL=PASS version=%s\n' "$ver"
AUTOTOOLS_INSTALL
  sudo -n test -e "$LFS$marker" || fail "Installed target marker missing: $marker"
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOG_DIR/$name-$ver-blfs-$STAMP.package.log"
  record_package "$name" "$ver" PASS "$backup"
}

build_cmake() {
  local name="$1" ver="$2" archive="$3" url="$4" marker="$5" args="$6" pc="$7"
  if sudo -n test -e "$LFS$marker"; then
    printf 'Skipping %s: target marker already exists at %s\n' "$name" "$marker"
    record_package "$name" "$ver" SKIP_EXISTING "$DATA/backups/$name-$ver-before-final-$STAMP"
    return
  fi
  fetch "$archive" "$url"
  local work="/sources/$name-$ver-blfs-$STAMP" source="/sources/$name-$ver-blfs-$STAMP/$name-$ver"
  local build="/sources/$name-$ver-blfs-$STAMP/build" stage="/sources/$name-$ver-blfs-$STAMP/stage"
  local pkglog="/sources/$name-$ver-blfs-$STAMP/package.log" backup="$DATA/backups/$name-$ver-before-final-$STAMP"
  mkdir -p "$backup"; printf '\n--- %s %s ---\n' "$name" "$ver"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$source" "$build" "$stage" "$pkglog" "$args" <<'CMAKE_BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; pkglog="$6"; args="$7"
[[ ! -e "$work" ]] || { echo "Refusing existing build tree: $work" >&2; exit 1; }
mkdir -pv "$work"; exec > >(tee "$pkglog") 2>&1
tar -xf "/sources/$archive" -C "$work"; [[ -f "$source/CMakeLists.txt" ]]
cmake -S "$source" -B "$build" $args > "$work/configure.log" 2>&1 || { tail -n 140 "$work/configure.log"; exit 1; }
cmake --build "$build" --parallel 4 > "$work/compile.log" 2>&1 || { tail -n 140 "$work/compile.log"; exit 1; }
mkdir -pv "$stage"; DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1
printf 'CMAKE_STAGED_INSTALL=PASS\n'
CMAKE_BUILD
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOG_DIR/$name-$ver-blfs-$STAMP.package.log"
  backup_stage "$stage" "$backup"
  sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$build" "$pkglog" "$pc" "$ver" "$marker" <<'CMAKE_INSTALL'
set -Eeuo pipefail
build="$1"; pkglog="$2"; pc="$3"; ver="$4"; marker="$5"; exec > >(tee -a "$pkglog") 2>&1
cmake --install "$build"; ldconfig
[[ -e "$marker" ]]
if [[ -n "$pc" ]]; then [[ "$(pkg-config --modversion "$pc")" == "$ver" ]]; fi
printf 'CMAKE_FINAL_INSTALL=PASS version=%s\n' "$ver"
CMAKE_INSTALL
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$pkglog" "$LOG_DIR/$name-$ver-blfs-$STAMP.package.log"
  record_package "$name" "$ver" PASS "$backup"
}

# Breeze Icons: Qt 6.9.2 and ECM are already present.
build_cmake breeze-icons 6.17.0 breeze-icons-6.17.0.tar.xz https://download.kde.org/stable/frameworks/6.17/breeze-icons-6.17.0.tar.xz /usr/lib/libKF6BreezeIcons.so '-D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_BUILD_TYPE=Release -D BUILD_TESTING=OFF -D CMAKE_PREFIX_PATH=/opt/qt6 -D Qt6_DIR=/opt/qt6/lib/cmake/Qt6 -W no-dev' ''

# libical: keep the core and GLib libraries, turn off bindings needing absent GI/Vala tools.
build_cmake libical 3.0.20 libical-3.0.20.tar.gz https://github.com/libical/libical/releases/download/v3.0.20/libical-3.0.20.tar.gz /usr/lib/libical.so '-D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_BUILD_TYPE=Release -D SHARED_ONLY=yes -D ICAL_BUILD_DOCS=false -D GOBJECT_INTROSPECTION=false -D ICAL_GLIB_VAPI=false -D USE_BUILTIN_TZDATA=yes' libical

# Required sound stack for libcanberra: Ogg, Vorbis, then the Wayland crash fix.
build_autotools libogg 1.3.6 libogg-1.3.6.tar.xz https://downloads.xiph.org/releases/ogg/libogg-1.3.6.tar.xz '--prefix=/usr --disable-static --docdir=/usr/share/doc/libogg-1.3.6' /usr/lib/libogg.so ogg '' '' ''
build_autotools libvorbis 1.3.7 libvorbis-1.3.7.tar.xz https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz '--prefix=/usr --disable-static' /usr/lib/libvorbis.so vorbis '' '' vorbis
fetch libcanberra-0.30-wayland-1.patch https://www.linuxfromscratch.org/patches/blfs/12.4/libcanberra-0.30-wayland-1.patch
build_autotools libcanberra 0.30 libcanberra-0.30.tar.xz https://0pointer.de/lennart/projects/libcanberra/libcanberra-0.30.tar.xz '--prefix=/usr --disable-oss --disable-gtk3' /usr/lib/libcanberra.so libcanberra libcanberra-0.30-wayland-1.patch 'docdir=/usr/share/doc/libcanberra-0.30' ''

# Wget is a KF6 build prerequisite; OpenSSL and make-ca are already installed.
build_autotools wget 1.25.0 wget-1.25.0.tar.gz https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz '--prefix=/usr --sysconfdir=/etc --with-ssl=openssl' /usr/bin/wget '' '' ''
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '
  [[ "$(wget --version | head -n1)" == GNU\ Wget\ 1.25.0* ]]
  wget --version | grep -Fq "https"
'
printf 'KF6_DEPENDENCIES_RESULT=PASS\nLOG=%s\nTESTS=SKIPPED\nCHECKSUMS=SKIPPED\n' "$LOG" > "$STATUS"
printf '\nAll remaining required KF6 dependencies are installed.\nLog: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
