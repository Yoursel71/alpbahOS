#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=2.7.0
readonly ARCHIVE="duktape-$VERSION.tar.xz"
readonly URL="https://duktape.org/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/duktape-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/duktape-$VERSION"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/duktape-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/duktape-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/duktape-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'DUKTAPE_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'DUKTAPE_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

printf 'BLFS 12.4 Duktape %s source/build/install; no test suite or checksum calculation.\n' "$VERSION"
printf 'Source: %s\nStarted: %s\n' "$URL" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else
    printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$STAGE" "$PACKAGE_LOG" <<'DUKTAPE_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"; package_log="$5"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior build tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/Makefile.sharedlibrary" && -f "$source/src/duktape.c" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX DUKTAPE_SOURCE='$source' DUKTAPE_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
cd "$DUKTAPE_SOURCE"
sed -i 's/-Os/-O2/' Makefile.sharedlibrary
make -j4 -f Makefile.sharedlibrary INSTALL_PREFIX=/usr > "$DUKTAPE_SOURCE/compile.log" 2>&1 || {
    tail -n 100 "$DUKTAPE_SOURCE/compile.log"; exit 1;
}
mkdir -pv "$DUKTAPE_STAGE"
DESTDIR="$DUKTAPE_STAGE" make -f Makefile.sharedlibrary INSTALL_PREFIX=/usr install > "$DUKTAPE_SOURCE/staged-install.log" 2>&1 || {
    tail -n 100 "$DUKTAPE_SOURCE/staged-install.log"; exit 1;
}
[[ -f "$DUKTAPE_STAGE/usr/lib/libduktape.so" && -f "$DUKTAPE_STAGE/usr/include/duktape.h" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
[[ -n "$(find "$stage" \( -type f -o -type l \) -print -quit)" ]]
printf 'DUKTAPE_STAGE=PASS\n'
DUKTAPE_BUILD_STAGE
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/duktape-$VERSION-$STAMP.package.log"

sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged-paths.list0"
python3 - "$LFS" "$BACKUP/staged-paths.list0" "$BACKUP/preexisting-paths.list0" <<'PY'
import os, sys
root, staged_path, existing_path = sys.argv[1:]
with open(staged_path, 'rb') as stream:
    staged = [p for p in stream.read().split(b'\0') if p]
existing = []
for raw in staged:
    rel = os.fsdecode(raw)
    if os.path.isabs(rel) or '..' in rel.split('/'):
        raise SystemExit(f'Unsafe staged path: {rel!r}')
    if os.path.lexists(os.path.join(root, rel)):
        existing.append(raw)
with open(existing_path, 'wb') as stream:
    for raw in sorted(set(existing)):
        stream.write(raw + b'\0')
print(f'Staged paths: {len(staged)}; existing target paths: {len(set(existing))}')
PY
if [[ -s "$BACKUP/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
    [[ -s "$BACKUP/archive.list" ]] || fail 'The Duktape pre-install backup is empty.'
else
    printf 'No existing Duktape package targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$SOURCE" "$PACKAGE_LOG" <<'DUKTAPE_FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cd "$source"
make -j1 -f Makefile.sharedlibrary INSTALL_PREFIX=/usr install
ldconfig
[[ -f /usr/lib/libduktape.so && -f /usr/lib/libduktaped.so ]]
[[ -f /usr/include/duktape.h && -f /usr/lib/pkgconfig/duktape.pc ]]
[[ "$(pkg-config --modversion duktape)" == 2.7.0 ]]
printf 'DUKTAPE_FINAL_INSTALL=PASS\n'
DUKTAPE_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/duktape-$VERSION-$STAMP.package.log"
printf 'DUKTAPE_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' \
    "$LOG" "$LOG_DIR/duktape-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/duktape-$VERSION-$STAMP.package.status"
printf 'Duktape %s installed; test suites and checksum calculations were skipped.\n' "$VERSION"
printf 'Log: %s\nStatus: %s\nFinished: %s\n' "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
