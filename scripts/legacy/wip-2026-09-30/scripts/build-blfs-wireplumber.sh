#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=0.5.10
readonly ARCHIVE="wireplumber-$VERSION.tar.bz2"
readonly URL="https://gitlab.freedesktop.org/pipewire/wireplumber/-/archive/$VERSION/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/wireplumber-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/wireplumber-$VERSION"
readonly BUILD="$WORK/build"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/wireplumber-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/wireplumber-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/wireplumber-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/meson && -x /usr/bin/ninja && -e /usr/lib/libpipewire-0.3.so && -e /usr/lib/liblua.so.5.4.8 && -e /usr/lib/libglib-2.0.so && ! -e /usr/lib/libwireplumber-0.5.so ]]' || fail 'Meson/PipeWire/Lua/GLib prerequisites are missing or WirePlumber already exists.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'WIREPLUMBER_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'WIREPLUMBER_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'BLFS 12.4 WirePlumber %s; system Lua 5.4, tests/docs disabled, no service enable/start, checksum calculation skipped.\nSource: %s\n' "$VERSION" "$URL"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" "$PACKAGE_LOG" <<'WIREPLUMBER_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; package_log="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/meson.build" && -f "$source/meson_options.txt" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin WIREPLUMBER_SOURCE='$source' WIREPLUMBER_BUILD='$build' WIREPLUMBER_STAGE='$stage' WIREPLUMBER_WORK='$work' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
meson setup "$WIREPLUMBER_BUILD" "$WIREPLUMBER_SOURCE" \
    --prefix=/usr \
    --buildtype=release \
    -D system-lua=true \
    -D systemd=enabled \
    -D systemd-user-service=true \
    -D systemd-system-service=false \
    -D tests=false \
    -D dbus-tests=false \
    -D doc=disabled \
    > "$WIREPLUMBER_WORK/configure.log" 2>&1 || { tail -n 180 "$WIREPLUMBER_WORK/configure.log"; exit 1; }
meson configure "$WIREPLUMBER_BUILD" > "$WIREPLUMBER_WORK/meson-options.txt"
grep -Eq '^[[:space:]]+system-lua[[:space:]]+true([[:space:]]|$)' "$WIREPLUMBER_WORK/meson-options.txt"
grep -Eq '^[[:space:]]+tests[[:space:]]+false([[:space:]]|$)' "$WIREPLUMBER_WORK/meson-options.txt"
ninja -C "$WIREPLUMBER_BUILD" > "$WIREPLUMBER_WORK/compile.log" 2>&1 || { tail -n 200 "$WIREPLUMBER_WORK/compile.log"; exit 1; }
mkdir -pv "$WIREPLUMBER_STAGE"
DESTDIR="$WIREPLUMBER_STAGE" ninja -C "$WIREPLUMBER_BUILD" install > "$WIREPLUMBER_WORK/staged-install.log" 2>&1 || { tail -n 180 "$WIREPLUMBER_WORK/staged-install.log"; exit 1; }
for program in wireplumber wpctl wpexec; do [[ -x "$WIREPLUMBER_STAGE/usr/bin/$program" ]]; done
[[ -e "$WIREPLUMBER_STAGE/usr/lib/libwireplumber-0.5.so" ]]
[[ -d "$WIREPLUMBER_STAGE/usr/lib/wireplumber-0.5" && -d "$WIREPLUMBER_STAGE/usr/share/wireplumber" ]]
[[ -f "$WIREPLUMBER_STAGE/usr/lib/systemd/user/wireplumber.service" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
printf 'WIREPLUMBER_STAGE=PASS\n'
WIREPLUMBER_BUILD_STAGE

sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/wireplumber-$VERSION-$STAMP.package.log"
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged-paths.list0"
python3 - "$LFS" "$BACKUP/staged-paths.list0" "$BACKUP/preexisting-paths.list0" <<'PY'
import os, sys
root, staged, out = sys.argv[1:]
with open(staged, 'rb') as stream: paths = [p for p in stream.read().split(b'\0') if p]
old = []
for raw in paths:
    rel = os.fsdecode(raw)
    if os.path.isabs(rel) or '..' in rel.split('/'): raise SystemExit(f'Unsafe path: {rel!r}')
    if os.path.lexists(os.path.join(root, rel)): old.append(raw)
with open(out, 'wb') as stream:
    for raw in sorted(set(old)): stream.write(raw + b'\0')
print(f'Staged paths: {len(paths)}; existing target paths: {len(set(old))}')
PY
if [[ -s "$BACKUP/preexisting-paths.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/preexisting-paths.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
    [[ -s "$BACKUP/archive.list" ]] || fail 'WirePlumber pre-install backup is empty.'
else printf 'No existing WirePlumber targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$BUILD" "$PACKAGE_LOG" <<'WIREPLUMBER_FINAL_INSTALL'
set -Eeuo pipefail
build="$1"; package_log="$2"
exec >> "$package_log" 2>&1
ninja -C "$build" install
ldconfig
for program in wireplumber wpctl wpexec; do [[ -x "/usr/bin/$program" ]]; done
[[ -e /usr/lib/libwireplumber-0.5.so ]]
[[ -d /usr/lib/wireplumber-0.5 && -d /usr/share/wireplumber ]]
[[ -f /usr/lib/systemd/user/wireplumber.service ]]
output="$(ldd /usr/lib/libwireplumber-0.5.so)"
printf '%s\n' "$output"
[[ "$output" != *'not found'* && "$output" != *'/sources/'* ]]
printf 'WIREPLUMBER_FINAL_INSTALL=PASS\n'
WIREPLUMBER_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/wireplumber-$VERSION-$STAMP.package.log"
printf 'WIREPLUMBER_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LOG_DIR/wireplumber-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/wireplumber-$VERSION-$STAMP.package.status"
printf 'WirePlumber %s installed with system Lua and user unit; tests/docs disabled, no service enabled or started. Runtime audio is not verified.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
