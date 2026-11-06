#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly SOURCES="$LFS/sources"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/wayland-base-$STAMP.log"
readonly STATUS="$LOG_DIR/wayland-base-$STAMP.status"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

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
        printf 'BLFS_WAYLAND_BASE_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_WAYLAND_BASE_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Build the BLFS 12.4 Wayland graphics base: libxml2 2.14.5, libpciaccess 0.18.1, libdrm 2.4.125, Wayland 1.24.0.\n'
printf 'Target: %s\nStarted: %s\n' "$LFS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Source checksums and package test suites are intentionally skipped per user preference.\n\n'

build_package() {
    local name="$1" version="$2" archive="$3" url="$4" recipe="$5"
    local package_stamp="${STAMP}"
    local work_root="/sources/${name}-${version}-blfs-${package_stamp}"
    local source_root="$work_root/${name}-${version}"
    local build_root="$source_root/build"
    local stage_root="$work_root/stage"
    local package_log_inside="$work_root/package.log"
    local package_log="$LOG_DIR/${name}-${version}-blfs-${package_stamp}.log"
    local status_file="$LOG_DIR/${name}-${version}-blfs-${package_stamp}.status"
    local backup_dir="$DATA/backups/${name}-before-final-${package_stamp}"
    local archive_path="$SOURCES/$archive"
    local temp_download="$DATA/downloads/$archive.part-$STAMP"
    local staged0="$backup_dir/staged-paths.list0"
    local existing0="$backup_dir/preexisting-paths.list0"
    local existing_txt="$backup_dir/preexisting-paths.list"
    local backup_tar="$backup_dir/preexisting-files.tar"

    printf '\n=== %s %s ===\n' "$name" "$version"
    if [[ ! -r "$archive_path" ]]; then
        printf 'Downloading official source: %s\n' "$url"
        curl --fail --location --retry 3 --output "$temp_download" "$url"
        sudo -n install -o 0 -g 0 -m 0644 "$temp_download" "$archive_path"
        rm -f "$temp_download"
    else
        printf 'Using existing source archive: %s\n' "$archive_path"
    fi
    [[ ! -e "$LFS$work_root" ]] || fail "Refusing to overwrite existing isolated build tree $work_root"
    mkdir -p "$backup_dir"

    if ! sudo -n chroot "$LFS" /usr/bin/env -i \
        HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
        /bin/bash -s -- "$archive" "$work_root" "$source_root" "$build_root" "$stage_root" "$recipe" "$package_log_inside" <<'CHROOT'
set -Eeuo pipefail
archive="$1"
work_root="$2"
source_root="$3"
build_root="$4"
stage_root="$5"
recipe="$6"
package_log="$7"
mkdir -pv "$work_root"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work_root"
[[ -d "$source_root" ]] || { printf 'Expected source directory missing: %s\n' "$source_root" >&2; exit 1; }
case "$recipe" in
    libxml2)
        cd "$source_root"
        ./configure --prefix=/usr \
            --sysconfdir=/etc \
            --disable-static \
            --with-history \
            PYTHON=/usr/bin/python3 \
            --docdir=/usr/share/doc/libxml2-2.14.5 > "$work_root/configure.log" 2>&1
        if make -j4 > "$work_root/compile.log" 2>&1; then
            printf 'LIBXML2_BUILD=PASS\n'
        else
            result=$?
            tail -n 120 "$work_root/compile.log"
            exit "$result"
        fi
        mkdir -pv "$stage_root"
        make -j1 DESTDIR="$stage_root" install > "$work_root/staged-install.log" 2>&1
        ;;
    libdrm)
        mkdir -pv "$build_root"
        cd "$build_root"
        meson setup .. --prefix=/usr --buildtype=release -D udev=true -D valgrind=disabled -D intel=enabled \
            > "$work_root/configure.log" 2>&1
        if ninja -j4 > "$work_root/compile.log" 2>&1; then
            printf 'LIBDRM_BUILD=PASS\n'
        else
            result=$?
            tail -n 120 "$work_root/compile.log"
            exit "$result"
        fi
        mkdir -pv "$stage_root"
        DESTDIR="$stage_root" ninja install > "$work_root/staged-install.log" 2>&1
        ;;
    libpciaccess)
        mkdir -pv "$build_root"
        cd "$build_root"
        meson setup .. --prefix=/usr --buildtype=release > "$work_root/configure.log" 2>&1
        if ninja -j4 > "$work_root/compile.log" 2>&1; then
            printf 'LIBPCIACCESS_BUILD=PASS\n'
        else
            result=$?
            tail -n 120 "$work_root/compile.log"
            exit "$result"
        fi
        mkdir -pv "$stage_root"
        DESTDIR="$stage_root" ninja install > "$work_root/staged-install.log" 2>&1
        ;;
    wayland)
        mkdir -pv "$build_root"
        cd "$build_root"
        meson setup .. --prefix=/usr --buildtype=release -D documentation=false \
            > "$work_root/configure.log" 2>&1
        if ninja -j4 > "$work_root/compile.log" 2>&1; then
            printf 'WAYLAND_BUILD=PASS\n'
        else
            result=$?
            tail -n 120 "$work_root/compile.log"
            exit "$result"
        fi
        mkdir -pv "$stage_root"
        DESTDIR="$stage_root" ninja install > "$work_root/staged-install.log" 2>&1
        ;;
    *)
        printf 'Unknown package recipe: %s\n' "$recipe" >&2
        exit 2
        ;;
esac
[[ -d "$stage_root/usr" ]] || { printf 'Staged install is empty.\n' >&2; exit 1; }
printf 'STAGED_INSTALL=PASS\n'
CHROOT
    then
        if sudo -n test -f "$LFS$package_log_inside"; then
            sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"
        fi
        printf '%s_RESULT=FAIL\nLOG=%s\n' "$(tr '[:lower:]' '[:upper:]' <<< "$name" | tr '-' '_')" "$package_log" > "$status_file"
        fail "$name build or staged install failed; see $package_log"
    fi
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"

    sudo -n find "$LFS$stage_root" \( -type f -o -type l \) -printf '%P\0' \
        | sort -zu > "$staged0"
    python3 - "$LFS" "$staged0" "$existing0" <<'PY'
import os
import sys

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
print(f"Staged files/symlinks: {len(staged)}; pre-existing target paths: {len(set(existing))}")
PY
    tr '\0' '\n' < "$existing0" > "$existing_txt"
    if [[ -s "$existing0" ]]; then
        sudo -n tar --create --file="$backup_tar" --numeric-owner --acls --xattrs \
            -C "$LFS" --null --files-from="$existing0"
        sudo -n chown "$(id -u):$(id -g)" "$backup_tar"
        sudo -n tar --list --file="$backup_tar" > "$backup_dir/archive.list"
        [[ -s "$backup_dir/archive.list" ]] || fail "Pre-install backup is empty for $name"
        printf 'Existing target backup: %s bytes\n' "$(stat -c '%s' "$backup_tar")"
    else
        printf 'No pre-existing package files; no target backup was needed.\n'
    fi

    if ! sudo -n chroot "$LFS" /usr/bin/env -i \
        HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
        /bin/bash -s -- "$build_root" "$source_root" "$recipe" "$package_log_inside" <<'INSTALL'
set -Eeuo pipefail
build_root="$1"
source_root="$2"
recipe="$3"
package_log="$4"
exec > >(tee -a "$package_log") 2>&1
case "$recipe" in
    libxml2)
        cd "$source_root"
        make -j1 install
        rm -f /usr/lib/libxml2.la
        sed '/libs=/s/xml2.*/xml2"/' -i /usr/bin/xml2-config
        ldconfig
        [[ "$(xml2-config --version)" == 2.14.5 ]]
        [[ "$(pkg-config --modversion libxml-2.0)" == 2.14.5 ]]
        xmllint --version 2>&1 | grep -F 'using libxml version 21405'
        [[ -x /usr/bin/xmlcatalog && -d /usr/include/libxml2/libxml ]]
        [[ -f /usr/lib/libxml2.so && -d /usr/share/doc/libxml2-2.14.5 ]]
        ;;
    libpciaccess)
        cd "$build_root"
        ninja install
        ldconfig
        [[ "$(pkg-config --modversion pciaccess)" == 0.18.1 ]]
        [[ -f /usr/lib/libpciaccess.so ]]
        [[ -f /usr/include/pciaccess.h || -f /usr/include/pciaccess/pciaccess.h ]]
        ;;
    libdrm)
        cd "$build_root"
        ninja install
        ldconfig
        [[ "$(pkg-config --modversion libdrm)" == 2.4.125 ]]
        [[ -f /usr/lib/libdrm.so && -d /usr/include/libdrm ]]
        for library in libdrm_amdgpu.so libdrm_intel.so libdrm_nouveau.so libdrm_radeon.so; do
            [[ -f "/usr/lib/$library" ]] || { printf 'Missing libdrm library: %s\n' "$library" >&2; exit 1; }
        done
        ;;
    wayland)
        cd "$build_root"
        ninja install
        ldconfig
        [[ "$(pkg-config --modversion wayland-client)" == 1.24.0 ]]
        wayland-scanner --version 2>&1 | grep -F '1.24.0'
        for library in libwayland-client.so libwayland-cursor.so libwayland-egl.so libwayland-server.so; do
            [[ -f "/usr/lib/$library" ]] || { printf 'Missing Wayland library: %s\n' "$library" >&2; exit 1; }
        done
        [[ -d /usr/share/wayland && -f /usr/include/wayland-client-protocol.h ]]
        ;;
    *) exit 2 ;;
esac
printf 'PACKAGE_FINAL_INSTALL=PASS\n'
INSTALL
    then
        if sudo -n test -f "$LFS$package_log_inside"; then
            sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"
        fi
        printf '%s_RESULT=FAIL_FINAL_INSTALL\nLOG=%s\n' "$(tr '[:lower:]' '[:upper:]' <<< "$name" | tr '-' '_')" "$package_log" > "$status_file"
        fail "$name final install or verification failed; see $package_log"
    fi

    printf '%s_RESULT=PASS\nLOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' \
        "$(tr '[:lower:]' '[:upper:]' <<< "$name" | tr '-' '_')" "$package_log" "$LFS$work_root" "$backup_dir" > "$status_file"
    printf 'Installed and verified %s %s. Log: %s\n' "$name" "$version" "$package_log"
}

build_package libxml2 2.14.5 libxml2-2.14.5.tar.xz \
    https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.5.tar.xz libxml2
build_package libpciaccess 0.18.1 libpciaccess-0.18.1.tar.xz \
    https://www.x.org/pub/individual/lib/libpciaccess-0.18.1.tar.xz libpciaccess
build_package libdrm 2.4.125 libdrm-2.4.125.tar.xz \
    https://dri.freedesktop.org/libdrm/libdrm-2.4.125.tar.xz libdrm
build_package wayland 1.24.0 wayland-1.24.0.tar.xz \
    https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.24.0/downloads/wayland-1.24.0.tar.xz wayland

printf '\nThe Wayland graphics base build/install completed without package test suites or checksum verification.\n'
printf 'Host log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
