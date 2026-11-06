#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=6.9.2
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qt-wayland-modules-$STAMP.log"
readonly STATUS="$LOG_DIR/qt-wayland-modules-$STAMP.status"

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

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$LFS/sources/qt"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() {
    local result=$?
    if (( result == 0 )); then
        printf 'BLFS_QT_WAYLAND_MODULES_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_QT_WAYLAND_MODULES_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building Qt ShaderTools, Declarative, and Wayland modules %s in sequence.\n' "$VERSION"
printf 'QtBase is the /opt/qt6 Wayland profile; XCB/X11 and package tests remain disabled.\n'
printf 'Started: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

build_module() {
    local module="$1" archive="${1}-everywhere-src-$VERSION.tar.xz" url="https://download.qt.io/archive/qt/6.9/6.9.2/submodules/${1}-everywhere-src-$VERSION.tar.xz"
    local source_dir="${1}-everywhere-src-$VERSION"
    local work_root="/sources/qt-${module}-$VERSION-wayland-$STAMP"
    local source_root="$work_root/$source_dir"
    local build_root="$work_root/build"
    local stage_root="$work_root/stage"
    local package_log_inside="$work_root/package.log"
    local package_log="$LOG_DIR/qt-${module}-$VERSION-wayland-$STAMP.log"
    local package_status="$LOG_DIR/qt-${module}-$VERSION-wayland-$STAMP.status"
    local backup_dir="$DATA/backups/qt-${module}-before-final-$STAMP"
    local archive_path="$LFS/sources/qt/$archive"
    local temp_download="$DATA/downloads/$archive.part-$STAMP"
    local staged0="$backup_dir/staged-paths.list0"
    local existing0="$backup_dir/preexisting-paths.list0"

    printf '\n=== Qt %s %s ===\n' "$module" "$VERSION"
    if [[ ! -r "$archive_path" ]]; then
        curl --fail --location --retry 3 --output "$temp_download" "$url"
        sudo -n install -o 0 -g 0 -m 0644 "$temp_download" "$archive_path"
        rm -f "$temp_download"
    else
        printf 'Using existing source archive: %s\n' "$archive_path"
    fi
    [[ ! -e "$LFS$work_root" ]] || fail "Refusing to overwrite isolated module tree $work_root"
    mkdir -p "$backup_dir"

    if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin \
        QT6DIR=/opt/qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig LC_ALL=POSIX MAKEFLAGS=-j6 \
        /bin/bash -s -- "$archive" "$work_root" "$source_root" "$build_root" "$stage_root" "$package_log_inside" "$module" <<'CHROOT'
set -Eeuo pipefail
archive="$1"; work_root="$2"; source_root="$3"; build_root="$4"; stage_root="$5"; package_log="$6"; module="$7"
mkdir -pv "$work_root"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/qt/$archive" -C "$work_root"
[[ -d "$source_root" ]] || { printf 'Expected Qt module source missing: %s\n' "$source_root" >&2; exit 1; }
[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 ]] || { printf 'Installed QtBase 6.9.2 is required.\n' >&2; exit 1; }
mkdir -pv "$build_root"
cd "$build_root"
if qt-configure-module "$source_root" > "$work_root/configure.log" 2>&1; then
    printf 'QT_MODULE_CONFIGURE=PASS\n'
else
    result=$?; tail -n 140 "$work_root/configure.log"; exit "$result"
fi
if ninja -j6 > "$work_root/compile.log" 2>&1; then
    printf 'QT_MODULE_BUILD=PASS\n'
else
    result=$?; tail -n 160 "$work_root/compile.log"; exit "$result"
fi
mkdir -pv "$stage_root"
DESTDIR="$stage_root" cmake --install . > "$work_root/staged-install.log" 2>&1
case "$module" in
    qtshadertools) [[ -f "$stage_root/opt/qt6/lib/libQt6ShaderTools.so.6" ]] ;;
    qtdeclarative) [[ -f "$stage_root/opt/qt6/lib/libQt6Qml.so.6" && -f "$stage_root/opt/qt6/lib/libQt6Quick.so.6" ]] ;;
    qtwayland) [[ -f "$stage_root/opt/qt6/lib/libQt6WaylandClient.so.6" ]] ;;
    *) printf 'Unknown Qt module: %s\n' "$module" >&2; exit 2 ;;
esac
printf 'STAGED_INSTALL=PASS\n'
CHROOT
    then
        if sudo -n test -f "$LFS$package_log_inside"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"; fi
        printf 'QT_MODULE_RESULT=FAIL_BUILD_OR_STAGE\nLOG=%s\n' "$package_log" > "$package_status"
        fail "Qt $module build or staged install failed; see $package_log"
    fi
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"

    sudo -n find "$LFS$stage_root" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$staged0"
    python3 - "$LFS" "$staged0" "$existing0" <<'PY'
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
print(f"Staged paths: {len(staged)}; pre-existing paths: {len(set(existing))}")
PY
    if [[ -s "$existing0" ]]; then
        sudo -n tar --create --file="$backup_dir/preexisting-files.tar" --numeric-owner --acls --xattrs \
            -C "$LFS" --null --files-from="$existing0"
        sudo -n chown "$(id -u):$(id -g)" "$backup_dir/preexisting-files.tar"
        sudo -n tar --list --file="$backup_dir/preexisting-files.tar" > "$backup_dir/archive.list"
        [[ -s "$backup_dir/archive.list" ]] || fail "Qt $module pre-install backup is empty"
        printf 'Existing Qt %s target backup: %s bytes\n' "$module" "$(stat -c '%s' "$backup_dir/preexisting-files.tar")"
    else
        printf 'No pre-existing Qt %s paths; no package backup was needed.\n' "$module"
    fi

    if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin \
        QT6DIR=/opt/qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig LC_ALL=POSIX MAKEFLAGS=-j6 \
        /bin/bash -s -- "$build_root" "$package_log_inside" "$module" <<'INSTALL'
set -Eeuo pipefail
build_root="$1"; package_log="$2"; module="$3"
exec > >(tee -a "$package_log") 2>&1
cmake --install "$build_root"
ldconfig
case "$module" in
    qtshadertools)
        [[ -f /opt/qt6/lib/libQt6ShaderTools.so.6 && -x /opt/qt6/bin/qsb ]]
        ;;
    qtdeclarative)
        [[ -f /opt/qt6/lib/libQt6Qml.so.6 && -f /opt/qt6/lib/libQt6Quick.so.6 && -x /opt/qt6/bin/qml ]]
        ;;
    qtwayland)
        [[ -f /opt/qt6/lib/libQt6WaylandClient.so.6 ]]
        [[ -f /opt/qt6/plugins/platforms/libqwayland-egl.so ]]
        ;;
    *) exit 2 ;;
esac
printf 'QT_MODULE_FINAL_INSTALL=PASS\n'
INSTALL
    then
        if sudo -n test -f "$LFS$package_log_inside"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"; fi
        printf 'QT_MODULE_RESULT=FAIL_FINAL_INSTALL\nLOG=%s\n' "$package_log" > "$package_status"
        fail "Qt $module final install or verification failed; see $package_log"
    fi
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"
    printf 'QT_MODULE_RESULT=PASS\nLOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$package_log" "$LFS$work_root" "$backup_dir" > "$package_status"
    printf 'Qt %s %s built and installed. Log: %s\n' "$module" "$VERSION" "$package_log"
}

build_module qtshadertools
build_module qtdeclarative
build_module qtwayland

printf '\nQt ShaderTools/QML/Wayland module set installed; no package tests or smoke runs executed.\n'
printf 'Host log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
