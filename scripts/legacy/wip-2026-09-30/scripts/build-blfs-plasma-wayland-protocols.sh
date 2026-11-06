#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=1.18.0
readonly ARCHIVE="plasma-wayland-protocols-$VERSION.tar.xz"
readonly URL="https://download.kde.org/stable/plasma-wayland-protocols/$ARCHIVE"
readonly WORK="/sources/plasma-wayland-protocols-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/plasma-wayland-protocols-$VERSION"
readonly BUILD="$SOURCE/build"
readonly STAGE="$WORK/stage"
readonly LOGDIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOGDIR/plasma-wayland-protocols-$VERSION-blfs-$STAMP.log"
readonly STATUS="$LOGDIR/plasma-wayland-protocols-$VERSION-blfs-$STAMP.status"
readonly PACKAGE_LOG="$LOGDIR/plasma-wayland-protocols-$VERSION-blfs-$STAMP.package.log"
readonly BACKUP="$DATA/backups/plasma-wayland-protocols-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the HDD build directory.'
[[ -c "$LFS/dev/null" ]] || fail 'Chroot /dev is not mounted.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not all mounted.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
  [[ -f /usr/share/ECM/cmake/ECMConfig.cmake ]]
  [[ -f /usr/share/ECM/cmake/ECMConfigVersion.cmake ]]
  [[ "$(cmake --version | head -n1)" == "cmake version 4.1.0" ]]
' || fail 'ECM 6.17.0 and CMake 4.1.0 are required.'
mkdir -p "$LOGDIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_PLASMA_WAYLAND_PROTOCOLS_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'BLFS_PLASMA_WAYLAND_PROTOCOLS_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
[[ ! -e "$LFS$WORK" ]] || fail "Refusing to overwrite $WORK"
printf 'Building BLFS 12.4 plasma-wayland-protocols %s. Package tests/checksum calculations skipped.\n' "$VERSION"
if [[ ! -r "$ARCHIVE_PATH" ]]; then
  tmp="$DATA/downloads/$ARCHIVE.part-$STAMP"
  curl --fail --location --retry 3 --output "$tmp" "$URL"
  sudo -n install -o 0 -g 0 -m 0644 "$tmp" "$ARCHIVE_PATH"
  rm -f "$tmp"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" <<'PLASMA_WAYLAND_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"
mkdir -pv "$work"
exec > >(tee "$work/package.log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/CMakeLists.txt" ]]
mkdir -pv "$build"
cmake -S "$source" -B "$build" \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D ECM_DIR=/usr/share/ECM/cmake \
  -D CMAKE_PREFIX_PATH=/usr/share/ECM \
  -D CMAKE_BUILD_TYPE=Release > "$work/configure.log" 2>&1
if cmake --build "$build" --parallel 4 > "$work/compile.log" 2>&1; then printf 'PLASMA_WAYLAND_PROTOCOLS_BUILD=PASS\n'; else rc=$?; tail -n 120 "$work/compile.log"; exit "$rc"; fi
mkdir -pv "$stage"
DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1
[[ -d "$stage/usr/share/plasma-wayland-protocols" && -d "$stage/usr/lib/cmake/PlasmaWaylandProtocols" ]]
printf 'PLASMA_WAYLAND_PROTOCOLS_STAGE=PASS\n'
PLASMA_WAYLAND_BUILD_STAGE
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,staged,out=sys.argv[1:]
with open(staged,"rb") as f: paths=[p for p in f.read().split(b"\0") if p]
old=[]
for p in paths:
    rel=os.fsdecode(p)
    if os.path.isabs(rel) or ".." in rel.split("/"): raise SystemExit(f"unsafe path: {rel}")
    if os.path.lexists(os.path.join(root,rel)): old.append(p)
with open(out,"wb") as f:
    for p in sorted(set(old)): f.write(p+b"\0")
print(f"Staged paths: {len(paths)}; existing targets: {len(set(old))}")
PY
if [[ -s "$BACKUP/existing.list0" ]]; then
  sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/existing.list0"
  sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
  sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
  [[ -s "$BACKUP/archive.list" ]] || fail 'Pre-install backup archive is empty.'
else
  printf 'No existing Plasma Wayland protocol paths needed backup.\n' > "$BACKUP/no-preexisting-files.txt"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
  /bin/bash -s -- "$BUILD" "$WORK" <<'PLASMA_WAYLAND_FINAL_INSTALL'
set -Eeuo pipefail
build="$1"; work="$2"
exec > >(tee -a "$work/package.log") 2>&1
cmake --install "$build"
[[ -d /usr/share/plasma-wayland-protocols && -d /usr/lib/cmake/PlasmaWaylandProtocols ]]
protocol_count=$(find /usr/share/plasma-wayland-protocols -type f | wc -l)
(( protocol_count >= 10 ))
[[ -f /usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake ]]
printf 'PLASMA_WAYLAND_PROTOCOLS_FINAL_INSTALL=PASS\nPROTOCOL_FILES=%s\n' "$protocol_count"
PLASMA_WAYLAND_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
printf 'BLFS_PLASMA_WAYLAND_PROTOCOLS_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$PACKAGE_LOG" "$LFS$WORK" "$BACKUP" > "$STATUS"
printf '\nPlasma Wayland protocols installed; no package test suites or checksum calculations ran.\nStatus: %s\nFinished: %s\n' "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

