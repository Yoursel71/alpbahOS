#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=4.12.0
readonly ARCHIVE="phonon-$VERSION.tar.xz"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-phonon-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/phonon-$VERSION-d34-$STAMP.log"
readonly BACKUP="$DATA/backups/phonon-$VERSION-d34-$STAMP"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo unavailable.'
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
python3 - "$ALPBAHOS_D34_PACKAGE" "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/plasma-d34-package-order.json" <<'PY'
import json,sys
if sys.argv[1] not in json.load(open(sys.argv[2], encoding="utf-8")):
    raise SystemExit("phonon is absent from the approved D34 package order")
PY
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
printf 'Phonon Qt6 D34 build start; package=%s candidate=%s\n' "$ALPBAHOS_D34_PACKAGE" "$ALPBAHOS_D34_CANDIDATE_PATH"
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=phonon\nVERSION=%s\nLOG=%s\n' "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=phonon exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT

sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
  CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib \
  LC_ALL=POSIX MAKEFLAGS=-j8 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/phonon-4.12.0"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -f "$source/CMakeLists.txt" ]]
chown -R nobody:nogroup "$work"
su -s /bin/bash nobody -c "env HOME=/tmp PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib PHONON_SOURCE='$source' PHONON_BUILD='$build' PHONON_STAGE='$stage' /bin/bash -s" <<'UNPRIVILEGED'
set -Eeuo pipefail
mkdir -p "$PHONON_BUILD"
cmake -S "$PHONON_SOURCE" -B "$PHONON_BUILD" \
  -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_INSTALL_LIBDIR=lib \
  -D CMAKE_PREFIX_PATH=/opt/qt6\;/opt/kf6\;/usr -D Qt6_DIR=/opt/qt6/lib/cmake/Qt6 \
  -D PHONON_BUILD_QT5=OFF -D BUILD_TESTING=OFF -D CMAKE_BUILD_TYPE=Release -W no-dev \
  > "$PHONON_BUILD/configure.log" 2>&1 || { tail -n 120 "$PHONON_BUILD/configure.log"; exit 1; }
cmake --build "$PHONON_BUILD" --parallel 8 > "$PHONON_BUILD/compile.log" 2>&1 \
  || { tail -n 160 "$PHONON_BUILD/compile.log"; exit 1; }
mkdir -p "$PHONON_STAGE"
DESTDIR="$PHONON_STAGE" cmake --install "$PHONON_BUILD" > "$PHONON_BUILD/staged-install.log" 2>&1 \
  || { tail -n 120 "$PHONON_BUILD/staged-install.log"; exit 1; }
test -s "$PHONON_STAGE/usr/lib/cmake/phonon4qt6/Phonon4Qt6Config.cmake"
UNPRIVILEGED
chown -R 0:0 "$stage"
BUILD

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" "$ALPBAHOS_D34_CANDIDATE_PATH" <<'MANIFEST'
import json,os,sys
root,staged_path,existing_path,candidate=sys.argv[1:]
ledger_path=os.path.join(os.path.dirname(candidate),"d34-ownership-ledger.json")
ledger=json.load(open(ledger_path,encoding="utf-8"))
if ledger.get("result") != "COMPLETE": raise SystemExit("candidate ownership ledger is not COMPLETE")
owners=ledger.get("final_system_path_owners",{})
staged=[p for p in open(staged_path,"rb").read().split(b"\0") if p]
collisions=[]
for raw in staged:
    rel=os.fsdecode(raw)
    if os.path.isabs(rel) or ".." in rel.split("/"): raise SystemExit(f"unsafe staged path: {rel}")
    if os.path.lexists(os.path.join(root,rel)):
        if owners.get(rel) != "phonon": raise SystemExit(f"refusing overwrite of {rel}: ledger owner is {owners.get(rel)!r}")
        collisions.append(raw)
open(existing_path,"wb").write(b"".join(p+b"\0" for p in collisions))
print(f"Phonon overlay: {len(staged)} staged paths; {len(collisions)} prior phonon-owned collisions")
MANIFEST
if [[ -s "$BACKUP/existing.list0" ]]; then
  sudo -n tar --create --file="$BACKUP/preexisting-phonon-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/existing.list0"
  sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-phonon-files.tar"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib \
  /bin/bash -s -- "$WORK/stage" <<'INSTALL'
set -Eeuo pipefail
cp -a "$1"/. /
ldconfig
test -s /usr/lib/cmake/phonon4qt6/Phonon4Qt6Config.cmake
test -e /usr/lib/libphonon4qt6.so
INSTALL
printf 'D34_RESULT=PASS PACKAGE=phonon VERSION=%s LOG=%s\n' "$VERSION" "$LOG"
