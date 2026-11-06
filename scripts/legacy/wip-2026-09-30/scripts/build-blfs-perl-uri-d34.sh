#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly PACKAGE="${ALPBAHOS_D34_PACKAGE:?D34 runner must set ALPBAHOS_D34_PACKAGE}"
[[ "$PACKAGE" == perl-uri ]] || { echo 'This builder only accepts perl-uri.' >&2; exit 2; }
readonly VERSION=5.32 ARCHIVE=URI-5.32.tar.gz
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/dev/shm/alpbahos-d34-perl-uri-$STAMP"
readonly STAGE="$WORK/stage"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/perl-uri-d34-$STAMP.log"
readonly BACKUP="$DATA/backups/perl-uri-d34-$STAMP"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 && -d "$LFS" ]] || fail 'Run as the regular user against the D34 candidate.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$BACKUP"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'D34_RESULT=PASS\nPACKAGE=%s\nVERSION=%s\nLOG=%s\n' "$PACKAGE" "$VERSION" "$LOG" > "$LOG.status"; else printf 'D34_RESULT=FAIL package=%s exit=%s\nLOG=%s\n' "$PACKAGE" "$rc" "$LOG" > "$LOG.status"; fi; }
trap record_result EXIT
[[ -r "$DATA/downloads/$ARCHIVE" ]] || fail "Missing source archive: $DATA/downloads/$ARCHIVE"
sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$LFS/sources/$ARCHIVE"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
set -Eeuo pipefail
archive="$1"; work="$2"; stage="$work/stage"; source="$work/URI-5.32"
[[ ! -e "$work" ]] || { echo "Refusing existing work tree: $work" >&2; exit 1; }
mkdir -p "$work"; tar -xf "/sources/$archive" -C "$work"; [[ -f "$source/Makefile.PL" ]]
cd "$source"
perl Makefile.PL > "$work/configure.log" 2>&1 || { tail -n 80 "$work/configure.log"; exit 1; }
make -j4 > "$work/build.log" 2>&1 || { tail -n 80 "$work/build.log"; exit 1; }
mkdir -p "$stage"
make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1 || { tail -n 80 "$work/staged-install.log"; exit 1; }
# MakeMaker's shared perllocal.pod is an installation log, not module payload.
find "$stage" -name perllocal.pod -type f -delete
find "$stage" -type f -o -type l | grep -q .
BUILD
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]
paths=[p for p in open(src,'rb').read().split(b'\0') if p]
existing=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in existing))
print(f'Perl URI staged paths={len(paths)} existing targets={len(existing)}')
if existing: raise SystemExit(f'Refusing existing candidate paths: {existing[:8]!r}')
PY
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
  /bin/bash -s -- "$STAGE" <<'INSTALL'
set -Eeuo pipefail
cp -a "$1/." /
perl -MURI::Escape -e 'print "$URI::Escape::VERSION\n"; exit(($URI::Escape::VERSION // "") eq "5.32" ? 0 : 1)'
perl -MURI::Escape -e 'exit(URI::Escape::uri_escape("a b") eq "a%20b" ? 0 : 1)'
INSTALL
printf 'Perl URI::Escape 5.32 installed and smoke-checked.\n'
