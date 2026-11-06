#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=6.17.0
readonly ARCHIVE="extra-cmake-modules-$VERSION.tar.xz"
readonly PATCH="extra-cmake-modules-$VERSION-upstream_fix-1.patch"
readonly WORK_ROOT="/sources/extra-cmake-modules-$VERSION-blfs-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/extra-cmake-modules-$VERSION"
readonly BUILD_ROOT="$WORK_ROOT/build"
readonly STAGE_ROOT="$WORK_ROOT/stage"
readonly PACKAGE_LOG_INSIDE="$WORK_ROOT/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/extra-cmake-modules-$VERSION-blfs-$STAMP.log"
readonly STATUS="$LOG_DIR/extra-cmake-modules-$VERSION-blfs-$STAMP.status"
readonly PACKAGE_STATUS="$LOG_DIR/extra-cmake-modules-$VERSION-blfs-$STAMP.package.status"
readonly BACKUP_DIR="$DATA/backups/extra-cmake-modules-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly PATCH_PATH="$LFS/sources/$PATCH"
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
        printf 'BLFS_ECM_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_ECM_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building KDE Extra CMake Modules %s for BLFS 12.4 KF6.\n' "$VERSION"
printf 'Installs shared CMake modules under /usr; Qt6 integration enabled. Package tests/checksum work skipped.\n'
printf 'Started: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
for item in "$ARCHIVE|$ARCHIVE_PATH|https://download.kde.org/stable/frameworks/6.17/$ARCHIVE" \
            "$PATCH|$PATCH_PATH|https://www.linuxfromscratch.org/patches/blfs/12.4/$PATCH"; do
    IFS='|' read -r file path url <<< "$item"
    if [[ ! -r "$path" ]]; then
        part="$DATA/downloads/$file.part-$STAMP"
        curl --fail --location --retry 3 --output "$part" "$url"
        sudo -n install -o 0 -g 0 -m 0644 "$part" "$path"
    else
        printf 'Using existing source input: %s\n' "$path"
    fi
done
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite existing ECM build tree $WORK_ROOT"
mkdir -p "$BACKUP_DIR"

if ! sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig LC_ALL=POSIX MAKEFLAGS=-j6 \
    /bin/bash -s -- "$ARCHIVE" "$PATCH" "$WORK_ROOT" "$SOURCE_ROOT" "$BUILD_ROOT" "$STAGE_ROOT" "$PACKAGE_LOG_INSIDE" <<'CHROOT'
set -Eeuo pipefail
archive="$1"; patch="$2"; work_root="$3"; source_root="$4"; build_root="$5"; stage_root="$6"; package_log="$7"
mkdir -pv "$work_root"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work_root"
[[ -d "$source_root" ]] || { printf 'Expected ECM source tree missing: %s\n' "$source_root" >&2; exit 1; }
cd "$source_root"
patch -Np1 -i "/sources/$patch"
sed -i '/"lib64"/s/64//' kde-modules/KDEInstallDirsCommon.cmake
sed -e '/PACKAGE_INIT/i set(SAVE_PACKAGE_PREFIX_DIR "${PACKAGE_PREFIX_DIR}")' \
    -e '/^include/a set(PACKAGE_PREFIX_DIR "${SAVE_PACKAGE_PREFIX_DIR}")' \
    -i ECMConfig.cmake.in
cmake -S . -B "$build_root" \
    -D CMAKE_INSTALL_PREFIX=/usr \
    -D BUILD_WITH_QT6=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_TESTING=OFF > "$work_root/configure.log" 2>&1 || {
        result=$?; tail -n 120 "$work_root/configure.log"; exit "$result";
    }
if cmake --build "$build_root" --parallel 6 > "$work_root/compile.log" 2>&1; then
    printf 'ECM_BUILD=PASS\n'
else
    result=$?; tail -n 120 "$work_root/compile.log"; exit "$result"
fi
mkdir -pv "$stage_root"
DESTDIR="$stage_root" cmake --install "$build_root" > "$work_root/staged-install.log" 2>&1
[[ -f "$stage_root/usr/share/ECM/cmake/ECMConfig.cmake" ]]
printf 'STAGED_INSTALL=PASS\n'
CHROOT
then
    if sudo -n test -f "$LFS$PACKAGE_LOG_INSIDE"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"; fi
    printf 'ECM_RESULT=FAIL_BUILD_OR_STAGE\nLOG=%s\n' "$LOG" > "$PACKAGE_STATUS"
    fail "ECM build or staged install failed; see $LOG"
fi
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"

sudo -n find "$LFS$STAGE_ROOT" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$STAGED0"
python3 - "$LFS" "$STAGED0" "$EXISTING0" <<'PY'
import os, sys
root, staged_path, existing_path = sys.argv[1:]
with open(staged_path, "rb") as stream:
    staged = [path for path in stream.read().split(b"\0") if path]
existing = []
for raw in staged:
    relative = os.fsdecode(raw)
    if os.path.isabs(relative) or ".." in relative.split("/"):
        raise SystemExit(f"Unsafe staged target: {relative!r}")
    if os.path.lexists(os.path.join(root, relative)):
        existing.append(raw)
with open(existing_path, "wb") as stream:
    for raw in sorted(set(existing)):
        stream.write(raw + b"\0")
print(f"Staged ECM files/symlinks: {len(staged)}; pre-existing target paths: {len(set(existing))}")
PY
if [[ -s "$EXISTING0" ]]; then
    sudo -n tar --create --file="$BACKUP_DIR/preexisting-files.tar" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$EXISTING0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_DIR/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP_DIR/preexisting-files.tar" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'ECM pre-install backup is empty.'
    printf 'Existing ECM target backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_DIR/preexisting-files.tar")"
else
    printf 'No pre-existing ECM paths; no target backup was needed.\n'
fi

if ! sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig LC_ALL=POSIX MAKEFLAGS=-j6 \
    /bin/bash -s -- "$BUILD_ROOT" "$PACKAGE_LOG_INSIDE" <<'INSTALL'
set -Eeuo pipefail
build_root="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cmake --install "$build_root"
[[ -f /usr/share/ECM/cmake/ECMConfig.cmake ]]
[[ -f /usr/share/ECM/modules/ECMFindModuleHelpers.cmake ]]
printf 'ECM_FINAL_INSTALL=PASS\n'
INSTALL
then
    if sudo -n test -f "$LFS$PACKAGE_LOG_INSIDE"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"; fi
    printf 'ECM_RESULT=FAIL_FINAL_INSTALL\nLOG=%s\n' "$LOG" > "$PACKAGE_STATUS"
    fail "ECM final install or verification failed; see $LOG"
fi
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"
printf 'ECM_RESULT=PASS\nLOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LFS$WORK_ROOT" "$BACKUP_DIR" > "$PACKAGE_STATUS"
printf '\nECM %s installed; no package tests/checksum work ran.\n' "$VERSION"
printf 'Host log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
