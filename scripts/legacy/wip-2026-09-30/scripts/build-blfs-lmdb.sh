#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=0.9.33
readonly ARCHIVE="lmdb-$VERSION.tar.bz2"
readonly URL="https://git.openldap.org/openldap/openldap/-/archive/LMDB_$VERSION/$ARCHIVE"
readonly WORK="/sources/lmdb-$VERSION-blfs-$STAMP"
readonly SOURCE="$WORK/openldap-LMDB_0.9.33-3a29a24777c82a0165de813ae696a5068b5add30"
readonly LIBSOURCE="$SOURCE/libraries/liblmdb"
readonly STAGE="$WORK/stage"
readonly LOGDIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOGDIR/lmdb-$VERSION-blfs-$STAMP.log"
readonly STATUS="$LOGDIR/lmdb-$VERSION-blfs-$STAMP.status"
readonly PACKAGE_LOG="$LOGDIR/lmdb-$VERSION-blfs-$STAMP.package.log"
readonly BACKUP="$DATA/backups/lmdb-before-final-$STAMP"
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
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_LMDB_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"; else printf 'BLFS_LMDB_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$LOG" > "$STATUS"; fi; }
trap record_result EXIT
[[ ! -e "$LFS$WORK" ]] || fail "Refusing to overwrite $WORK"
printf 'Building BLFS 12.4 LMDB %s. Package has no test suite; source checksums are skipped.\n' "$VERSION"
if [[ ! -r "$ARCHIVE_PATH" ]]; then
  tmp="$DATA/downloads/$ARCHIVE.part-$STAMP"
  curl --fail --location --retry 3 --output "$tmp" "$URL"
  sudo -n install -o 0 -g 0 -m 0644 "$tmp" "$ARCHIVE_PATH"
  rm -f "$tmp"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
  /bin/bash -s -- "$ARCHIVE" "$WORK" "$SOURCE" "$LIBSOURCE" "$STAGE" <<'LMDB_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; libsource="$4"; stage="$5"
mkdir -pv "$work"
exec > >(tee "$work/package.log") 2>&1
tar -xjf "/sources/$archive" -C "$work"
[[ -f "$libsource/Makefile" && -f "$libsource/lmdb.h" ]]
cd "$libsource"
make -j4 > "$work/compile.log" 2>&1
sed -i 's| liblmdb.a||' Makefile
mkdir -pv "$stage/usr"
make -j1 prefix="$stage/usr" install > "$work/staged-install.log" 2>&1
[[ -x "$stage/usr/bin/mdb_copy" && -x "$stage/usr/bin/mdb_dump" && -f "$stage/usr/lib/liblmdb.so" && -f "$stage/usr/include/lmdb.h" ]]
printf 'LMDB_BUILD_AND_STAGE=PASS\n'
LMDB_BUILD_STAGE
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
sudo -n find "$LFS$STAGE" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$BACKUP/staged.list0"
python3 - "$LFS" "$BACKUP/staged.list0" "$BACKUP/existing.list0" <<'PY'
import os,sys
root,staged,out=sys.argv[1:]
with open(staged,"rb") as f: paths=[p for p in f.read().split(b"\0") if p]
old=[]
for p in paths:
    rel=os.fsdecode(p)
    if os.path.isabs(rel) or ".." in rel.split("/"): raise SystemExit(f"unsafe path: {rel}")
    if os.path.lexists(os.path.join(root,rel)): old.append(p)
with open(out,"wb") as f:
    for p in sorted(set(old)): f.write(p+b"\0")
print(f"Staged paths: {len(paths)}; existing targets: {len(set(old))}")
PY
if [[ -s "$BACKUP/existing.list0" ]]; then
  sudo -n tar --create --file="$BACKUP/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$BACKUP/existing.list0"
  sudo -n chown "$(id -u):$(id -g)" "$BACKUP/preexisting-files.tar"
  sudo -n tar --list --file="$BACKUP/preexisting-files.tar" > "$BACKUP/archive.list"
  [[ -s "$BACKUP/archive.list" ]] || fail 'Pre-install backup archive is empty.'
else
  printf 'No existing LMDB targets needed backup.\n' > "$BACKUP/no-preexisting-files.txt"
fi
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
  /bin/bash -s -- "$LIBSOURCE" "$WORK" <<'LMDB_FINAL_INSTALL'
set -Eeuo pipefail
libsource="$1"; work="$2"
exec > >(tee -a "$work/package.log") 2>&1
cd "$libsource"
make -j1 prefix=/usr install
ldconfig
for c in mdb_copy mdb_dump mdb_load mdb_stat; do command -v "$c" >/dev/null; done
[[ -f /usr/lib/liblmdb.so && -f /usr/include/lmdb.h ]]
readelf -h /usr/bin/mdb_copy | grep -F 'Advanced Micro Devices X86-64'
ldd /usr/bin/mdb_copy | grep -E 'libc[.]so[.]6.*/usr/lib/'
[[ ! -e /usr/lib/liblmdb.a ]]
printf 'LMDB_0_9_33_FINAL_INSTALL=PASS\nSTATIC_ARCHIVE=NOT_INSTALLED_PER_BLFS_RECIPE\n'
LMDB_FINAL_INSTALL
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$WORK/package.log" "$PACKAGE_LOG"
printf 'BLFS_LMDB_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$PACKAGE_LOG" "$LFS$WORK" "$BACKUP" > "$STATUS"
printf '\nLMDB installed; no package tests or checksum calculations ran.\nStatus: %s\nFinished: %s\n' "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

