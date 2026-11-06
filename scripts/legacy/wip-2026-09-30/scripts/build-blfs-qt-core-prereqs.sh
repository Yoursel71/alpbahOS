#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qt-core-prereqs-$STAMP.log"
readonly STATUS="$LOG_DIR/qt-core-prereqs-$STAMP.status"

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
        printf 'BLFS_QT_CORE_PREREQUISITES_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_QT_CORE_PREREQUISITES_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building BLFS 12.4 Qt core prerequisites: PCRE2 10.45 and SQLite 3.50.4.\n'
printf 'Unicode/JIT/16/32-bit PCRE2, FTS4/5 and SQLite metadata features enabled. Package tests/checksum work skipped.\n'
printf 'Started: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

build_package() {
    local name="$1" version="$2" archive="$3" url="$4" source_dir="$5" recipe="$6"
    local work_root="/sources/${name}-${version}-blfs-$STAMP"
    local source_root="$work_root/$source_dir"
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
        curl --fail --location --retry 3 --output "$temp_download" "$url"
        sudo -n install -o 0 -g 0 -m 0644 "$temp_download" "$archive_path"
        rm -f "$temp_download"
    else
        printf 'Using existing source archive: %s\n' "$archive_path"
    fi
    [[ ! -e "$LFS$work_root" ]] || fail "Refusing to overwrite isolated tree $work_root"
    mkdir -p "$backup_dir"

    if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
        /bin/bash -s -- "$archive" "$work_root" "$source_root" "$stage_root" "$package_log_inside" "$recipe" <<'CHROOT'
set -Eeuo pipefail
archive="$1"; work_root="$2"; source_root="$3"; stage_root="$4"; package_log="$5"; recipe="$6"
mkdir -pv "$work_root"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work_root"
[[ -d "$source_root" ]] || { printf 'Expected source tree missing: %s\n' "$source_root" >&2; exit 1; }
cd "$source_root"
case "$recipe" in
    pcre2)
        ./configure --prefix=/usr --docdir=/usr/share/doc/pcre2-10.45 \
            --enable-unicode --enable-jit --enable-pcre2-16 --enable-pcre2-32 \
            --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-pcre2test-libreadline \
            --disable-static > "$work_root/configure.log" 2>&1
        ;;
    sqlite)
        CPPFLAGS='-D SQLITE_ENABLE_COLUMN_METADATA=1 -D SQLITE_ENABLE_UNLOCK_NOTIFY=1 -D SQLITE_ENABLE_DBSTAT_VTAB=1 -D SQLITE_SECURE_DELETE=1' \
            ./configure --prefix=/usr --disable-static --enable-fts4 --enable-fts5 \
            > "$work_root/configure.log" 2>&1
        ;;
    *) printf 'Unknown package recipe: %s\n' "$recipe" >&2; exit 2 ;;
esac
if make -j4 > "$work_root/compile.log" 2>&1; then
    printf '%s_BUILD=PASS\n' "$(tr '[:lower:]' '[:upper:]' <<< "$recipe" | tr '-' '_')"
else
    result=$?; tail -n 140 "$work_root/compile.log"; exit "$result"
fi
mkdir -pv "$stage_root"
make -j1 DESTDIR="$stage_root" install > "$work_root/staged-install.log" 2>&1
[[ -d "$stage_root/usr" ]] || { printf 'Staged install is empty.\n' >&2; exit 1; }
printf 'STAGED_INSTALL=PASS\n'
CHROOT
    then
        if sudo -n test -f "$LFS$package_log_inside"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"; fi
        printf '%s_RESULT=FAIL_BUILD_OR_STAGE\nLOG=%s\n' "$name" "$package_log" > "$package_status"
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
        [[ -s "$backup_dir/archive.list" ]] || fail "$name pre-install backup is empty"
        printf 'Existing target backup: %s bytes\n' "$(stat -c '%s' "$backup_dir/preexisting-files.tar")"
    else
        printf 'No pre-existing package files; no target backup was needed.\n'
    fi

    if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
        /bin/bash -s -- "$source_root" "$package_log_inside" "$recipe" <<'INSTALL'
set -Eeuo pipefail
source_root="$1"; package_log="$2"; recipe="$3"
exec > >(tee -a "$package_log") 2>&1
cd "$source_root"
make -j1 install
case "$recipe" in
    pcre2)
        ldconfig
        [[ "$(pkg-config --modversion libpcre2-8)" == 10.45 ]]
        [[ -f /usr/lib/libpcre2-8.so.0 && -f /usr/lib/libpcre2-16.so.0 && -f /usr/lib/libpcre2-32.so.0 ]]
        [[ -d /usr/share/doc/pcre2-10.45 ]]
        ;;
    sqlite)
        ldconfig
        [[ "$(sqlite3 --version | awk '{print $1}')" == 3.50.4 ]]
        [[ "$(pkg-config --modversion sqlite3)" == 3.50.4 ]]
        [[ -f /usr/lib/libsqlite3.so && -f /usr/include/sqlite3.h ]]
        ;;
    *) exit 2 ;;
esac
printf 'PACKAGE_FINAL_INSTALL=PASS\n'
INSTALL
    then
        if sudo -n test -f "$LFS$package_log_inside"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"; fi
        printf '%s_RESULT=FAIL_FINAL_INSTALL\nLOG=%s\n' "$name" "$package_log" > "$package_status"
        fail "$name final install or verification failed; see $package_log"
    fi
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log_inside" "$package_log"
    printf 'PACKAGE_RESULT=PASS\nLOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$package_log" "$LFS$work_root" "$backup_dir" > "$package_status"
    printf 'Installed and verified %s %s. Log: %s\n' "$name" "$version" "$package_log"
}

build_package pcre2 10.45 pcre2-10.45.tar.bz2 \
    https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.bz2 pcre2-10.45 pcre2
build_package sqlite 3.50.4 sqlite-autoconf-3500400.tar.gz \
    https://www.sqlite.org/2025/sqlite-autoconf-3500400.tar.gz sqlite-autoconf-3500400 sqlite

printf '%s\n' '' 'PCRE2 and SQLite prerequisites installed; package tests/checksum work skipped.'
printf 'Host log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
