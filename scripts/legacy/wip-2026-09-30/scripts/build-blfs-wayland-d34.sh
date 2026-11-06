#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly VERSION=1.24.0
readonly ARCHIVE="wayland-$VERSION.tar.xz"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/wayland-$VERSION-d34-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/wayland-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/wayland-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/wayland-$VERSION-d34-$STAMP"
readonly URL="https://gitlab.freedesktop.org/wayland/wayland/-/releases/$VERSION/downloads/$ARCHIVE"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular user.'
[[ -d "$LFS" ]] || fail 'The D34 candidate is not mounted at /mnt/lfs.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -c '[[ -x /usr/bin/meson && -x /usr/bin/ninja && -x /usr/bin/pkg-config && ! -e /usr/lib/pkgconfig/wayland-client.pc ]] && [[ "$(pkg-config --modversion libxml-2.0)" == 2.14.5 ]]' \
    || fail 'Meson/Ninja/libxml2 prerequisites are missing or Wayland is already installed.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another build process is active.'
fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'WAYLAND_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'WAYLAND_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
}
trap record_result EXIT

readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
    if [[ -r "$DATA/downloads/$ARCHIVE" ]]; then
        sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$ARCHIVE_PATH"
    else
        curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"
        sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"
        rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"
    fi
fi

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    LC_ALL=POSIX MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/wayland-1.24.0"; build="$source/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"
tar -xf "/sources/$archive" -C "$work"
meson setup "$build" "$source" --prefix=/usr --buildtype=release -D documentation=false
ninja -C "$build" -j8
mkdir -p "$stage"
DESTDIR="$stage" ninja -C "$build" install
test -s "$stage/usr/lib/pkgconfig/wayland-client.pc"
BUILD

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os, sys
root, staged_path, existing_path = sys.argv[1:]
with open(staged_path, 'rb') as stream: paths = [p for p in stream.read().split(b'\0') if p]
existing = [p for p in paths if os.path.lexists(os.path.join(root, os.fsdecode(p)))]
with open(existing_path, 'wb') as stream:
    for p in existing: stream.write(p + b'\0')
print(f'Wayland staged paths: {len(paths)}; existing target collisions: {len(existing)}')
if existing: raise SystemExit('Refusing to overwrite pre-existing candidate paths')
PY

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    LC_ALL=POSIX /bin/bash -s -- "$WORK" <<'INSTALL'
set -Eeuo pipefail
work="$1"; build="$work/wayland-1.24.0/build"
ninja -C "$build" install
ldconfig
[[ "$(pkg-config --modversion wayland-client)" == 1.24.0 ]]
[[ "$(pkg-config --modversion wayland-server)" == 1.24.0 ]]
[[ -s /usr/lib/libwayland-client.so && -s /usr/lib/libwayland-server.so ]]
[[ -x /usr/bin/wayland-scanner ]]
INSTALL
printf 'WAYLAND_RESULT=PASS\nLOG=%s\nVERSION=%s\n' "$LOG" "$VERSION" > "$STATUS"
printf 'Wayland %s installed in the D34 candidate. Log: %s\n' "$VERSION" "$LOG"
