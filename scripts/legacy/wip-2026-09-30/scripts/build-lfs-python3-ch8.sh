#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/python-3.13.7-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/Python-3.13.7"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/python3-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/python3-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/python3-pass2-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/python3-pass2-files.tar"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA" ]] || fail 'The LFS target or HDD build data directory is missing.'
if [[ -z "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    [[ -d "$DATA/lfs" ]] || fail 'The HDD-backed LFS build directory is missing.'
fi
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
[[ -r "$LFS/sources/Python-3.13.7.tar.xz" ]] || fail 'The Python 3.13.7 source archive is missing.'
[[ -r "$LFS/sources/python-3.13.7-docs-html.tar.bz2" ]] || fail 'The Python 3.13.7 HTML documentation archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Python work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Python 3.13.7.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archives without checksum work, as requested.\n'
printf 'The full Python make test suite is not being run. LFS --enable-optimizations invokes its focused PGO profiling workload during make.\n'

(
    cd "$LFS"
    for path in usr/lib/python3 usr/lib/python3.13 usr/include/python3.13 \
        usr/share/doc/python-3.13.7 usr/share/doc/python3.13 usr/share/info/dir; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    find usr/bin -maxdepth 1 \( -type f -o -type l \) \( \
        -name 'python3*' -o -name 'pip3*' -o -name 'pydoc3*' -o -name 'idle3*' -o -name '2to3*' \
    \) -print0 2>/dev/null || true
    find usr/lib -maxdepth 1 \( -type f -o -type l \) \( \
        -name 'libpython3.so*' -o -name 'libpython3.13.so*' \
        -o -name 'libpython3.a' -o -name 'libpython3.13.a' \
    \) -print0 2>/dev/null || true
    find usr/lib/pkgconfig -maxdepth 1 -type f -name 'python*.pc' -print0 2>/dev/null || true
    find usr/share/man -type f \( -name 'python3*' -o -name 'pip3*' -o -name 'pydoc3*' \
        -o -name 'idle3*' -o -name '2to3*' \) -print0 2>/dev/null || true
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Python Pass 2 backup archive is empty.'
    printf 'Existing Python-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Python-path files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
fi
printf 'Pre-existing top-level path count: %s\n' "$(wc -l < "$MANIFEST")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WORK_ROOT" "$SOURCE_ROOT" "$CHROOT_LOG" <<'CHROOT'
set -Eeuo pipefail
work_root="$1"
source_root="$2"
build_log="$3"
mkdir -pv "$work_root"
exec > >(tee "$build_log") 2>&1

tar -xf /sources/Python-3.13.7.tar.xz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'Python configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
./configure --prefix=/usr \
    --enable-shared \
    --with-system-expat \
    --enable-optimizations \
    --without-static-libpython > "$work_root/configure.log" 2>&1

if make -j4 > "$work_root/compile.log" 2>&1; then
    printf 'PYTHON_BUILD_RESULT=PASS\n'
else
    status=$?
    printf 'PYTHON_BUILD_RESULT=FAIL exit=%s\n' "$status"
    tail -n 100 "$work_root/compile.log"
    exit "$status"
fi

make -j1 install

install -v -dm755 /usr/share/doc/python-3.13.7/html
tar --strip-components=1 --no-same-owner --no-same-permissions \
    -C /usr/share/doc/python-3.13.7/html \
    -xf /sources/python-3.13.7-docs-html.tar.bz2

/usr/bin/python3 --version
/usr/bin/python3 -c 'import bz2, ctypes, lzma, ssl, sys, sysconfig, xml.parsers.expat, zlib; print("Python", sys.version.split()[0]); print("OpenSSL", ssl.OPENSSL_VERSION); print("Expat", xml.parsers.expat.EXPAT_VERSION); print("shared", sysconfig.get_config_var("Py_ENABLE_SHARED"))'
/usr/bin/python3 -m pip --version
[[ -x /usr/bin/python3 && -x /usr/bin/python3-config && -x /usr/bin/pip3 ]]
[[ -e /usr/lib/libpython3.13.so && -e /usr/lib/libpython3.so ]]
[[ -f /usr/include/python3.13/Python.h && -d /usr/lib/python3.13 ]]
[[ -d /usr/share/doc/python-3.13.7/html ]]
ldd /usr/bin/python3 | grep -E 'libpython3[.]13[.]so.*[/]usr/lib/'
printf 'PYTHON_FINAL_INSTALL=PASS\nPYTHON_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nPython Chapter 8 build/install completed; full test suite was not run.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
