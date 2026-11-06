#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly VERSION=3.1.3
readonly ARCHIVE="cython-$VERSION.tar.gz"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/cython-$VERSION-d34-$STAMP"
readonly SOURCE="$WORK/cython-$VERSION"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/cython-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/cython-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/cython-$VERSION-d34-$STAMP"
readonly URL="https://github.com/cython/cython/releases/download/$VERSION/$ARCHIVE"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular user.'
[[ -d "$LFS" ]] || fail 'The D34 candidate is not mounted at /mnt/lfs.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -c '[[ -x /usr/bin/python3 && -x /usr/bin/pip3 && ! -d /usr/lib/python3.13/site-packages/Cython ]]'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another build process is active.'
fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() {
    local rc=$?
    if (( rc == 0 )); then printf 'CYTHON_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else printf 'CYTHON_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi
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

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/cython-3.1.3"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"
tar -xf "/sources/$archive" -C "$work"
mkdir -p "$source/dist"
python3 -m pip wheel -w "$source/dist" --no-build-isolation --no-deps --no-cache-dir "$source" > "$work/wheel.log" 2>&1
mkdir -p "$stage"
python3 -m pip install --root="$stage" --no-index --find-links="$source/dist" --no-user --no-deps --ignore-installed Cython > "$work/staged-install.log" 2>&1
find "$source/dist" -maxdepth 1 -type f -name 'cython-3.1.3-*.whl' | grep -q .
[[ -x "$stage/usr/bin/cython" ]]
BUILD

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os, sys
root, staged_path, existing_path = sys.argv[1:]
with open(staged_path, 'rb') as stream: paths = [p for p in stream.read().split(b'\0') if p]
existing = [p for p in paths if os.path.lexists(os.path.join(root, os.fsdecode(p)))]
with open(existing_path, 'wb') as stream:
    for p in existing: stream.write(p + b'\0')
print(f'Cython staged paths: {len(paths)}; existing target collisions: {len(existing)}')
if existing: raise SystemExit('Refusing to overwrite pre-existing candidate paths')
PY

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$SOURCE" <<'INSTALL'
set -Eeuo pipefail
source="$1"
python3 -m pip install --no-index --find-links="$source/dist" --no-user --no-deps --force-reinstall Cython
python3 -c 'import Cython, importlib.metadata as m; assert m.version("Cython") == "3.1.3"; print("Cython", Cython.__version__)'
command -v cython >/dev/null
cython --version
INSTALL
printf 'CYTHON_RESULT=PASS\nLOG=%s\nVERSION=%s\n' "$LOG" "$VERSION" > "$STATUS"
printf 'Cython %s installed in the D34 candidate. Log: %s\n' "$VERSION" "$LOG"
