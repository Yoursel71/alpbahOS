#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=1.1.43
readonly ARCHIVE="libxslt-$VERSION.tar.xz"
readonly URL="https://download.gnome.org/sources/libxslt/1.1/$ARCHIVE"
readonly WORK_ROOT="/sources/libxslt-$VERSION-blfs-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/libxslt-$VERSION"
readonly STAGE_ROOT="$WORK_ROOT/stage"
readonly PACKAGE_LOG_INSIDE="$WORK_ROOT/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/libxslt-$VERSION-blfs-$STAMP.log"
readonly STATUS="$LOG_DIR/libxslt-$VERSION-blfs-$STAMP.status"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.part-$STAMP"
readonly BACKUP_DIR="$DATA/backups/libxslt-before-final-$STAMP"
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
        printf 'BLFS_LIBXSLT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_LIBXSLT_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building BLFS 12.4 libxslt %s for the KDE Frameworks dependency chain.\n' "$VERSION"
printf 'Package test suites and source checksum calculations are skipped per user preference.\n'
printf 'Target: %s\nStarted: %s\n' "$LFS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

if [[ ! -r "$ARCHIVE_PATH" ]]; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
    rm -f "$TEMP_DOWNLOAD"
else
    printf 'Using existing source archive: %s\n' "$ARCHIVE_PATH"
fi
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite existing isolated build tree $WORK_ROOT"
mkdir -p "$BACKUP_DIR"

if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK_ROOT" "$SOURCE_ROOT" "$STAGE_ROOT" "$PACKAGE_LOG_INSIDE" <<'CHROOT'
set -Eeuo pipefail
archive="$1"; work_root="$2"; source_root="$3"; stage_root="$4"; package_log="$5"
mkdir -pv "$work_root"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work_root"
[[ -x "$source_root/configure" ]] || { printf 'libxslt configure script missing.\n' >&2; exit 1; }
cd "$source_root"
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/libxslt-1.1.43 > "$work_root/configure.log" 2>&1
if make -j4 > "$work_root/compile.log" 2>&1; then
    printf 'LIBXSLT_BUILD=PASS\n'
else
    result=$?; tail -n 120 "$work_root/compile.log"; exit "$result"
fi
mkdir -pv "$stage_root"
make -j1 DESTDIR="$stage_root" install > "$work_root/staged-install.log" 2>&1
[[ -x "$stage_root/usr/bin/xsltproc" && -f "$stage_root/usr/lib/libxslt.so" && -f "$stage_root/usr/lib/libexslt.so" ]]
printf 'LIBXSLT_STAGED_INSTALL=PASS\n'
CHROOT
then
    if sudo -n test -f "$LFS$PACKAGE_LOG_INSIDE"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG_DIR/libxslt-$VERSION-blfs-$STAMP.package.log"; fi
    fail "libxslt build or staged install failed; see $LOG"
fi
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG_DIR/libxslt-$VERSION-blfs-$STAMP.package.log"

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
        raise SystemExit(f"Unsafe staged path: {relative!r}")
    if os.path.lexists(os.path.join(root, relative)):
        existing.append(raw)
with open(existing_path, "wb") as stream:
    for raw in sorted(set(existing)):
        stream.write(raw + b"\0")
print(f"Staged paths: {len(staged)}; pre-existing targets: {len(set(existing))}")
PY
if [[ -s "$EXISTING0" ]]; then
    sudo -n tar --create --file="$BACKUP_DIR/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$EXISTING0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_DIR/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP_DIR/preexisting-files.tar" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'Pre-install backup archive is empty.'
else
    printf 'No pre-existing libxslt paths required backup.\n' > "$BACKUP_DIR/no-preexisting-files.txt"
fi

if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$SOURCE_ROOT" "$PACKAGE_LOG_INSIDE" <<'INSTALL'
set -Eeuo pipefail
source_root="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cd "$source_root"
make -j1 install
ldconfig
[[ "$(pkg-config --modversion libxslt)" == 1.1.43 ]]
[[ "$(pkg-config --modversion libexslt)" == 0.8.24 ]]
[[ "$(xslt-config --version)" == 1.1.43 ]]
[[ -x /usr/bin/xsltproc && -d /usr/include/libxslt && -d /usr/include/libexslt ]]
[[ -f /usr/lib/libxslt.so && -f /usr/lib/libexslt.so && -d /usr/share/doc/libxslt-1.1.43 ]]
printf 'LIBXSLT_FINAL_INSTALL=PASS\n'
INSTALL
then
    fail "libxslt final install or static verification failed; see $LOG"
fi
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG_DIR/libxslt-$VERSION-blfs-$STAMP.package.log"
printf 'BLFS_LIBXSLT_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' \
    "$LOG" "$LOG_DIR/libxslt-$VERSION-blfs-$STAMP.package.log" "$LFS$WORK_ROOT" "$BACKUP_DIR" > "$LOG_DIR/libxslt-$VERSION-blfs-$STAMP.package.status"
printf '\nlibxslt build/install completed; no package tests or checksum calculations ran.\n'
printf 'Log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
