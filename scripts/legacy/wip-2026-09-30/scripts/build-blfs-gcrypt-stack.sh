#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOGDIR="$DATA/logs/blfs-12.4-systemd"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not bound to the HDD build directory.'
[[ -c "$LFS/dev/null" ]] || fail 'Chroot /dev is not mounted.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'Chroot pseudo-filesystems are not all mounted.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then fail 'A build or package-test process is active.'; fi
mkdir -p "$LOGDIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOGDIR/libgcrypt-stack-$STAMP.log") 2>&1
readonly STACK_LOG="$LOGDIR/libgcrypt-stack-$STAMP.log"
record_result() { local rc=$?; if (( rc == 0 )); then printf 'BLFS_LIBGCRYPT_STACK_RESULT=PASS\nLOG=%s\n' "$STACK_LOG" > "$LOGDIR/libgcrypt-stack-$STAMP.status"; else printf 'BLFS_LIBGCRYPT_STACK_RESULT=FAIL exit=%s\nLOG=%s\n' "$rc" "$STACK_LOG" > "$LOGDIR/libgcrypt-stack-$STAMP.status"; fi; }
trap record_result EXIT
printf 'Building BLFS 12.4 libgpg-error 1.55, then libgcrypt 1.11.2. Package test suites/checksum calculations skipped; static archives and documentation retained.\n'
build_package() {
  local name="$1" version="$2" archive="$3" url="$4" recipe="$5"
  local work="/sources/$name-$version-blfs-$STAMP"
  local source="$work/$name-$version"
  local stage="$work/stage"
  local inside_log="$work/package.log"
  local package_log="$LOGDIR/$name-$version-blfs-$STAMP.package.log"
  local status="$LOGDIR/$name-$version-blfs-$STAMP.status"
  local backup="$DATA/backups/$name-before-final-$STAMP"
  local archive_path="$LFS/sources/$archive"
  local temp="$DATA/downloads/$archive.part-$STAMP"
  local staged="$backup/staged.list0"
  local existing="$backup/existing.list0"
  if [[ "$recipe" == libgcrypt ]] && sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
    [[ "$(pkg-config --modversion libgcrypt)" == 1.11.2 ]]
    for c in dumpsexp hmac256 mpicalc; do command -v "$c" >/dev/null; done
    [[ -f /usr/lib/libgcrypt.so && -f /usr/include/gcrypt.h ]]
    [[ -f /usr/share/doc/libgcrypt-1.11.2/gcrypt_nochunks.html && -f /usr/share/doc/libgcrypt-1.11.2/gcrypt.txt && -f /usr/share/doc/libgcrypt-1.11.2/html/index.html ]]
  '; then
    printf 'BLFS_PACKAGE_RESULT=PASS\nREUSED=libgcrypt-1.11.2-installed-and-verified\n' > "$status"
    printf 'Using the already installed libgcrypt 1.11.2; static checks passed.\n'
    return 0
  fi
  if [[ "$recipe" == libgpg-error ]] && sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
    [[ "$(gpgrt-config --version)" == 1.55 ]]
    [[ "$(pkg-config --modversion gpg-error)" == 1.55 ]]
    [[ -f /usr/share/doc/libgpg-error-1.55/README ]]
    [[ -f /usr/lib/libgpg-error.so && -f /usr/include/gpg-error.h ]]
  '; then
    printf 'BLFS_PACKAGE_RESULT=PASS\nREUSED=libgpg-error-1.55-installed-and-verified\n' > "$status"
    printf 'Using the already installed libgpg-error 1.55; static checks passed.\n'
    return 0
  fi
  [[ ! -e "$LFS$work" ]] || fail "Refusing to overwrite $work"
  mkdir -p "$backup"
  if [[ ! -r "$archive_path" ]]; then
    printf 'Downloading %s from %s\n' "$archive" "$url"
    curl --fail --location --retry 3 --output "$temp" "$url"
    sudo -n install -o 0 -g 0 -m 0644 "$temp" "$archive_path"
    rm -f "$temp"
  fi
  printf '\n=== %s %s ===\n' "$name" "$version"
  if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
      /bin/bash -s -- "$archive" "$work" "$source" "$stage" "$inside_log" "$recipe" <<'GCRYPT_BUILD_STAGE'
set -Eeuo pipefail
archive="$1"; work="$2"; source="$3"; stage="$4"; package_log="$5"; recipe="$6"
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/$archive" -C "$work"
[[ -d "$source" ]]
cd "$source"
case "$recipe" in
  libgpg-error)
    ./configure --prefix=/usr > "$work/configure.log" 2>&1
    if make -j4 > "$work/compile.log" 2>&1; then printf 'LIBGPG_ERROR_BUILD=PASS\n'; else rc=$?; tail -n 120 "$work/compile.log"; exit "$rc"; fi
    ;;
  libgcrypt)
    ./configure --prefix=/usr > "$work/configure.log" 2>&1
    if make -j4 > "$work/compile.log" 2>&1; then printf 'LIBGCRYPT_BUILD=PASS\n'; else rc=$?; tail -n 140 "$work/compile.log"; exit "$rc"; fi
    make -C doc html > "$work/docs-html.log" 2>&1
    makeinfo --html --no-split -o doc/gcrypt_nochunks.html doc/gcrypt.texi > "$work/docs-nochunks.log" 2>&1
    makeinfo --plaintext -o doc/gcrypt.txt doc/gcrypt.texi > "$work/docs-text.log" 2>&1
    [[ -d doc/gcrypt.html && -f doc/gcrypt_nochunks.html && -f doc/gcrypt.txt ]]
    ;;
  *) printf 'Unknown build recipe: %s\n' "$recipe" >&2; exit 2 ;;
esac
mkdir -pv "$stage"
make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1
if [[ "$recipe" == libgpg-error ]]; then
  install -v -m644 -D README "$stage/usr/share/doc/libgpg-error-1.55/README"
elif [[ "$recipe" == libgcrypt ]]; then
  doc="$stage/usr/share/doc/libgcrypt-1.11.2"
  install -v -d -m755 "$doc/html"
  install -v -m644 README doc/README.apichanges doc/fips* doc/libgcrypt* "$doc/"
  install -v -m644 doc/gcrypt.html/* "$doc/html/"
  install -v -m644 doc/gcrypt_nochunks.html "$doc/"
  install -v -m644 doc/gcrypt.txt doc/gcrypt.texi "$doc/"
fi
[[ -d "$stage/usr" ]]
printf 'PACKAGE_STAGED_INSTALL=PASS\n'
GCRYPT_BUILD_STAGE
  then
    if sudo -n test -f "$LFS$inside_log"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$inside_log" "$package_log"; fi
    printf 'BLFS_PACKAGE_RESULT=FAIL_BUILD_OR_STAGE\nLOG=%s\n' "$package_log" > "$status"
    fail "$name build or stage failed."
  fi
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$inside_log" "$package_log"
  sudo -n find "$LFS$stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$staged"
  python3 - "$LFS" "$staged" "$existing" <<'MANIFEST'
import os, sys
root, staged_path, output_path = sys.argv[1:]
with open(staged_path, "rb") as f: paths = [p for p in f.read().split(b"\0") if p]
old = []
for raw in paths:
    rel = os.fsdecode(raw)
    if os.path.isabs(rel) or ".." in rel.split("/"): raise SystemExit(f"unsafe staged path: {rel}")
    if os.path.lexists(os.path.join(root, rel)): old.append(raw)
with open(output_path, "wb") as f:
    for raw in sorted(set(old)): f.write(raw + b"\0")
print(f"Staged paths: {len(paths)}; existing paths: {len(set(old))}")
MANIFEST
  if [[ -s "$existing" ]]; then
    sudo -n tar --create --file="$backup/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$existing"
    sudo -n chown "$(id -u):$(id -g)" "$backup/preexisting-files.tar"
    sudo -n tar --list --file="$backup/preexisting-files.tar" > "$backup/archive.list"
    [[ -s "$backup/archive.list" ]] || fail "Backup archive is empty for $name."
  else
    printf 'No existing package targets needed backup.\n' > "$backup/no-preexisting-files.txt"
  fi
  if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
      /bin/bash -s -- "$source" "$inside_log" "$recipe" <<'GCRYPT_FINAL_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"; recipe="$3"
exec > >(tee -a "$package_log") 2>&1
cd "$source"
make -j1 install
case "$recipe" in
  libgpg-error)
    ldconfig
    install -v -m644 -D README /usr/share/doc/libgpg-error-1.55/README
    [[ "$(gpgrt-config --version)" == 1.55 ]]
    [[ "$(pkg-config --modversion gpg-error)" == 1.55 ]]
    for cmd in gpg-error gpgrt-config yat2m; do command -v "$cmd" >/dev/null; done
    [[ -f /usr/lib/libgpg-error.so && -f /usr/include/gpg-error.h && -f /usr/share/doc/libgpg-error-1.55/README && -d /usr/share/libgpg-error ]]
    ;;
  libgcrypt)
    doc=/usr/share/doc/libgcrypt-1.11.2
    install -v -d -m755 "$doc/html"
    install -v -m644 README doc/README.apichanges doc/fips* doc/libgcrypt* "$doc/"
    install -v -m644 doc/gcrypt.html/* "$doc/html/"
    install -v -m644 doc/gcrypt_nochunks.html "$doc/"
    install -v -m644 doc/gcrypt.txt doc/gcrypt.texi "$doc/"
    ldconfig
    [[ "$(pkg-config --modversion libgcrypt)" == 1.11.2 ]]
    for cmd in dumpsexp hmac256 mpicalc; do command -v "$cmd" >/dev/null; done
    [[ -f /usr/lib/libgcrypt.so && -f /usr/include/gcrypt.h ]]
    [[ -f "$doc/gcrypt_nochunks.html" && -f "$doc/gcrypt.txt" && -f "$doc/html/index.html" ]]
    readelf -h /usr/bin/hmac256 | grep -F 'Advanced Micro Devices X86-64'
    ldd /usr/bin/hmac256 | grep -E 'libc[.]so[.]6.*/usr/lib/'
    ;;
esac
printf '%s_FINAL_INSTALL=PASS\n' "$(tr '[:lower:]-' '[:upper:]_' <<< "$recipe")"
GCRYPT_FINAL_INSTALL
  then
    fail "$name final install or static verification failed."
  fi
  sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$inside_log" "$package_log"
  printf 'BLFS_PACKAGE_RESULT=PASS\nLOG=%s\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$package_log" "$package_log" "$LFS$work" "$backup" > "$status"
  printf 'Installed %s %s; no tests/checksums ran.\n' "$name" "$version"
}
build_package libgpg-error 1.55 libgpg-error-1.55.tar.bz2 https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.55.tar.bz2 libgpg-error
build_package libgcrypt 1.11.2 libgcrypt-1.11.2.tar.bz2 https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.11.2.tar.bz2 libgcrypt
printf '\nlibgpg-error/libgcrypt dependency chain completed.\nStack log: %s\nFinished: %s\n' "$STACK_LOG" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
