#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=0.21.2
readonly ARCHIVE="docutils-0.21.2.tar.gz"
readonly URL="https://files.pythonhosted.org/packages/source/d/docutils/$ARCHIVE"
readonly WORK="/sources/docutils-0.21.2-blfs-$STAMP"
readonly SOURCE="$WORK/docutils-0.21.2"
readonly LOGDIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOGDIR/docutils-0.21.2-blfs-$STAMP.log"
readonly STATUS="$LOGDIR/docutils-0.21.2-blfs-$STAMP.status"
readonly PACKAGE_LOG="$LOGDIR/docutils-0.21.2-blfs-$STAMP.package.log"
readonly BACKUP="$DATA/backups/docutils-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/$ARCHIVE"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the HDD build directory.'
[[ -c "$LFS/dev/null" ]] || fail 'Chroot /dev is not mounted.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not all mounted.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
mkdir -p "$LOGDIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$BACKUP"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_DOCUTILS_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'BLFS_DOCUTILS_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
[[ ! -e "$LFS$WORK" ]] || fail "Refusing to overwrite $WORK"
printf 'Building BLFS 12.4 docutils %s wheel for GLib man-page generation. Package tests/checksum calculations skipped.\n' "0.21.2"
if [[ ! -r "$ARCHIVE_PATH" ]]; then
  tmp="$DATA/downloads/$ARCHIVE.part-$STAMP"
  curl --fail --location --retry 3 --output "$tmp" "$URL"
  sudo -n install -o 0 -g 0 -m 0644 "$tmp" "$ARCHIVE_PATH"
  rm -f "$tmp"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
  /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" <<'CHROOT'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"
mkdir -pv "$work"
exec > >(tee "$work/package.log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -f "$source/pyproject.toml" ]]
mkdir -pv "$source/dist"
python3 -m pip wheel -w "$source/dist" --no-build-isolation --no-deps --no-cache-dir "$source"
mkdir -pv "$work/stage"
python3 -m pip install --root="$work/stage" --no-index --find-links="$source/dist" --no-user --no-deps --ignore-installed "docutils==0.21.2"
[[ -d "$work/stage/usr/lib/python3.13/site-packages/docutils" ]]
printf 'DOCUTILS_WHEEL_AND_STAGE=PASS\n'
CHROOT
sudo -n find "$LFS$WORK/stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os, sys
root, staged_path, output_path = sys.argv[1:]
with open(staged_path, "rb") as f: staged = [p for p in f.read().split(b"\0") if p]
existing = []
for raw in staged:
    rel = os.fsdecode(raw)
    if os.path.isabs(rel) or ".." in rel.split("/"): raise SystemExit(f"unsafe path: {rel}")
    if os.path.lexists(os.path.join(root, rel)): existing.append(raw)
with open(output_path, "wb") as f:
    for raw in sorted(set(existing)): f.write(raw + b"\0")
print(f"Staged paths: {len(staged)}; pre-existing targets: {len(set(existing))}")
PY
if [[ -s "$BACKUP/existing.list0" ]]; then
  sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/existing.list0"
  sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
  sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
  [[ -s "$BACKUP/archive.list" ]] || fail 'Pre-install backup archive is empty.'
else printf 'No existing docutils targets needed backup.\n' > "$BACKUP/no-preexisting-files.txt"; fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -s -- "$WORK" <<'INSTALL'
set -Eeuo pipefail
work="$1";
exec > >(tee -a "$work/package.log") 2>&1
python3 -m pip install --no-index --find-links="$work/docutils-0.21.2/dist" --no-user --no-deps --force-reinstall docutils
python3 -c 'import docutils, importlib.metadata as m; assert m.version("docutils") == "0.21.2"; print("docutils", docutils.__version__)'
command -v docutils >/dev/null; command -v rst2man >/dev/null
[[ -d /usr/lib/python3.13/site-packages/docutils && -d /usr/lib/python3.13/site-packages/docutils-0.21.2.dist-info ]]
printf 'DOCUTILS_FINAL_INSTALL=PASS\n'
INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
printf 'BLFS_DOCUTILS_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$PACKAGE_LOG" "$LFS$WORK" "$BACKUP" > "$STATUS"
printf 'docutils installed; package tests/checksum calculations skipped.\nStatus: %s\nFinished: %s\n' "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
