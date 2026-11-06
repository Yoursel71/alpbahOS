#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly PACKAGE="${ALPBAHOS_D34_PACKAGE:?D34 runner must set ALPBAHOS_D34_PACKAGE}"
case "$PACKAGE" in
  xkeyboard-config)
    readonly VERSION=2.45 ARCHIVE=xkeyboard-config-2.45.tar.xz
    readonly URL=https://www.x.org/pub/individual/data/xkeyboard-config/xkeyboard-config-2.45.tar.xz
    readonly SOURCE_DIR=xkeyboard-config-2.45
    readonly MESON_OPTIONS=''
    ;;
  libxkbcommon)
    readonly VERSION=1.11.0 ARCHIVE=libxkbcommon-1.11.0.tar.gz
    readonly URL=https://github.com/lfs-book/libxkbcommon/archive/v1.11.0/libxkbcommon-1.11.0.tar.gz
    readonly SOURCE_DIR=libxkbcommon-1.11.0
    readonly MESON_OPTIONS='-D enable-docs=false -D enable-x11=false'
    ;;
  libxkbcommon-x11)
    readonly VERSION=1.11.0 ARCHIVE=libxkbcommon-1.11.0.tar.gz
    readonly URL=https://github.com/lfs-book/libxkbcommon/archive/v1.11.0/libxkbcommon-1.11.0.tar.gz
    readonly SOURCE_DIR=libxkbcommon-1.11.0
    readonly MESON_OPTIONS='-D enable-docs=false -D enable-x11=true -D enable-tools=false -D enable-wayland=false -D enable-xkbregistry=false'
    ;;
  *) printf 'Unsupported D34 XKB package: %s\n' "$PACKAGE" >&2; exit 2 ;;
esac
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-$PACKAGE-$VERSION-$STAMP"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/$PACKAGE-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/$PACKAGE-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/$PACKAGE-d34-$STAMP"

fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular host user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another package build is active.'
fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$STATUS"; else printf 'D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT

archive_path="$DATA/downloads/$ARCHIVE"
if [[ ! -r "$archive_path" ]]; then
    temp="$archive_path.part-$STAMP"
    curl --fail --location --retry 3 --output "$temp" "$URL"
    mv -- "$temp" "$archive_path"
fi
sudo -n install -o 0 -g 0 -m 0644 "$archive_path" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
    LC_ALL=POSIX MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE_DIR" "$MESON_OPTIONS" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source_dir="$3"; options="$4"
source="$work/$source_dir"; build="$work/build"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/meson.build" ]]
# Both names/options originate from the fixed package allowlist above.
meson setup "$build" "$source" --prefix=/usr --buildtype=release $options > "$work/configure.log" 2>&1 \
    || { tail -n 120 "$work/configure.log"; exit 1; }
ninja -C "$build" -j8 > "$work/compile.log" 2>&1 || { tail -n 120 "$work/compile.log"; exit 1; }
mkdir -p "$stage"
DESTDIR="$stage" ninja -C "$build" install > "$work/staged-install.log" 2>&1 \
    || { tail -n 100 "$work/staged-install.log"; exit 1; }
[[ -d "$stage/usr" ]]
BUILD

sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" "$PACKAGE" "$ALPBAHOS_D34_CANDIDATE_PATH" <<'PY'
import json,os,sys
root,src,dst,package,candidate=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in collisions))
print(f"{len(paths)} staged paths; {len(collisions)} collisions")
if collisions:
    if package != "libxkbcommon-x11": raise SystemExit("Refusing to overwrite existing candidate paths")
    ledger_path=os.path.join(os.path.dirname(candidate),"d34-ownership-ledger.json")
    ledger=json.load(open(ledger_path,encoding="utf-8"))
    if ledger.get("result") != "COMPLETE": raise SystemExit("Refusing XKB overlay without a COMPLETE ownership ledger")
    owners=ledger.get("final_system_path_owners",{})
    wrong=[os.fsdecode(p) for p in collisions if owners.get(os.fsdecode(p)) != "libxkbcommon"]
    if wrong: raise SystemExit("Refusing XKB X11 overlay; paths not owned by libxkbcommon: "+repr(wrong[:12]))
    print(f"XKB X11 overlay may replace {len(collisions)} paths owned by libxkbcommon")
PY
if [[ -s "$BACKUP/existing.list0" ]]; then
    sudo -n tar --create --file="$BACKUP/preexisting-libxkbcommon-files.tar" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$BACKUP/existing.list0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-libxkbcommon-files.tar"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$PACKAGE" "$WORK/build" <<'INSTALL'
set -Eeuo pipefail
package="$1"; build="$2"
ninja -C "$build" install
case "$package" in
  xkeyboard-config)
    printf 'XKB compatibility root: %s\n' "$(readlink /usr/share/X11/xkb)"
    for path in /usr/share/xkeyboard-config-2/rules/evdev /usr/share/xkeyboard-config-2/symbols/us \
                /usr/share/xkeyboard-config-2/symbols/tr /usr/share/X11/xkb/symbols/tr; do
        [[ -r "$path" ]] || { printf 'Missing installed XKB data: %s\n' "$path" >&2; exit 1; }
    done
    ;;
  libxkbcommon)
    ldconfig
    [[ "$(pkg-config --modversion xkbcommon)" == 1.11.0 ]]
    command -v xkbcli >/dev/null
    xkbcli --version
    [[ -f /usr/lib/libxkbcommon.so.0 && -d /usr/include/xkbcommon ]]
    ;;
  libxkbcommon-x11)
    ldconfig
    [[ "$(pkg-config --modversion xkbcommon-x11)" == 1.11.0 ]]
    [[ -f /usr/lib/libxkbcommon-x11.so.0 && -f /usr/include/xkbcommon/xkbcommon-x11.h ]]
    ;;
esac
INSTALL
printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$STATUS"
