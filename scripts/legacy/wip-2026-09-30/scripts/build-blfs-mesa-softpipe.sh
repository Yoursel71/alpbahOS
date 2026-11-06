#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly ARCHIVE=mesa-25.1.8.tar.xz
readonly URL=https://mesa.freedesktop.org/archive/mesa-25.1.8.tar.xz
readonly WORK_ROOT="/sources/mesa-25.1.8-blfs-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/mesa-25.1.8"
readonly BUILD_ROOT="$SOURCE_ROOT/build"
readonly STAGE_ROOT="$WORK_ROOT/stage"
readonly PACKAGE_LOG_INSIDE="$WORK_ROOT/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/mesa-25.1.8-blfs-$STAMP.log"
readonly STATUS="$LOG_DIR/mesa-25.1.8-blfs-$STAMP.status"
readonly PACKAGE_STATUS="$LOG_DIR/mesa-25.1.8-blfs-$STAMP.package.status"
readonly BACKUP_DIR="$DATA/backups/mesa-25.1.8-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.part-$STAMP"
readonly STAGED0="$BACKUP_DIR/staged-paths.list0"
readonly EXISTING0="$BACKUP_DIR/preexisting-paths.list0"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/ninja/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() {
    local result=$?
    if (( result == 0 )); then
        printf 'BLFS_MESA_SOFTPIPE_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_MESA_SOFTPIPE_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building BLFS 12.4 Mesa 25.1.8 for the alpbahOS Wayland-only graphics path.\n'
printf 'Features: Wayland platform, Gallium softpipe, GLX/X11 disabled, Vulkan disabled, LLVM disabled.\n'
printf 'Optional Mesa docs will be installed. Package test suites and checksum calculations are skipped.\n'
printf 'Source: %s\nTarget: %s\nStarted: %s\n' "$URL" "$LFS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

if [[ ! -r "$ARCHIVE_PATH" ]]; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
    rm -f "$TEMP_DOWNLOAD"
else
    printf 'Using existing source archive: %s\n' "$ARCHIVE_PATH"
fi
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite existing isolated build tree $WORK_ROOT"
mkdir -p "$BACKUP_DIR"

if ! sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK_ROOT" "$SOURCE_ROOT" "$BUILD_ROOT" "$STAGE_ROOT" "$PACKAGE_LOG_INSIDE" <<'CHROOT'
set -Eeuo pipefail
archive="$1"; work_root="$2"; source_root="$3"; build_root="$4"; stage_root="$5"; package_log="$6"
mkdir -pv "$work_root"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work_root"
[[ -d "$source_root" ]] || { printf 'Expected Mesa source tree missing: %s\n' "$source_root" >&2; exit 1; }
mkdir -pv "$build_root"
meson setup "$build_root" "$source_root" \
    --prefix=/usr \
    --buildtype=release \
    -D platforms=wayland \
    -D egl-native-platform=wayland \
    -D gallium-drivers=softpipe \
    -D vulkan-drivers=[] \
    -D glx=disabled \
    -D llvm=disabled \
    -D valgrind=disabled \
    -D libunwind=disabled > "$work_root/configure.log" 2>&1
if ninja -C "$build_root" -j4 > "$work_root/compile.log" 2>&1; then
    printf 'MESA_BUILD=PASS\n'
else
    result=$?
    tail -n 160 "$work_root/compile.log"
    exit "$result"
fi
mkdir -pv "$stage_root"
DESTDIR="$stage_root" ninja -C "$build_root" install > "$work_root/staged-install.log" 2>&1
mkdir -pv "$stage_root/usr/share/doc/mesa-25.1.8"
cp -a "$source_root/docs/." "$stage_root/usr/share/doc/mesa-25.1.8/"
[[ -d "$stage_root/usr/lib" && -d "$stage_root/usr/share/doc/mesa-25.1.8" ]]
printf 'MESA_STAGED_INSTALL=PASS\n'
CHROOT
then
    if sudo -n test -f "$LFS$PACKAGE_LOG_INSIDE"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"; fi
    printf 'MESA_RESULT=FAIL_BUILD_OR_STAGE\nLOG=%s\n' "$LOG" > "$PACKAGE_STATUS"
    fail "Mesa build or staged install failed; see $LOG"
fi
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"

sudo -n find "$LFS$STAGE_ROOT" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$STAGED0"
python3 - "$LFS" "$STAGED0" "$EXISTING0" <<'PY'
import os, sys
root, staged_path, existing_path = sys.argv[1:]
with open(staged_path, "rb") as stream: staged = [p for p in stream.read().split(b"\0") if p]
existing = []
for raw in staged:
    relative = os.fsdecode(raw)
    if os.path.isabs(relative) or ".." in relative.split("/"): raise SystemExit(f"Unsafe staged target: {relative!r}")
    if os.path.lexists(os.path.join(root, relative)): existing.append(raw)
with open(existing_path, "wb") as stream:
    for raw in sorted(set(existing)): stream.write(raw + b"\0")
print(f"Staged files/symlinks: {len(staged)}; pre-existing target paths: {len(set(existing))}")
PY
if [[ -s "$EXISTING0" ]]; then
    sudo -n tar --create --file="$BACKUP_DIR/preexisting-files.tar" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$EXISTING0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_DIR/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP_DIR/preexisting-files.tar" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'Mesa pre-install backup is empty.'
    printf 'Existing Mesa target backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_DIR/preexisting-files.tar")"
else
    printf 'No pre-existing Mesa files; no target backup was needed.\n'
fi

if ! sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$BUILD_ROOT" "$SOURCE_ROOT" "$PACKAGE_LOG_INSIDE" <<'INSTALL'
set -Eeuo pipefail
build_root="$1"; source_root="$2"; package_log="$3"
exec > >(tee -a "$package_log") 2>&1
ninja -C "$build_root" install
install -d -m 0755 /usr/share/doc/mesa-25.1.8
cp -a "$source_root/docs/." /usr/share/doc/mesa-25.1.8/
ldconfig
for file in /usr/lib/libEGL.so.1 /usr/lib/libGLESv2.so.2 /usr/lib/libGLESv1_CM.so.1 \
            /usr/lib/libgbm.so.1 /usr/lib/libgallium-25.1.8.so /usr/lib/gbm/dri_gbm.so; do
    [[ -f "$file" ]] || { printf 'Missing Mesa library: %s\n' "$file" >&2; exit 1; }
done
[[ -d /usr/lib/gbm && -d /usr/share/doc/mesa-25.1.8 ]]
pkg-config --modversion egl
pkg-config --modversion glesv2
ldd /usr/lib/libEGL.so.1 > "$source_root/mesa-libEGL-ldd.txt"
if grep -Fq 'not found' "$source_root/mesa-libEGL-ldd.txt"; then cat "$source_root/mesa-libEGL-ldd.txt"; exit 1; fi
printf 'MESA_FINAL_INSTALL=PASS\n'
INSTALL
then
    if sudo -n test -f "$LFS$PACKAGE_LOG_INSIDE"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"; fi
    printf 'MESA_RESULT=FAIL_FINAL_INSTALL\nLOG=%s\n' "$LOG" > "$PACKAGE_STATUS"
    fail "Mesa final install or verification failed; see $LOG"
fi
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"
printf 'MESA_RESULT=PASS\nLOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LFS$WORK_ROOT" "$BACKUP_DIR" > "$PACKAGE_STATUS"
printf '\nMesa 25.1.8 build/install completed; no test suite or checksum verification ran.\n'
printf 'Build tree: %s\nHost log: %s\nStatus: %s\nFinished: %s\n' "$LFS$WORK_ROOT" "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
