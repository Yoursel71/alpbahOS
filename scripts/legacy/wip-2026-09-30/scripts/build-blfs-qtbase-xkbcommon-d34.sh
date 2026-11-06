#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=6.9.2
readonly ARCHIVE="qtbase-everywhere-src-$VERSION.tar.xz"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-qtbase-xkbcommon-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qtbase-xkbcommon-$VERSION-d34-$STAMP.log"
readonly BACKUP="$DATA/backups/qtbase-xkbcommon-$VERSION-d34-$STAMP"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as regular user against the D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo unavailable.'
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
python3 - "$ALPBAHOS_D34_PACKAGE" "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/plasma-d34-package-order.json" <<'PY'
import json,sys
if sys.argv[1] not in json.load(open(sys.argv[2], encoding="utf-8")):
    raise SystemExit("qtbase-xkbcommon is absent from the approved D34 order")
PY
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=qtbase-xkbcommon\nVERSION=%s\nLOG=%s\n' "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=qtbase-xkbcommon exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT

sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
  CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:/opt/kf6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig \
  LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j8 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/qtbase-everywhere-src-6.9.2"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -x "$source/configure" ]]
mkdir -p "$build"; cd "$build"
"$source/configure" -opensource -confirm-license -prefix /opt/qt6 -sysconfdir /etc/xdg \
  -dbus-linked -openssl-linked -system-sqlite -journald -nomake examples -no-rpath -no-sbom -no-xcb \
  -feature-xkbcommon > "$work/configure.log" 2>&1 || { tail -n 180 "$work/configure.log"; exit 1; }
grep -q '^FEATURE_xkbcommon:BOOL=ON$' "$build/CMakeCache.txt" \
  && grep -Eiq 'xkbcommon.*(yes|on|true)' "$build/config.summary" \
  || { tail -n 80 "$build/config.summary"; echo 'QtBase did not enable xkbcommon'; exit 1; }
ninja -j8 > "$work/compile.log" 2>&1 || { tail -n 180 "$work/compile.log"; exit 1; }
mkdir -p "$stage"; DESTDIR="$stage" cmake --install "$build" > "$work/staged-install.log" 2>&1 \
  || { tail -n 140 "$work/staged-install.log"; exit 1; }
test -s "$stage/opt/qt6/include/QtGui/6.9.2/QtGui/private/qxkbcommon_p.h"
test -s "$stage/opt/qt6/lib/libQt6Gui.so.6.9.2"
BUILD

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
candidate="$ALPBAHOS_D34_CANDIDATE_PATH"
ledger="$(dirname -- "$candidate")/d34-ownership-ledger.json"
[[ -r "$ledger" ]] || fail "Missing reconciled ownership ledger for candidate: $ledger"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" "$ledger" <<'MANIFEST'
import json,os,sys
root,staged_path,existing_path,ledger_path=sys.argv[1:]
ledger=json.load(open(ledger_path,encoding="utf-8"))
if ledger.get("result") != "COMPLETE": raise SystemExit("candidate ownership ledger is not COMPLETE")
owners=ledger.get("final_system_path_owners",{})
staged=[p for p in open(staged_path,"rb").read().split(b"\0") if p]
collisions=[]
for raw in staged:
    rel=os.fsdecode(raw)
    if os.path.isabs(rel) or ".." in rel.split("/"): raise SystemExit(f"unsafe staged path: {rel}")
    if os.path.lexists(os.path.join(root,rel)):
        owner=owners.get(rel)
        if owner != "QtBase": raise SystemExit(f"refusing overwrite of {rel}: ledger owner is {owner!r}, expected QtBase")
        collisions.append(raw)
open(existing_path,"wb").write(b"".join(p+b"\0" for p in collisions))
print(f"QtBase xkbcommon overlay: {len(staged)} staged paths; {len(collisions)} collisions owned by QtBase")
MANIFEST

if [[ -s "$BACKUP/existing.list0" ]]; then
  sudo -n tar --create --file="$BACKUP/preexisting-qtbase-files.tar" --numeric-owner --acls --xattrs \
    -C "$LFS" --null --files-from="$BACKUP/existing.list0"
  sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-qtbase-files.tar"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
  LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib LC_ALL=POSIX /bin/bash -s -- "$WORK/stage" <<'INSTALL'
set -Eeuo pipefail
cp -a "$1"/. /
ldconfig
test -s /opt/qt6/include/QtGui/6.9.2/QtGui/private/qxkbcommon_p.h
test -s /opt/qt6/lib/libQt6Gui.so.6.9.2
INSTALL
printf 'D34_RESULT=PASS PACKAGE=qtbase-xkbcommon VERSION=%s LOG=%s\n' "$VERSION" "$LOG"
