#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/mesa-prereqs-$STAMP.log"
readonly STATUS="$LOG_DIR/mesa-prereqs-$STAMP.status"

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
        printf 'BLFS_MESA_PREREQUISITES_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_MESA_PREREQUISITES_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building Mesa 25.1.8 prerequisites: libyaml, Cython, Mako, PyYAML, Wayland Protocols.\n'
printf 'The package test suites and source checksum calculations are skipped per user preference.\n'
printf 'Started: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

build_package() {
    local name="$1" version="$2" archive="$3" url="$4" recipe="$5" source_dir="$6" pip_name="${7:-}"
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
        /bin/bash -s -- "$archive" "$work_root" "$source_root" "$build_root" "$stage_root" "$recipe" "$package_log_inside" "$pip_name" <<'CHROOT'
set -Eeuo pipefail
archive="$1"; work_root="$2"; source_root="$3"; build_root="$4"; stage_root="$5"; recipe="$6"; package_log="$7"; pip_name="$8"
mkdir -pv "$work_root"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work_root"
[[ -d "$source_root" ]] || { printf 'Expected source directory missing: %s\n' "$source_root" >&2; exit 1; }
case "$recipe" in
    libyaml)
        cd "$source_root"
        ./configure --prefix=/usr --disable-static > "$work_root/configure.log" 2>&1
        if make -j4 > "$work_root/compile.log" 2>&1; then printf 'LIBYAML_BUILD=PASS\n'; else result=$?; tail -n 100 "$work_root/compile.log"; exit "$result"; fi
        mkdir -pv "$stage_root"
        make -j1 DESTDIR="$stage_root" install > "$work_root/staged-install.log" 2>&1
        ;;
    python-wheel)
        cd "$source_root"
        mkdir -pv dist
        python3 -m pip wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$source_root" > "$work_root/wheel.log" 2>&1
        mkdir -pv "$stage_root"
        python3 -m pip install --root="$stage_root" --no-index --find-links="$source_root/dist" --no-user --no-deps --ignore-installed "$pip_name" > "$work_root/staged-install.log" 2>&1
        ;;
    wayland-protocols)
        mkdir -pv "$build_root"
        meson setup "$build_root" "$source_root" --prefix=/usr --buildtype=release > "$work_root/configure.log" 2>&1
        if ninja -C "$build_root" -j4 > "$work_root/compile.log" 2>&1; then printf 'WAYLAND_PROTOCOLS_BUILD=PASS\n'; else result=$?; tail -n 100 "$work_root/compile.log"; exit "$result"; fi
        mkdir -pv "$stage_root"
        DESTDIR="$stage_root" ninja -C "$build_root" install > "$work_root/staged-install.log" 2>&1
        ;;
    *) printf 'Unknown build recipe: %s\n' "$recipe" >&2; exit 2 ;;
esac
[[ -d "$stage_root/usr" ]] || { printf 'Staged install is empty.\n' >&2; exit 1; }
printf 'STAGED_INSTALL=PASS\n'
CHROOT
    then
        if sudo -n test -f "$LFS$package_log_inside"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"; fi
        printf '%s_RESULT=FAIL_BUILD_OR_STAGE\nLOG=%s\n' "$(tr '[:lower:]' '[:upper:]' <<< "$name" | tr '-' '_')" "$package_log" > "$package_status"
        fail "$name build or staged install failed; see $package_log"
    fi
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"

    sudo -n find "$LFS$stage_root" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$staged0"
    python3 - "$LFS" "$staged0" "$existing0" <<'PY'
import os, sys
root, staged_path, existing_path = sys.argv[1:]
with open(staged_path, "rb") as stream: staged = [p for p in stream.read().split(b"\0") if p]
existing = []
for raw in staged:
    relative = os.fsdecode(raw)
    if os.path.isabs(relative) or ".." in relative.split("/"): raise SystemExit(f"Unsafe staged path: {relative!r}")
    if os.path.lexists(os.path.join(root, relative)): existing.append(raw)
with open(existing_path, "wb") as stream:
    for raw in sorted(set(existing)): stream.write(raw + b"\0")
print(f"Staged files/symlinks: {len(staged)}; pre-existing target paths: {len(set(existing))}")
PY
    if [[ -s "$existing0" ]]; then
        sudo -n tar --create --file="$backup_dir/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$existing0"
        sudo -n chown "$(id -u):$(id -g)" "$backup_dir/preexisting-files.tar"
        sudo -n tar --list --file="$backup_dir/preexisting-files.tar" > "$backup_dir/archive.list"
        [[ -s "$backup_dir/archive.list" ]] || fail "Pre-install backup is empty for $name"
        printf 'Existing target backup: %s bytes\n' "$(stat -c '%s' "$backup_dir/preexisting-files.tar")"
    else
        printf 'No pre-existing package files; no target backup was needed.\n'
    fi

    if ! sudo -n chroot "$LFS" /usr/bin/env -i \
        HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
        /bin/bash -s -- "$source_root" "$build_root" "$recipe" "$package_log_inside" "$pip_name" <<'INSTALL'
set -Eeuo pipefail
source_root="$1"; build_root="$2"; recipe="$3"; package_log="$4"; pip_name="$5"
exec > >(tee -a "$package_log") 2>&1
case "$recipe" in
    libyaml)
        cd "$source_root"; make -j1 install; ldconfig
        [[ -f /usr/lib/libyaml.so && -f /usr/include/yaml.h ]]
        ;;
    python-wheel)
        cd "$source_root"
        python3 -m pip install --no-index --find-links="$source_root/dist" --no-user --no-deps --force-reinstall "$pip_name"
        case "$pip_name" in
            Cython) python3 -c 'import Cython, importlib.metadata as m; assert m.version("Cython") == "3.1.3"; print("Cython", Cython.__version__)'; command -v cython >/dev/null ;;
            Mako) python3 -c 'import mako, importlib.metadata as m; assert m.version("Mako") == "1.3.10"; print("Mako", mako.__version__)'; command -v mako-render >/dev/null ;;
            PyYAML) python3 -c 'import yaml, importlib.metadata as m; assert m.version("PyYAML") == "6.0.2"; print("PyYAML", yaml.__version__)'; python3 -c 'import yaml._yaml; print("PyYAML C extension", yaml._yaml.__file__)' ;;
            *) exit 2 ;;
        esac
        ;;
    wayland-protocols)
        ninja -C "$build_root" install
        [[ -d /usr/share/wayland-protocols/stable && -f /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml ]]
        ;;
    *) exit 2 ;;
esac
printf 'PACKAGE_FINAL_INSTALL=PASS\n'
INSTALL
    then
        if sudo -n test -f "$LFS$package_log_inside"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"; fi
        printf '%s_RESULT=FAIL_FINAL_INSTALL\nLOG=%s\n' "$(tr '[:lower:]' '[:upper:]' <<< "$name" | tr '-' '_')" "$package_log" > "$package_status"
        fail "$name final install or verification failed; see $package_log"
    fi
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"
    printf '%s_RESULT=PASS\nLOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$(tr '[:lower:]' '[:upper:]' <<< "$name" | tr '-' '_')" "$package_log" "$LFS$work_root" "$backup_dir" > "$package_status"
    printf 'Installed and verified %s %s. Log: %s\n' "$name" "$version" "$package_log"
}

build_package libyaml 0.2.5 yaml-0.2.5.tar.gz https://github.com/yaml/libyaml/releases/download/0.2.5/yaml-0.2.5.tar.gz libyaml yaml-0.2.5
build_package Cython 3.1.3 cython-3.1.3.tar.gz https://github.com/cython/cython/releases/download/3.1.3/cython-3.1.3.tar.gz python-wheel cython-3.1.3 Cython
build_package Mako 1.3.10 mako-1.3.10.tar.gz https://files.pythonhosted.org/packages/source/M/Mako/mako-1.3.10.tar.gz python-wheel mako-1.3.10 Mako
build_package PyYAML 6.0.2 pyyaml-6.0.2.tar.gz https://files.pythonhosted.org/packages/source/P/PyYAML/pyyaml-6.0.2.tar.gz python-wheel pyyaml-6.0.2 PyYAML
build_package wayland-protocols 1.45 wayland-protocols-1.45.tar.xz https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.45/downloads/wayland-protocols-1.45.tar.xz wayland-protocols wayland-protocols-1.45

printf '\nMesa prerequisites installed and verified; no package test suites or checksum verification ran.\n'
printf 'Host log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
