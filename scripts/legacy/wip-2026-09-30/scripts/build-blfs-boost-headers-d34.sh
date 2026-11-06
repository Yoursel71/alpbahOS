#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly PACKAGE=boost-headers VERSION=1.89.0
readonly ARCHIVE=boost-1.89.0-b2-nodocs.tar.xz
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-$PACKAGE-$VERSION-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/$PACKAGE-$VERSION-d34-$STAMP.log"
readonly BACKUP="$DATA/backups/$PACKAGE-$VERSION-d34-$STAMP"

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the D34 candidate.'
python3 - "$PACKAGE" "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/plasma-d34-package-order.json" <<'PY'
import json,sys
if sys.argv[1] not in json.load(open(sys.argv[2], encoding="utf-8")):
    raise SystemExit("package is not in the approved Plasma D34 order")
PY
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo unavailable.'
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT

sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
  /bin/bash -s -- "$ARCHIVE" "$WORK" <<'STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/boost-1.89.0"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/boost/version.hpp" ]]
grep -Fq '#define BOOST_LIB_VERSION "1_89"' "$source/boost/version.hpp"
mkdir -p "$stage/usr/include"
cp -a "$source/boost" "$stage/usr/include/boost"
[[ -s "$stage/usr/include/boost/version.hpp" ]]
STAGE

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'MANIFEST'
import os,sys
root,src,dst=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
existing=[]
for path in paths:
    rel=os.fsdecode(path)
    if os.path.isabs(rel) or '..' in rel.split('/'):
        raise SystemExit(f'unsafe staged path: {rel}')
    if os.path.lexists(os.path.join(root,rel)):
        existing.append(path)
open(dst,'wb').write(b''.join(path+b'\0' for path in existing))
print(f'boost-headers: {len(paths)} staged paths; {len(existing)} existing')
if existing:
    raise SystemExit(f'Refusing existing Boost header targets: {existing[:12]!r}')
MANIFEST

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
  /bin/bash -s -- "$WORK/stage" <<'INSTALL'
set -Eeuo pipefail
cp -a "$1"/. /
[[ -f /usr/include/boost/version.hpp ]]
grep -Fq '#define BOOST_LIB_VERSION "1_89"' /usr/include/boost/version.hpp
INSTALL
printf 'D34_RESULT=PASS PACKAGE=%s VERSION=%s LOG=%s\n' "$PACKAGE" "$VERSION" "$LOG"
