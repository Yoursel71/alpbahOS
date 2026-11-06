#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qca-prereqs-blfs-$STAMP.log"
readonly STATUS="$LOG_DIR/qca-prereqs-blfs-$STAMP.status"
readonly WORK_PREFIX=/sources/alpbahos-qca-prereqs

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run the host orchestrator as the regular Fedora user.'
[[ -d "$LFS" ]] || fail 'The LFS target is missing.'
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another package build or test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1
record_result() {
    local result=$?
    if (( result == 0 )); then
        printf 'BLFS_QCA_PREREQUISITES_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_QCA_PREREQUISITES_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

fetch_source() {
    local archive="$1" url="$2" temporary="$DATA/downloads/$1.partial-$STAMP"
    if ! sudo -n test -r "$LFS/sources/$archive"; then
        printf 'Downloading %s from %s\n' "$archive" "$url"
        curl --fail --location --retry 3 --output "$temporary" "$url"
        sudo -n install -o 0 -g 0 -m 0644 "$temporary" "$LFS/sources/$archive"
    else
        printf 'Keeping existing source archive: %s\n' "$LFS/sources/$archive"
    fi
}

stage_paths_and_backup() {
    local label="$1" stage="$2"
    local backup="$DATA/backups/${label}-before-final-${STAMP}"
    mkdir -p "$backup"
    sudo -n find "$LFS$stage" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$backup/staged-paths.list0"
    python3 - "$LFS" "$backup/staged-paths.list0" "$backup/preexisting-paths.list0" <<'PY'
import os, sys
root, staged_path, existing_path = sys.argv[1:]
with open(staged_path, "rb") as stream:
    staged = [path for path in stream.read().split(b"\0") if path]
existing = []
for raw in staged:
    relative = os.fsdecode(raw)
    if os.path.isabs(relative) or ".." in relative.split("/"):
        raise SystemExit(f"Unsafe staged path: {relative!r}")
    if os.path.lexists(os.path.join(root, relative)):
        existing.append(raw)
with open(existing_path, "wb") as stream:
    for raw in sorted(set(existing)):
        stream.write(raw + b"\0")
print(f"Staged paths: {len(staged)}; existing targets: {len(set(existing))}", file=sys.stderr)
PY
    if [[ -s "$backup/preexisting-paths.list0" ]]; then
        sudo -n tar --create --file="$backup/preexisting-files.tar" --numeric-owner --acls --xattrs -C "$LFS" --null --files-from="$backup/preexisting-paths.list0"
        sudo -n chown "$(id -u):$(id -g)" "$backup/preexisting-files.tar"
        sudo -n tar --list --file="$backup/preexisting-files.tar" > "$backup/archive.list"
        [[ -s "$backup/archive.list" ]] || fail "The $label pre-install backup archive is empty."
    else
        printf 'No pre-existing targets required backup.\n' > "$backup/no-preexisting-files.txt"
    fi
    printf '%s\n' "$backup"
}

mark_package_pass() {
    local label="$1" package_log="$2" build_tree="$3" backup="$4"
    local package_status="$LOG_DIR/$label-blfs-$STAMP.status"
    sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$package_log" "$LOG_DIR/$label-blfs-$STAMP.package.log"
    printf 'BLFS_PACKAGE_RESULT=PASS\nPACKAGE_LOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\nTESTS=SKIPPED\nCHECKSUMS=SKIPPED\n' \
        "$LOG_DIR/$label-blfs-$STAMP.package.log" "$LFS$build_tree" "$backup" > "$package_status"
    printf 'PACKAGE_%s=PASS\nSTATUS=%s\n' "${label^^}" "$package_status"
}

printf 'Preparing the BLFS 12.4 QCA prerequisite chain on %s.\n' "$LFS"
printf 'Package tests and source checksum calculations are skipped per user preference.\n'
printf 'Started: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

fetch_source libtasn1-4.20.0.tar.gz https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz
fetch_source which-2.23.tar.gz https://ftp.gnu.org/gnu/which/which-2.23.tar.gz
fetch_source make-ca-1.16.1.tar.gz https://github.com/lfs-book/make-ca/archive/v1.16.1/make-ca-1.16.1.tar.gz
fetch_source p11-kit-0.25.5.tar.xz https://github.com/p11-glue/p11-kit/releases/download/0.25.5/p11-kit-0.25.5.tar.xz
fetch_source mozilla-nss-certdata.txt https://hg-edge.mozilla.org/projects/nss/raw-file/tip/lib/ckfw/builtins/certdata.txt

readonly LIBTASN1_WORK="$WORK_PREFIX/libtasn1-4.20.0-$STAMP"
readonly LIBTASN1_SOURCE="$LIBTASN1_WORK/libtasn1-4.20.0"
readonly LIBTASN1_STAGE="$LIBTASN1_WORK/stage"
readonly LIBTASN1_LOG="$LIBTASN1_WORK/package.log"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$LIBTASN1_WORK" "$LIBTASN1_SOURCE" "$LIBTASN1_STAGE" "$LIBTASN1_LOG" <<'LIBTASN1_BUILD'
set -Eeuo pipefail
work="$1"; source="$2"; stage="$3"; package_log="$4"
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xzf /sources/libtasn1-4.20.0.tar.gz -C "$work"
[[ -x "$source/configure" ]]
cd "$source"
./configure --prefix=/usr --disable-static > "$work/configure.log" 2>&1
if make -j4 > "$work/compile.log" 2>&1; then printf 'LIBTASN1_BUILD=PASS\n'; else rc=$?; tail -n 100 "$work/compile.log"; exit "$rc"; fi
mkdir -pv "$stage"
make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1
[[ -f "$stage/usr/lib/libtasn1.so" && -x "$stage/usr/bin/asn1Parser" && -f "$stage/usr/lib/pkgconfig/libtasn1.pc" ]]
printf 'LIBTASN1_STAGED_INSTALL=PASS\n'
LIBTASN1_BUILD
LIBTASN1_BACKUP="$(stage_paths_and_backup libtasn1-4.20.0 "$LIBTASN1_STAGE")" || fail 'Unable to back up pre-existing libtasn1 paths.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$LIBTASN1_SOURCE" "$LIBTASN1_LOG" <<'LIBTASN1_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cd "$source"
make -j1 install
ldconfig
[[ "$(pkg-config --modversion libtasn1)" == 4.20.0 ]]
[[ -f /usr/lib/libtasn1.so && -x /usr/bin/asn1Parser ]]
readelf -h /usr/bin/asn1Parser | grep -F 'Advanced Micro Devices X86-64'
ldd /usr/bin/asn1Parser | grep -E 'libc[.]so[.]6.*/usr/lib/'
printf 'LIBTASN1_FINAL_INSTALL=PASS\n'
LIBTASN1_INSTALL
mark_package_pass libtasn1-4.20.0 "$LIBTASN1_LOG" "$LIBTASN1_WORK" "$LIBTASN1_BACKUP"

readonly WHICH_WORK="$WORK_PREFIX/which-2.23-$STAMP"
readonly WHICH_SOURCE="$WHICH_WORK/which-2.23"
readonly WHICH_STAGE="$WHICH_WORK/stage"
readonly WHICH_LOG="$WHICH_WORK/package.log"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WHICH_WORK" "$WHICH_SOURCE" "$WHICH_STAGE" "$WHICH_LOG" <<'WHICH_BUILD'
set -Eeuo pipefail
work="$1"; source="$2"; stage="$3"; package_log="$4"
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xzf /sources/which-2.23.tar.gz -C "$work"
[[ -x "$source/configure" ]]
cd "$source"
./configure --prefix=/usr > "$work/configure.log" 2>&1
if make -j4 > "$work/compile.log" 2>&1; then printf 'WHICH_BUILD=PASS\n'; else rc=$?; tail -n 100 "$work/compile.log"; exit "$rc"; fi
mkdir -pv "$stage"
make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1
[[ -x "$stage/usr/bin/which" ]]
printf 'WHICH_STAGED_INSTALL=PASS\n'
WHICH_BUILD
WHICH_BACKUP="$(stage_paths_and_backup which-2.23 "$WHICH_STAGE")" || fail 'Unable to back up pre-existing Which paths.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$WHICH_SOURCE" "$WHICH_LOG" <<'WHICH_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cd "$source"
make -j1 install
[[ "$(which --version | head -n1)" == *"GNU which v2.23"* ]]
[[ "$(which bash)" == /usr/bin/bash ]]
printf 'WHICH_FINAL_INSTALL=PASS\n'
WHICH_INSTALL
mark_package_pass which-2.23 "$WHICH_LOG" "$WHICH_WORK" "$WHICH_BACKUP"

readonly MAKECA_WORK="$WORK_PREFIX/make-ca-1.16.1-$STAMP"
readonly MAKECA_SOURCE="$MAKECA_WORK/make-ca-1.16.1"
readonly MAKECA_STAGE="$MAKECA_WORK/stage"
readonly MAKECA_LOG="$MAKECA_WORK/package.log"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$MAKECA_WORK" "$MAKECA_SOURCE" "$MAKECA_STAGE" "$MAKECA_LOG" <<'MAKECA_BUILD'
set -Eeuo pipefail
work="$1"; source="$2"; stage="$3"; package_log="$4"
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xzf /sources/make-ca-1.16.1.tar.gz -C "$work"
[[ -f "$source/Makefile" && -f "$source/make-ca" && -f "$source/ISRG_Root_X1.pem" ]]
cd "$source"
make -j1 DESTDIR="$stage" install > "$work/staged-install.log" 2>&1
[[ -x "$stage/usr/sbin/make-ca" && -f "$stage/etc/make-ca/ISRG_Root_X1.pem" && -x "$stage/usr/libexec/make-ca/copy-trust-modifications" ]]
printf 'MAKE_CA_STAGED_INSTALL=PASS\n'
MAKECA_BUILD
MAKECA_BACKUP="$(stage_paths_and_backup make-ca-1.16.1 "$MAKECA_STAGE")" || fail 'Unable to back up pre-existing make-ca paths.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$MAKECA_SOURCE" "$MAKECA_LOG" <<'MAKECA_INSTALL'
set -Eeuo pipefail
source="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cd "$source"
make -j1 install
install -vdm755 /etc/ssl/local
[[ "$(/usr/sbin/make-ca --version | head -n1)" == *"make-ca 1.16.1"* ]]
[[ -r /etc/make-ca/ISRG_Root_X1.pem && -x /usr/libexec/make-ca/copy-trust-modifications ]]
printf 'MAKE_CA_FINAL_INSTALL=PASS\n'
MAKECA_INSTALL
mark_package_pass make-ca-1.16.1 "$MAKECA_LOG" "$MAKECA_WORK" "$MAKECA_BACKUP"

readonly P11_WORK="$WORK_PREFIX/p11-kit-0.25.5-$STAMP"
readonly P11_SOURCE="$P11_WORK/p11-kit-0.25.5"
readonly P11_BUILD="$P11_WORK/build"
readonly P11_STAGE="$P11_WORK/stage"
readonly P11_LOG="$P11_WORK/package.log"
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$P11_WORK" "$P11_SOURCE" "$P11_BUILD" "$P11_STAGE" "$P11_LOG" <<'P11_BUILD_STAGE'
set -Eeuo pipefail
work="$1"; source="$2"; build="$3"; stage="$4"; package_log="$5"
mkdir -pv "$work"
exec > >(tee "$package_log") 2>&1
tar -xf /sources/p11-kit-0.25.5.tar.xz -C "$work"
[[ -f "$source/meson.build" && -f "$source/trust/trust-extract-compat" ]]
sed '20,$d' -i "$source/trust/trust-extract-compat"
cat >> "$source/trust/trust-extract-compat" <<'HOOK'
# Copy existing anchor modifications to /etc/ssl/local
/usr/libexec/make-ca/copy-trust-modifications

# Update trust stores
/usr/sbin/make-ca -r
HOOK
mkdir -pv "$build"
meson setup "$build" "$source" --prefix=/usr --buildtype=release -D trust_paths=/etc/pki/anchors > "$work/configure.log" 2>&1
if ninja -C "$build" > "$work/compile.log" 2>&1; then printf 'P11_KIT_BUILD=PASS\n'; else rc=$?; tail -n 120 "$work/compile.log"; exit "$rc"; fi
mkdir -pv "$stage"
DESTDIR="$stage" ninja -C "$build" install > "$work/staged-install.log" 2>&1
ln -s /usr/libexec/p11-kit/trust-extract-compat "$stage/usr/bin/update-ca-certificates"
[[ -f "$stage/usr/lib/libp11-kit.so" && -x "$stage/usr/bin/trust" && -x "$stage/usr/bin/p11-kit" ]]
[[ -f "$stage/usr/lib/pkcs11/p11-kit-trust.so" && -x "$stage/usr/libexec/p11-kit/trust-extract-compat" ]]
printf 'P11_KIT_STAGED_INSTALL=PASS\n'
P11_BUILD_STAGE
P11_BACKUP="$(stage_paths_and_backup p11-kit-0.25.5 "$P11_STAGE")" || fail 'Unable to back up pre-existing p11-kit paths.'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$P11_BUILD" "$P11_LOG" <<'P11_INSTALL'
set -Eeuo pipefail
build="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
ninja -C "$build" install
ln -sfv /usr/libexec/p11-kit/trust-extract-compat /usr/bin/update-ca-certificates
ldconfig
[[ "$(pkg-config --modversion p11-kit-1)" == 0.25.5 ]]
[[ -f /usr/lib/libp11-kit.so && -x /usr/bin/trust && -x /usr/bin/p11-kit ]]
[[ -f /usr/lib/pkcs11/p11-kit-trust.so && -x /usr/libexec/p11-kit/trust-extract-compat ]]
[[ "$(readlink /usr/bin/update-ca-certificates)" == /usr/libexec/p11-kit/trust-extract-compat ]]
readelf -h /usr/bin/trust | grep -F 'Advanced Micro Devices X86-64'
ldd /usr/bin/trust | grep -E 'libc[.]so[.]6.*/usr/lib/'
printf 'P11_KIT_FINAL_INSTALL=PASS\n'
P11_INSTALL
mark_package_pass p11-kit-0.25.5 "$P11_LOG" "$P11_WORK" "$P11_BACKUP"

printf 'Generating the BLFS Mozilla CA stores from retained upstream certdata.txt.\n'
sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
    /bin/bash -s -- "$MAKECA_LOG" <<'MAKECA_STORES'
set -Eeuo pipefail
package_log="$1"
exec > >(tee -a "$package_log") 2>&1
/usr/sbin/make-ca -C /sources/mozilla-nss-certdata.txt
[[ -s /etc/ssl/certdata.txt && -s /etc/pki/tls/certs/ca-bundle.crt ]]
[[ -d /etc/pki/anchors && -d /etc/ssl/certs && -s /etc/pki/anchors.md5sums ]]
[[ "$(grep -c 'BEGIN CERTIFICATE' /etc/pki/tls/certs/ca-bundle.crt)" -gt 50 ]]
printf 'MAKE_CA_CERTIFICATE_STORES=PASS\nCERTIFICATE_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt\n'
MAKECA_STORES
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$MAKECA_LOG" "$LOG_DIR/make-ca-1.16.1-blfs-$STAMP.package.log"
printf 'MAKE_CA_CERTIFICATE_STORE_RESULT=PASS\nPACKAGE_LOG=%s\n' "$LOG_DIR/make-ca-1.16.1-blfs-$STAMP.package.log" > "$LOG_DIR/make-ca-1.16.1-blfs-$STAMP.certificate-store.status"

printf '\nQCA prerequisites installed. No package test suites or source checksum calculations ran.\n'
printf 'Main log: %s\nMain status: %s\nBuild trees: %s\nFinished: %s\n' \
    "$LOG" "$STATUS" "$LFS$WORK_PREFIX" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
