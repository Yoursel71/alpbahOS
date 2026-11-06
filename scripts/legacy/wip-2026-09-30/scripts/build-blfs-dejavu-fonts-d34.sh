#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs DATA=/mnt/alpbahOS-data/alpbahOS-build VERSION=2.37
readonly ARCHIVE="dejavu-fonts-ttf-$VERSION.zip" STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK="/sources/dejavu-fonts-$VERSION-d34-$STAMP"
readonly STAGE="$WORK/stage"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/dejavu-fonts-$VERSION-d34-$STAMP.log"
readonly STATUS="$LOG_DIR/dejavu-fonts-$VERSION-d34-$STAMP.status"
readonly BACKUP="$DATA/backups/dejavu-fonts-$VERSION-d34-$STAMP"
readonly URL="https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/$ARCHIVE"
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as regular user.'
[[ -d "$LFS" ]] || fail 'D34 candidate is not mounted.'
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
lfs_validate_target "$LFS" "$DATA"; sudo -n true || fail 'Non-interactive sudo unavailable.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v fc-cache >/dev/null && command -v fc-match >/dev/null && test -r /etc/fonts/fonts.conf && ! -d /usr/share/fonts/dejavu'
mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
lfs_acquire_writer_lock "$DATA"; exec > >(tee "$LOG") 2>&1
record_result(){ local rc=$?; if ((rc==0)); then printf 'DEJAVU_FONTS_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'DEJAVU_FONTS_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
if ! sudo -n test -r "$ARCHIVE_PATH"; then
  if [[ -r "$DATA/downloads/$ARCHIVE" ]]; then sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE" "$ARCHIVE_PATH"
  else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /usr/bin/python3 - "$ARCHIVE" "$WORK" <<'STAGE'
import pathlib,sys,zipfile
archive,work=sys.argv[1:]; root=pathlib.Path(work); dest=root/'stage/usr/share/fonts/dejavu'; dest.mkdir(parents=True)
with zipfile.ZipFile('/sources/'+archive) as z:
    members=[m for m in z.infolist() if m.filename.startswith('dejavu-fonts-ttf-2.37/ttf/') and m.filename.lower().endswith('.ttf')]
    if not members: raise SystemExit('DejaVu archive contains no TTF font payload')
    for m in members:
        target=dest/pathlib.PurePosixPath(m.filename).name
        target.write_bytes(z.read(m)); target.chmod(0o644)
print('DejaVu TTF staged:',len(members))
STAGE
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,src,dst=sys.argv[1:]; paths=[p for p in open(src,'rb').read().split(b'\0') if p]; collisions=[p for p in paths if os.path.lexists(os.path.join(root,os.fsdecode(p)))]
open(dst,'wb').write(b''.join(p+b'\0' for p in collisions)); print(f'DejaVu staged paths: {len(paths)}; collisions: {len(collisions)}')
if collisions: raise SystemExit('Refusing to overwrite existing candidate paths')
PY
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$STAGE/usr/share/fonts/dejavu" <<'INSTALL'
set -Eeuo pipefail
install -d -m 0755 /usr/share/fonts/dejavu
cp -a "$1/." /usr/share/fonts/dejavu/
fc-cache -f /usr/share/fonts/dejavu
family="$(fc-match --format '%{family}\n' 'sans:lang=tr' | head -n 1)"
[[ "$family" == *"DejaVu Sans"* ]]
printf 'DejaVu Turkish font match: %s\n' "$family"
INSTALL
printf 'DEJAVU_FONTS_RESULT=PASS\nLOG=%s\nVERSION=%s\n' "$LOG" "$VERSION" > "$STATUS"
