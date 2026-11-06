#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=0.9.33
readonly ARCHIVE="lmdb-$VERSION.tar.bz2"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-lmdb-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/lmdb-d34-$STAMP.log"
readonly BACKUP="$DATA/backups/lmdb-d34-$STAMP"
readonly SOURCE="$WORK/openldap-LMDB_0.9.33-3a29a24777c82a0165de813ae696a5068b5add30/libraries/liblmdb"

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo unavailable.'
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=lmdb\nVERSION=%s\nLOG=%s\n' "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=lmdb exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT

sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"
source="$work/openldap-LMDB_0.9.33-3a29a24777c82a0165de813ae696a5068b5add30/libraries/liblmdb"
stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"
tar -xjf "/sources/$archive" -C "$work"
[[ -f "$source/Makefile" && -f "$source/lmdb.h" ]]
cd "$source"
make -j8 > "$work/compile.log" 2>&1 || { tail -n 100 "$work/compile.log"; exit 1; }
# BLFS deliberately omits the static archive from installation.
sed -i 's| liblmdb.a||' Makefile
mkdir -p "$stage/usr"
make -j1 prefix="$stage/usr" install > "$work/staged-install.log" 2>&1 || { tail -n 100 "$work/staged-install.log"; exit 1; }
[[ -x "$stage/usr/bin/mdb_copy" && -x "$stage/usr/bin/mdb_dump" \
   && -f "$stage/usr/lib/liblmdb.so" && -f "$stage/usr/include/lmdb.h" ]]
[[ ! -e "$stage/usr/lib/liblmdb.a" ]]
BUILD

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
print(f'LMDB staged paths={len(paths)} existing targets={len(existing)}')
if existing:
    raise SystemExit(f'Refusing existing LMDB targets: {existing[:12]!r}')
MANIFEST

sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
  /bin/bash -s -- "$WORK/stage" <<'INSTALL'
set -Eeuo pipefail
stage="$1"
cp -a "$stage"/. /
ldconfig
[[ -f /usr/lib/liblmdb.so && -f /usr/include/lmdb.h ]]
[[ -x /usr/bin/mdb_copy && -x /usr/bin/mdb_dump && -x /usr/bin/mdb_load && -x /usr/bin/mdb_stat ]]
[[ ! -e /usr/lib/liblmdb.a ]]
INSTALL
printf 'D34_RESULT=PASS PACKAGE=lmdb VERSION=%s LOG=%s\n' "$VERSION" "$LOG"
