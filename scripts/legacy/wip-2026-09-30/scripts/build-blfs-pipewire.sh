#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly VERSION=1.4.7
readonly ARCHIVE="pipewire-$VERSION.tar.bz2"
readonly URL="https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/$VERSION/$ARCHIVE"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/pipewire-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/pipewire-$VERSION"
readonly BUILD="$WORK/build"
readonly STAGE="$WORK/stage"
readonly PACKAGE_LOG="$WORK/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/pipewire-$VERSION-$STAMP.log"
readonly STATUS="$LOG_DIR/pipewire-$VERSION-$STAMP.status"
readonly BACKUP="$DATA/backups/pipewire-$VERSION-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.partial-$STAMP"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not ready.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "cmake" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/meson && -x /usr/bin/ninja && -e /usr/lib/libasound.so.2 && -e /usr/lib/libsndfile.so.1 && ! -e /usr/lib/libpipewire-0.3.so ]]' || fail 'Meson/Ninja/ALSA/libsndfile prerequisite is missing or PipeWire already exists.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'PIPEWIRE_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'PIPEWIRE_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

printf 'BLFS 12.4 PipeWire %s; ALSA and libsndfile enabled, X11 and tests disabled, no bundled session manager, checksum calculation skipped.\nSource: %s\n' "$VERSION" "$URL"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
else printf 'Using retained source archive: %s\n' "$ARCHIVE_PATH"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$BUILD" "$STAGE" "$PACKAGE_LOG" <<'PIPEWIRE_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; build="$4"; stage="$5"; package_log="$6"
[[ "$(id nobody)" == 'uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)' ]]
[[ ! -e "$work" ]] || { printf 'Refusing to overwrite prior work tree: %s\n' "$work" >&2; exit 1; }
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/meson.build" && -f "$source/meson_options.txt" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin PIPEWIRE_SOURCE='$source' PIPEWIRE_BUILD='$build' PIPEWIRE_STAGE='$stage' PIPEWIRE_WORK='$work' /bin/bash -s" <<'UNPRIVILEGED_BUILD'
set -Eeuo pipefail
meson setup "$PIPEWIRE_BUILD" "$PIPEWIRE_SOURCE" \
    --prefix=/usr \
    --buildtype=release \
    -D session-managers='[]' \
    -D flatpak=disabled \
    -D tests=disabled \
    -D x11=disabled \
    -D x11-xfixes=disabled \
    -D alsa=enabled \
    -D sndfile=enabled \
    -D pw-cat=enabled \
    -D docs=disabled \
    -D man=disabled \
    > "$PIPEWIRE_WORK/configure.log" 2>&1 || { tail -n 220 "$PIPEWIRE_WORK/configure.log"; exit 1; }
ninja -C "$PIPEWIRE_BUILD" > "$PIPEWIRE_WORK/compile.log" 2>&1 || { tail -n 220 "$PIPEWIRE_WORK/compile.log"; exit 1; }
mkdir -pv "$PIPEWIRE_STAGE"
DESTDIR="$PIPEWIRE_STAGE" ninja -C "$PIPEWIRE_BUILD" install > "$PIPEWIRE_WORK/staged-install.log" 2>&1 || { tail -n 180 "$PIPEWIRE_WORK/staged-install.log"; exit 1; }
for program in pipewire pw-cli pw-cat pw-play pw-record; do [[ -x "$PIPEWIRE_STAGE/usr/bin/$program" || -L "$PIPEWIRE_STAGE/usr/bin/$program" ]]; done
[[ -e "$PIPEWIRE_STAGE/usr/lib/libpipewire-0.3.so" ]]
[[ -d "$PIPEWIRE_STAGE/usr/lib/spa-0.2" ]]
UNPRIVILEGED_BUILD
chown -R 0:0 "$stage"
printf 'PIPEWIRE_STAGE=PASS\n'
PIPEWIRE_BUILD_STAGE

sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/pipewire-$VERSION-$STAMP.package.log"
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
    [[ -s "$BACKUP/archive.list" ]] || fail 'PipeWire pre-install backup is empty.'
else printf 'No existing PipeWire targets required an archive.\n' > "$BACKUP/no-preexisting-files.txt"; fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$BUILD" "$PACKAGE_LOG" <<'PIPEWIRE_FINAL_INSTALL'
set -Eeuo pipefail
build="$1"; package_log="$2"
exec >> "$package_log" 2>&1
ninja -C "$build" install
ldconfig
[[ -x /usr/bin/pipewire && -e /usr/bin/pw-cli && -e /usr/bin/pw-cat && -e /usr/bin/pw-play && -e /usr/bin/pw-record ]]
[[ -e /usr/lib/libpipewire-0.3.so && -d /usr/lib/spa-0.2 ]]
[[ "$(pkg-config --modversion libpipewire-0.3)" == 1.4.7 ]]
[[ -f /usr/lib/systemd/user/pipewire.service && -f /usr/lib/systemd/user/pipewire.socket ]]
for library in /usr/lib/libpipewire-0.3.so; do
    ldd_output="$(ldd "$library")"
    printf '%s\n' "$ldd_output"
    [[ "$ldd_output" != *'not found'* && "$ldd_output" != *'/sources/'* ]]
done
printf 'PIPEWIRE_FINAL_INSTALL=PASS\n'
PIPEWIRE_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG" "$LOG_DIR/pipewire-$VERSION-$STAMP.package.log"
printf 'PIPEWIRE_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LOG_DIR/pipewire-$VERSION-$STAMP.package.log" "$LFS$WORK" "$BACKUP" > "$LOG_DIR/pipewire-$VERSION-$STAMP.package.status"
printf 'PipeWire %s installed; ALSA/libsndfile and pw-cat are built, X11 and tests were disabled, no service was enabled. Runtime audio was not tested.\nLog: %s\nStatus: %s\n' "$VERSION" "$LOG" "$STATUS"
