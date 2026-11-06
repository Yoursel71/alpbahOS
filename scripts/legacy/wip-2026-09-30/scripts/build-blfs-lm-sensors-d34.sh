#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=3-6-2 ARCHIVE=lm-sensors-3-6-2.tar.gz
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-lm-sensors-$STAMP" LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/lm-sensors-$VERSION-d34-$STAMP.log" BACKUP="$DATA/backups/lm-sensors-$VERSION-d34-$STAMP"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"; lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo unavailable.'
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
python3 - "$ALPBAHOS_D34_PACKAGE" "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/plasma-d34-package-order.json" <<'PY'
import json,sys
if sys.argv[1] not in json.load(open(sys.argv[2],encoding='utf-8')): raise SystemExit('lm-sensors absent from approved D34 order')
PY
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"; lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=lm-sensors\nVERSION=%s\nLOG=%s\n' "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=lm-sensors exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$LOG.status"; fi; }; trap record_result EXIT
sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/lm-sensors-3-6-2"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -f "$source/Makefile" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp PATH=/usr/bin:/usr/sbin:/bin:/sbin SENSOR_SOURCE='$source' SENSOR_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED'
set -Eeuo pipefail
cd "$SENSOR_SOURCE"
make -j8 PREFIX=/usr LIBDIR=/usr/lib MANDIR=/usr/share/man > "$SENSOR_SOURCE/build.log" 2>&1 || { tail -n 140 "$SENSOR_SOURCE/build.log"; exit 1; }
mkdir -p "$SENSOR_STAGE"
make DESTDIR="$SENSOR_STAGE" PREFIX=/usr LIBDIR=/usr/lib MANDIR=/usr/share/man install > "$SENSOR_SOURCE/install.log" 2>&1 || { tail -n 140 "$SENSOR_SOURCE/install.log"; exit 1; }
test -x "$SENSOR_STAGE/usr/bin/sensors"; test -s "$SENSOR_STAGE/usr/include/sensors/sensors.h"; test -e "$SENSOR_STAGE/usr/lib/libsensors.so"
UNPRIVILEGED
chown -R 0:0 "$stage"
BUILD
sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" "$ALPBAHOS_D34_CANDIDATE_PATH" <<'MANIFEST'
import json,os,sys
root,src,dst,candidate=sys.argv[1:]; ledger=json.load(open(os.path.join(os.path.dirname(candidate),'d34-ownership-ledger.json'),encoding='utf-8'))
if ledger.get('result')!='COMPLETE': raise SystemExit('incomplete ownership ledger')
owners=ledger.get('final_system_path_owners',{}); paths=[p for p in open(src,'rb').read().split(b'\0') if p]; old=[]
for raw in paths:
 rel=os.fsdecode(raw)
 if os.path.isabs(rel) or '..' in rel.split('/'): raise SystemExit(f'unsafe path {rel}')
 if os.path.lexists(os.path.join(root,rel)):
  if owners.get(rel)!='lm-sensors': raise SystemExit(f'refusing overwrite of {rel}: owner={owners.get(rel)!r}')
  old.append(raw)
open(dst,'wb').write(b''.join(p+b'\0' for p in old)); print(f'lm-sensors overlay {len(paths)} staged paths, {len(old)} prior-owned collisions')
MANIFEST
if [[ -s "$BACKUP/existing.list0" ]]; then sudo -n tar -cf "$BACKUP/preexisting-lm-sensors-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null -T "$BACKUP/existing.list0"; sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-lm-sensors-files.tar"; fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash -s -- "$WORK/stage" <<'INSTALL'
set -Eeuo pipefail; cp -a "$1"/. /; ldconfig; test -x /usr/bin/sensors; test -s /usr/include/sensors/sensors.h; test -e /usr/lib/libsensors.so
INSTALL
printf 'D34_RESULT=PASS PACKAGE=lm-sensors VERSION=%s LOG=%s\n' "$VERSION" "$LOG"
