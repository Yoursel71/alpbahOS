#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/font-stack-$STAMP.log"
readonly STATUS="$LOG_DIR/font-stack-$STAMP.status"

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
        printf 'BLFS_FONT_STACK_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_FONT_STACK_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building BLFS 12.4 font runtime: FreeType 2.13.3, HarfBuzz 11.4.1, FreeType integration, Fontconfig 2.17.1.\n'
printf 'The order follows the BLFS circular dependency recipe. Package tests and checksum calculations are skipped.\n'
printf 'No patent-related subpixel-rendering override is applied.\n'
printf 'Started: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

build_package() {
    local name="$1" version="$2" archive="$3" url="$4" source_dir="$5" variant="$6"
    local work_root="/sources/${name}-${version}-${variant}-blfs-$STAMP"
    local source_root="$work_root/$source_dir"
    local build_root="$work_root/build"
    local stage_root="$work_root/stage"
    local package_log_inside="$work_root/package.log"
    local package_log="$LOG_DIR/${name}-${version}-${variant}-blfs-$STAMP.log"
    local package_status="$LOG_DIR/${name}-${version}-${variant}-blfs-$STAMP.status"
    local backup_dir="$DATA/backups/${name}-${variant}-before-final-$STAMP"
    local archive_path="$LFS/sources/$archive"
    local temp_download="$DATA/downloads/$archive.part-$STAMP"
    local staged0="$backup_dir/staged-paths.list0"
    local existing0="$backup_dir/preexisting-paths.list0"

    printf '\n=== %s %s (%s) ===\n' "$name" "$version" "$variant"
    if [[ ! -r "$archive_path" ]]; then
        curl --fail --location --retry 3 --output "$temp_download" "$url"
        sudo -n install -o 0 -g 0 -m 0644 "$temp_download" "$archive_path"
        rm -f "$temp_download"
    else
        printf 'Using existing source archive: %s\n' "$archive_path"
    fi
    [[ ! -e "$LFS$work_root" ]] || fail "Refusing to overwrite isolated package tree $work_root"
    mkdir -p "$backup_dir"

    if ! sudo -n chroot "$LFS" /usr/bin/env -i \
        HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j6 \
        /bin/bash -s -- "$archive" "$work_root" "$source_root" "$build_root" "$stage_root" "$package_log_inside" "$name" "$variant" <<'CHROOT'
set -Eeuo pipefail
archive="$1"; work_root="$2"; source_root="$3"; build_root="$4"; stage_root="$5"; package_log="$6"; name="$7"; variant="$8"
mkdir -pv "$work_root"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work_root"
[[ -d "$source_root" ]] || { printf 'Expected source tree missing: %s\n' "$source_root" >&2; exit 1; }

case "$name:$variant" in
    freetype:bootstrap|freetype:integrated)
        cd "$source_root"
        sed -ri 's:.*(AUX_MODULES.*valid):\1:' modules.cfg
        configure_args=(--prefix=/usr --enable-freetype-config --disable-static)
        [[ "$variant" != bootstrap ]] || configure_args+=(--without-harfbuzz)
        if ./configure "${configure_args[@]}" > "$work_root/configure.log" 2>&1; then
            printf 'FREETYPE_CONFIGURE=PASS\n'
        else
            result=$?; tail -n 120 "$work_root/configure.log"; exit "$result"
        fi
        if make -j6 > "$work_root/compile.log" 2>&1; then
            printf 'FREETYPE_BUILD=PASS\n'
        else
            result=$?; tail -n 140 "$work_root/compile.log"; exit "$result"
        fi
        mkdir -pv "$stage_root"
        make DESTDIR="$stage_root" install > "$work_root/staged-install.log" 2>&1
        [[ -f "$stage_root/usr/lib/libfreetype.so" && -x "$stage_root/usr/bin/freetype-config" ]]
        ;;
    harfbuzz:main)
        mkdir -pv "$build_root"
        meson setup "$build_root" "$source_root" --prefix=/usr --buildtype=release \
            -D graphite2=disabled -D docs=disabled -D tests=disabled -D utilities=disabled > "$work_root/configure.log" 2>&1 || {
                result=$?; tail -n 120 "$work_root/configure.log"; exit "$result";
            }
        if ninja -C "$build_root" -j6 > "$work_root/compile.log" 2>&1; then
            printf 'HARFBUZZ_BUILD=PASS\n'
        else
            result=$?; tail -n 140 "$work_root/compile.log"; exit "$result"
        fi
        mkdir -pv "$stage_root"
        DESTDIR="$stage_root" ninja -C "$build_root" install > "$work_root/staged-install.log" 2>&1
        [[ -f "$stage_root/usr/lib/libharfbuzz.so" && -f "$stage_root/usr/lib/pkgconfig/harfbuzz.pc" ]]
        ;;
    fontconfig:main)
        cd "$source_root"
        if ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
            --disable-docs --docdir=/usr/share/doc/fontconfig-2.17.1 \
            > "$work_root/configure.log" 2>&1; then
            printf 'FONTCONFIG_CONFIGURE=PASS\n'
        else
            result=$?; tail -n 120 "$work_root/configure.log"; exit "$result"
        fi
        if make -j6 > "$work_root/compile.log" 2>&1; then
            printf 'FONTCONFIG_BUILD=PASS\n'
        else
            result=$?; tail -n 140 "$work_root/compile.log"; exit "$result"
        fi
        mkdir -pv "$stage_root"
        make DESTDIR="$stage_root" install > "$work_root/staged-install.log" 2>&1
        [[ -f "$stage_root/usr/lib/libfontconfig.so" && -x "$stage_root/usr/bin/fc-cache" ]]
        ;;
    *) printf 'Unknown font package recipe: %s (%s)\n' "$name" "$variant" >&2; exit 2 ;;
esac
printf 'STAGED_INSTALL=PASS\n'
CHROOT
    then
        if sudo -n test -f "$LFS$package_log_inside"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"; fi
        printf 'FONT_PACKAGE_RESULT=FAIL_BUILD_OR_STAGE\nLOG=%s\n' "$package_log" > "$package_status"
        fail "$name $variant build or staged install failed; see $package_log"
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
print(f"Staged paths: {len(staged)}; pre-existing target paths: {len(set(existing))}")
PY
    if [[ -s "$existing0" ]]; then
        sudo -n tar --create --file="$backup_dir/preexisting-files.tar" --numeric-owner --acls --xattrs \
            -C "$LFS" --null --files-from="$existing0"
        sudo -n chown "$(id -u):$(id -g)" "$backup_dir/preexisting-files.tar"
        sudo -n tar --list --file="$backup_dir/preexisting-files.tar" > "$backup_dir/archive.list"
        [[ -s "$backup_dir/archive.list" ]] || fail "Pre-install backup is empty for $name $variant"
        printf 'Existing target backup: %s bytes\n' "$(stat -c '%s' "$backup_dir/preexisting-files.tar")"
    else
        printf 'No pre-existing package paths; no backup was needed.\n'
    fi

    if ! sudo -n chroot "$LFS" /usr/bin/env -i \
        HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j6 \
        /bin/bash -s -- "$source_root" "$build_root" "$package_log_inside" "$name" "$variant" <<'INSTALL'
set -Eeuo pipefail
source_root="$1"; build_root="$2"; package_log="$3"; name="$4"; variant="$5"
exec > >(tee -a "$package_log") 2>&1
case "$name:$variant" in
    freetype:bootstrap|freetype:integrated)
        cd "$source_root"
        make -j1 install
        ldconfig
        [[ -f /usr/lib/libfreetype.so && -x /usr/bin/freetype-config ]]
        freetype-config --ftversion
        ;;
    harfbuzz:main)
        ninja -C "$build_root" install
        ldconfig
        [[ "$(pkg-config --modversion harfbuzz)" == 11.4.1 ]]
        [[ -f /usr/lib/libharfbuzz.so && -f /usr/include/harfbuzz/hb.h ]]
        ;;
    fontconfig:main)
        cd "$source_root"
        make -j1 install
        ldconfig
        [[ "$(pkg-config --modversion fontconfig)" == 2.17.1 ]]
        [[ -f /usr/lib/libfontconfig.so && -x /usr/bin/fc-cache && -r /etc/fonts/fonts.conf ]]
        fc-cache --version
        ;;
    *) printf 'Unknown final verification package: %s (%s)\n' "$name" "$variant" >&2; exit 2 ;;
esac
printf 'FONT_PACKAGE_FINAL_INSTALL=PASS\n'
INSTALL
    then
        if sudo -n test -f "$LFS$package_log_inside"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"; fi
        printf 'FONT_PACKAGE_RESULT=FAIL_FINAL_INSTALL\nLOG=%s\n' "$package_log" > "$package_status"
        fail "$name $variant final install or verification failed; see $package_log"
    fi
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"
    printf 'FONT_PACKAGE_RESULT=PASS\nLOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' \
        "$package_log" "$LFS$work_root" "$backup_dir" > "$package_status"
    printf 'Installed %s %s (%s). Log: %s\n' "$name" "$version" "$variant" "$package_log"
}

if sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin /bin/bash -ec \
    '[[ "$(freetype-config --ftversion)" == 2.13.3 && -f /usr/lib/libfreetype.so ]]'; then
    printf 'Reusing the already installed FreeType 2.13.3 bootstrap package.\n'
else
    build_package freetype 2.13.3 freetype-2.13.3.tar.xz \
        https://downloads.sourceforge.net/freetype/freetype-2.13.3.tar.xz freetype-2.13.3 bootstrap
fi
build_package harfbuzz 11.4.1 harfbuzz-11.4.1.tar.xz \
    https://github.com/harfbuzz/harfbuzz/releases/download/11.4.1/harfbuzz-11.4.1.tar.xz harfbuzz-11.4.1 main
build_package freetype 2.13.3 freetype-2.13.3.tar.xz \
    https://downloads.sourceforge.net/freetype/freetype-2.13.3.tar.xz freetype-2.13.3 integrated
build_package fontconfig 2.17.1 fontconfig-2.17.1.tar.xz \
    https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.17.1/fontconfig-2.17.1.tar.xz fontconfig-2.17.1 main

printf '\nFreeType/HarfBuzz/Fontconfig installed and version-checked. No package tests or checksum calculations were run.\n'
printf 'Host log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
