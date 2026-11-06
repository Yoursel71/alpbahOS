#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/setuptools-80.9.0-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/setuptools-80.9.0"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/setuptools-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/setuptools-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/setuptools-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/setuptools-before-files.tar"
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
[[ -r "$LFS/sources/setuptools-80.9.0.tar.gz" ]] || fail 'The Setuptools 80.9.0 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Setuptools work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Setuptools 80.9.0.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work. Pip is restricted to the locally built wheel; no online index will be used.\n'

(
    cd "$LFS"
    for path in usr/lib/python3.13/site-packages/_distutils_hack \
        usr/lib/python3.13/site-packages/pkg_resources \
        usr/lib/python3.13/site-packages/setuptools \
        usr/lib/python3.13/site-packages/setuptools-80.9.0.dist-info; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Setuptools backup archive is empty.'
    printf 'Existing Setuptools-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Setuptools files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
fi
printf 'Pre-existing path count: %s\n' "$(wc -l < "$MANIFEST")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WORK_ROOT" "$SOURCE_ROOT" "$CHROOT_LOG" <<'CHROOT'
set -Eeuo pipefail
work_root="$1"
source_root="$2"
build_log="$3"
mkdir -pv "$work_root"
exec > >(tee "$build_log") 2>&1

tar -xzf /sources/setuptools-80.9.0.tar.gz -C "$work_root"
[[ -f "$source_root/pyproject.toml" ]] || { printf 'Setuptools pyproject.toml is missing.\n' >&2; exit 1; }
cd "$source_root"
/usr/bin/pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps "$PWD"
/usr/bin/pip3 install --no-index --find-links dist setuptools

/usr/bin/python3 -c 'import importlib.metadata as m, setuptools; print("Setuptools", m.version("setuptools")); print(setuptools.__file__)'
for path in /usr/lib/python3.13/site-packages/_distutils_hack \
    /usr/lib/python3.13/site-packages/pkg_resources \
    /usr/lib/python3.13/site-packages/setuptools \
    /usr/lib/python3.13/site-packages/setuptools-80.9.0.dist-info; do
    [[ -d "$path" ]] || { printf 'Missing installed Setuptools path: %s\n' "$path" >&2; exit 1; }
done
printf 'SETUPTOOLS_FINAL_INSTALL=PASS\nSETUPTOOLS_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nSetuptools Chapter 8 build/install completed from a local wheel.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
