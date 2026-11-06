#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=0.200.0 ARCHIVE=polkit-qt-1-0.200.0.tar.xz
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-polkit-qt-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/polkit-qt-$VERSION-d34-$STAMP.log"
readonly BACKUP="$DATA/backups/polkit-qt-$VERSION-d34-$STAMP"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"; lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo unavailable.'
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
python3 - "$ALPBAHOS_D34_PACKAGE" "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/plasma-d34-package-order.json" <<'PY'
import json,sys
if sys.argv[1] not in json.load(open(sys.argv[2],encoding='utf-8')): raise SystemExit('polkit-qt absent from approved D34 order')
PY
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"; lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=polkit-qt\nVERSION=%s\nLOG=%s\n' "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=polkit-qt exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$LOG.status"; fi; }; trap record_result EXIT
sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX \
  /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/polkit-qt-1-0.200.0"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -f "$source/CMakeLists.txt" ]]; chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib POLKIT_SOURCE='$source' POLKIT_BUILD='$build' POLKIT_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED'
set -Eeuo pipefail; mkdir -p "$POLKIT_BUILD"
cmake -S "$POLKIT_SOURCE" -B "$POLKIT_BUILD" -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_INSTALL_LIBDIR=lib -D CMAKE_BUILD_TYPE=Release \
  -D 'CMAKE_PREFIX_PATH=/opt/qt6;/usr' -D Qt6_DIR=/opt/qt6/lib/cmake/Qt6 -D QT_MAJOR_VERSION=6 -D BUILD_TESTING=OFF -W no-dev \
  > "$POLKIT_BUILD/configure.log" 2>&1 || { tail -n 140 "$POLKIT_BUILD/configure.log"; exit 1; }
cmake --build "$POLKIT_BUILD" --parallel 8 > "$POLKIT_BUILD/compile.log" 2>&1 || { tail -n 160 "$POLKIT_BUILD/compile.log"; exit 1; }
mkdir -p "$POLKIT_STAGE"; DESTDIR="$POLKIT_STAGE" cmake --install "$POLKIT_BUILD" > "$POLKIT_BUILD/staged-install.log" 2>&1 || { tail -n 120 "$POLKIT_BUILD/staged-install.log"; exit 1; }
test -s "$POLKIT_STAGE/usr/lib/cmake/PolkitQt6-1/PolkitQt6-1Config.cmake"
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
  if owners.get(rel)!='polkit-qt': raise SystemExit(f'refusing overwrite of {rel}: owner={owners.get(rel)!r}')
  old.append(raw)
open(dst,'wb').write(b''.join(p+b'\0' for p in old)); print(f'Polkit-Qt overlay {len(paths)} staged paths, {len(old)} prior-owned collisions')
MANIFEST
if [[ -s "$BACKUP/existing.list0" ]]; then sudo -n tar -cf "$BACKUP/preexisting-polkit-qt-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null -T "$BACKUP/existing.list0"; sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-polkit-qt-files.tar"; fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib /bin/bash -s -- "$WORK/stage" <<'INSTALL'
set -Eeuo pipefail; cp -a "$1"/. /; ldconfig; test -s /usr/lib/cmake/PolkitQt6-1/PolkitQt6-1Config.cmake; test -e /usr/lib/libpolkit-qt6-core-1.so
INSTALL
printf 'D34_RESULT=PASS PACKAGE=polkit-qt VERSION=%s LOG=%s\n' "$VERSION" "$LOG"
