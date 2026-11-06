#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=6.0.2
readonly ARCHIVE="pyyaml-$VERSION.tar.gz" STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/pyyaml-$VERSION-d34-$STAMP"
readonly SOURCE="$WORK/pyyaml-$VERSION"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/pyyaml-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/pyyaml-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/pyyaml-$VERSION-d34-$STAMP"
readonly URL="https://files.pythonhosted.org/packages/source/P/PyYAML/$ARCHIVE"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as regular user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"; sudo -n true || fail 'Non-interactive sudo unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/python3 && -x /usr/bin/pip3 && -d /usr/lib/python3.13/site-packages/Cython && -e /usr/lib/libyaml.so && ! -d /usr/lib/python3.13/site-packages/yaml ]]'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "meson" { found=1 } END { exit found ? 0 : 1 }'; then fail 'Another build process is active.'; fi
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"; exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'PYYAML_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'PYYAML_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
  if [[ -r "$DATA/downloads/$ARCHIVE" ]]; then sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$ARCHIVE_PATH"
  else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$work/pyyaml-6.0.2"; stage="$work/stage"
[[ ! -e "$work" ]] || { echo "Refusing to overwrite $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; mkdir -p "$source/dist"
python3 -m pip wheel -w "$source/dist" --no-build-isolation --no-deps --no-cache-dir "$source" > "$work/wheel.log" 2>&1
python3 -m pip install --root="$stage" --no-index --find-links="$source/dist" --no-user --no-deps --ignore-installed PyYAML > "$work/staged-install.log" 2>&1
find "$source/dist" -maxdepth 1 -name 'pyyaml-6.0.2-*.whl' | grep -q .; [[ -d "$stage/usr/lib/python3.13/site-packages/yaml" ]]
BUILD
sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]; paths=[p for p in open(src,'rb').read().split(b'\0') if p]; existing=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in existing)); print(f'PyYAML staged paths: {len(paths)}; collisions: {len(existing)}')
if existing: raise SystemExit('Refusing to overwrite existing candidate paths')
PY
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$SOURCE" <<'INSTALL'
set -Eeuo pipefail
python3 -m pip install --no-index --find-links="$1/dist" --no-user --no-deps --force-reinstall PyYAML
python3 -c 'import yaml,importlib.metadata as m; assert m.version("PyYAML")=="6.0.2"; import yaml._yaml; print("PyYAML",m.version("PyYAML"),"C extension OK")'
INSTALL
printf 'PYYAML_RESULT=PASS\nLOG=%s\nVERSION=%s\n' "$LOG" "$VERSION" > "$STATUS"
