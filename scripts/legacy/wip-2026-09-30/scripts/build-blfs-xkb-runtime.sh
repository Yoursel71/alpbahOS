#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/xkb-runtime-$STAMP.log"
readonly STATUS="$LOG_DIR/xkb-runtime-$STAMP.status"

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
        printf 'BLFS_XKB_RUNTIME_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_XKB_RUNTIME_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building the Wayland keyboard runtime: XKeyboardConfig 2.45, then libxkbcommon 1.11.0.\n'
printf 'The build omits Xorg server/client libraries, optional documentation, package tests, and checksum calculations.\n'
printf 'Started: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

build_package() {
    local name="$1" version="$2" archive="$3" url="$4" source_dir="$5"
    local work_root="/sources/${name}-${version}-blfs-$STAMP"
    local source_root="$work_root/$source_dir"
    local build_root="$source_root/build"
    local stage_root="$work_root/stage"
    local package_log_inside="$work_root/package.log"
    local package_log="$LOG_DIR/${name}-${version}-blfs-$STAMP.log"
    local package_status="$LOG_DIR/${name}-${version}-blfs-$STAMP.status"
    local backup_dir="$DATA/backups/${name}-before-final-$STAMP"
    local archive_path="$LFS/sources/$archive"
    local temp_download="$DATA/downloads/$archive.part-$STAMP"
    local staged0="$backup_dir/staged-paths.list0"
    local existing0="$backup_dir/preexisting-paths.list0"

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
        /bin/bash -s -- "$archive" "$work_root" "$source_root" "$build_root" "$stage_root" "$package_log_inside" <<'CHROOT'
set -Eeuo pipefail
archive="$1"; work_root="$2"; source_root="$3"; build_root="$4"; stage_root="$5"; package_log="$6"
mkdir -pv "$work_root"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work_root"
[[ -d "$source_root" ]] || { printf 'Expected source tree missing: %s\n' "$source_root" >&2; exit 1; }
mkdir -pv "$build_root"
case "$source_root" in
    */xkeyboard-config-2.45)
        meson setup "$build_root" "$source_root" --prefix=/usr --buildtype=release > "$work_root/configure.log" 2>&1
        ;;
    */libxkbcommon-1.11.0)
        meson setup "$build_root" "$source_root" --prefix=/usr --buildtype=release \
            -D enable-docs=false -D enable-x11=false > "$work_root/configure.log" 2>&1
        ;;
    *) printf 'Unknown Meson recipe tree: %s\n' "$source_root" >&2; exit 2 ;;
esac
if ninja -C "$build_root" -j4 > "$work_root/compile.log" 2>&1; then
    printf 'PACKAGE_BUILD=PASS\n'
else
    result=$?
    tail -n 120 "$work_root/compile.log"
    exit "$result"
fi
mkdir -pv "$stage_root"
DESTDIR="$stage_root" ninja -C "$build_root" install > "$work_root/staged-install.log" 2>&1
[[ -d "$stage_root/usr" ]] || { printf 'Staged install is empty.\n' >&2; exit 1; }
printf 'STAGED_INSTALL=PASS\n'
CHROOT
    then
        if sudo -n test -f "$LFS$package_log_inside"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"; fi
        printf 'PACKAGE_RESULT=FAIL_BUILD_OR_STAGE\nLOG=%s\n' "$package_log" > "$package_status"
        fail "$name build or staged install failed; see $package_log"
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
        raise SystemExit(f"Unsafe staged path: {relative!r}")
    if os.path.lexists(os.path.join(root, relative)):
        existing.append(raw)
with open(existing_path, "wb") as stream:
    for raw in sorted(set(existing)):
        stream.write(raw + b"\0")
print(f"Staged files/symlinks: {len(staged)}; pre-existing target paths: {len(set(existing))}")
PY
    if [[ -s "$existing0" ]]; then
        sudo -n tar --create --file="$backup_dir/preexisting-files.tar" --numeric-owner --acls --xattrs \
            -C "$LFS" --null --files-from="$existing0"
        sudo -n chown "$(id -u):$(id -g)" "$backup_dir/preexisting-files.tar"
        sudo -n tar --list --file="$backup_dir/preexisting-files.tar" > "$backup_dir/archive.list"
        [[ -s "$backup_dir/archive.list" ]] || fail "Pre-install backup is empty for $name"
        printf 'Existing target backup: %s bytes\n' "$(stat -c '%s' "$backup_dir/preexisting-files.tar")"
    else
        printf 'No pre-existing package files; no target backup was needed.\n'
    fi

    if ! sudo -n chroot "$LFS" /usr/bin/env -i \
        HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
        /bin/bash -s -- "$source_root" "$build_root" "$package_log_inside" <<'INSTALL'
set -Eeuo pipefail
source_root="$1"; build_root="$2"; package_log="$3"
exec > >(tee -a "$package_log") 2>&1
ninja -C "$build_root" install
case "$source_root" in
    */xkeyboard-config-2.45)
        [[ -r /usr/share/X11/xkb/rules/evdev && -r /usr/share/X11/xkb/symbols/us && -r /usr/share/X11/xkb/symbols/tr ]]
        ;;
    */libxkbcommon-1.11.0)
        ldconfig
        [[ "$(pkg-config --modversion xkbcommon)" == 1.11.0 ]]
        command -v xkbcli >/dev/null
        xkbcli --version
        [[ -f /usr/lib/libxkbcommon.so.0 && -d /usr/include/xkbcommon ]]
        ;;
    *) printf 'Unknown final verification tree: %s\n' "$source_root" >&2; exit 2 ;;
esac
printf 'PACKAGE_FINAL_INSTALL=PASS\n'
INSTALL
    then
        if sudo -n test -f "$LFS$package_log_inside"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"; fi
        printf 'PACKAGE_RESULT=FAIL_FINAL_INSTALL\nLOG=%s\n' "$package_log" > "$package_status"
        fail "$name final install or verification failed; see $package_log"
    fi
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"
    printf 'PACKAGE_RESULT=PASS\nLOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$package_log" "$LFS$work_root" "$backup_dir" > "$package_status"
    printf 'Installed and verified %s %s. Log: %s\n' "$name" "$version" "$package_log"
}

build_package xkeyboard-config 2.45 xkeyboard-config-2.45.tar.xz \
    https://www.x.org/pub/individual/data/xkeyboard-config/xkeyboard-config-2.45.tar.xz xkeyboard-config-2.45
build_package libxkbcommon 1.11.0 libxkbcommon-1.11.0.tar.gz \
    https://github.com/lfs-book/libxkbcommon/archive/v1.11.0/libxkbcommon-1.11.0.tar.gz libxkbcommon-1.11.0

printf '\nWayland keyboard data/runtime installed and verified; Xorg, tests, and checksum work were skipped.\n'
printf 'Host log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
