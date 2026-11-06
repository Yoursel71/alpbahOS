#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly ARCHIVE="$LFS/sources/systemd-257.8.tar.gz"
readonly MANPAGES="$LFS/sources/systemd-man-pages-257.8.tar.xz"
readonly WORK_ROOT="/sources/systemd-257.8-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/systemd-257.8"
readonly BUILD_ROOT="$SOURCE_ROOT/build"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/systemd-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/systemd-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/systemd-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/systemd-before-files.tar"
readonly INSTALL_PLAN="$BACKUP_DIR/systemd-installed-paths.json"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"
readonly STATUS="$LOG_DIR/systemd-ch8-$STAMP.status"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA" ]] || fail 'The LFS target or HDD build data directory is missing.'
if [[ -z "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    [[ -d "$DATA/lfs" ]] || fail 'The HDD-backed LFS build directory is missing.'
fi
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
[[ -r "$ARCHIVE" && -r "$MANPAGES" ]] || fail 'The Systemd source or man-page archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Systemd work tree: $WORK_ROOT"
sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '
    [[ "$(pkg-config --modversion pam)" == 1.7.1 ]]
    [[ -f /usr/include/security/pam_appl.h && -f /usr/lib/libpam.so && -f /usr/lib/libpam_misc.so ]]
' || fail 'Linux-PAM 1.7.1 must be installed before the logind rebuild.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/ninja/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

record_result() {
    local result=$?
    if (( result == 0 )); then
        printf 'SYSTEMD_SCRIPT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'SYSTEMD_SCRIPT_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building LFS Chapter 8 Systemd 257.8.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using existing source archives without checksum work. Systemd package tests are skipped per user preference and the LFS page notes known chroot/kernel failures.\n'

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WORK_ROOT" "$SOURCE_ROOT" "$BUILD_ROOT" "$CHROOT_LOG" <<'PREPARE'
set -Eeuo pipefail
work_root="$1"
source_root="$2"
build_root="$3"
build_log="$4"
mkdir -pv "$work_root"
exec > >(tee "$build_log") 2>&1

tar -xzf /sources/systemd-257.8.tar.gz -C "$work_root"
[[ -f "$source_root/rules.d/50-udev-default.rules.in" ]] || {
    printf 'Systemd default udev rules template is missing.\n' >&2
    exit 1
}
sed -e 's/GROUP="render"/GROUP="video"/' \
    -e 's/GROUP="sgx", //' \
    -i "$source_root/rules.d/50-udev-default.rules.in"
mkdir -pv "$build_root"
cd "$build_root"
meson setup .. \
    --prefix=/usr \
    --buildtype=release \
    -D default-dnssec=no \
    -D firstboot=false \
    -D install-tests=false \
    -D ldconfig=false \
    -D sysusers=false \
    -D rpmmacrosdir=no \
    -D homed=disabled \
    -D userdb=false \
    -D man=disabled \
    -D mode=release \
    -D pamconfdir=no \
    -D dev-kvm-mode=0660 \
    -D nobody-group=nogroup \
    -D pam=enabled \
    -D pamconfdir=/usr/lib/pam.d \
    -D sysupdate=disabled \
    -D ukify=disabled \
    -D docdir=/usr/share/doc/systemd-257.8 > "$work_root/configure.log" 2>&1
grep -F 'Run-time dependency pam found: YES' "$work_root/configure.log" >/dev/null
grep -E 'PAM configuration directory *: /usr/lib/pam[.]d' "$work_root/configure.log" >/dev/null
printf 'SYSTEMD_PAM_CONFIGURE=PASS\n'
meson introspect --installed "$build_root" > "$work_root/meson-installed-paths.json"
[[ -s "$work_root/meson-installed-paths.json" ]]
printf 'SYSTEMD_MESON_SETUP=PASS\nSYSTEMD_INSTALL_PLAN=%s/meson-installed-paths.json\n' "$work_root"
PREPARE

sudo -n chown "$(id -u):$(id -g)" "$LFS$WORK_ROOT/meson-installed-paths.json"
cp "$LFS$WORK_ROOT/meson-installed-paths.json" "$INSTALL_PLAN"
tar -tJf "$MANPAGES" > "$BACKUP_DIR/man-pages-archive.list"
python3 - "$LFS" "$INSTALL_PLAN" "$MANPAGES" "$MANIFEST0" <<'PY'
import json
import os
import sys
import tarfile

root, plan_path, manpages_path, output_path = sys.argv[1:]
with open(plan_path, encoding="utf-8") as stream:
    plan = json.load(stream)
if not isinstance(plan, dict):
    raise SystemExit("Meson installed-path plan is not a JSON object")

destinations = set()
for source, destination in plan.items():
    if not isinstance(destination, str) or not destination.startswith("/"):
        raise SystemExit(f"Unexpected Meson install destination: {source!r} -> {destination!r}")
    destinations.add(destination)

with tarfile.open(manpages_path, "r:xz") as archive:
    for member in archive.getmembers():
        if not (member.isfile() or member.issym() or member.islnk()):
            continue
        parts = member.name.split("/", 1)
        if len(parts) != 2 or not parts[1].startswith("man"):
            continue
        destinations.add("/usr/share/man/" + parts[1])

# These paths can be changed by the LFS post-install machine-id and preset steps.
destinations.update({
    "/etc/machine-id", "/var/lib/dbus/machine-id", "/etc/systemd",
    "/etc/udev", "/etc/init.d", "/etc/binfmt.d", "/etc/kernel",
    "/etc/modules-load.d", "/etc/sysctl.d", "/etc/tmpfiles.d",
    "/etc/xdg/systemd", "/usr/lib/systemd", "/usr/lib/udev",
    "/usr/share/systemd", "/usr/share/factory", "/usr/share/doc/systemd-257.8",
    "/usr/include/systemd", "/usr/lib/binfmt.d", "/usr/lib/environment.d",
    "/usr/lib/kernel", "/usr/lib/modules-load.d", "/usr/lib/sysctl.d",
    "/usr/lib/tmpfiles.d", "/var/lib/systemd", "/var/log/journal",
})

existing = []
for destination in destinations:
    normalized = os.path.normpath(destination)
    if not normalized.startswith("/") or normalized == "/" or ".." in normalized.split("/"):
        raise SystemExit(f"Unsafe package target path: {destination!r}")
    relative = normalized.lstrip("/")
    if os.path.lexists(os.path.join(root, relative)):
        existing.append(relative)

with open(output_path, "wb") as stream:
    for relative in sorted(set(existing)):
        stream.write(os.fsencode(relative) + b"\0")
print(f"Meson and man-page targets: {len(destinations)}; pre-existing paths to archive: {len(set(existing))}")
PY
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Systemd pre-install backup archive is empty.'
    printf 'Existing Systemd-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Systemd install targets were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
fi
printf 'Pre-existing path count: %s\n' "$(wc -l < "$MANIFEST")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$BUILD_ROOT" "$CHROOT_LOG" <<'BUILD'
set -Eeuo pipefail
build_root="$1"
build_log="$2"
exec > >(tee -a "$build_log") 2>&1
cd "$build_root"

if ninja -j4 > compile.log 2>&1; then
    printf 'SYSTEMD_BUILD_RESULT=PASS\n'
else
    result=$?
    printf 'SYSTEMD_BUILD_RESULT=FAIL exit=%s\n' "$result"
    tail -n 120 compile.log
    exit "$result"
fi
ninja install
tar -xf /sources/systemd-man-pages-257.8.tar.xz \
    --no-same-owner --strip-components=1 -C /usr/share/man
systemd-machine-id-setup
systemctl preset-all

[[ "$(systemctl --version | sed -n '1p')" == 'systemd 257 (257.8)' ]]
[[ "$(udevadm --version)" == '257' ]]
for command in systemd systemctl journalctl systemd-analyze systemd-machine-id-setup \
    systemd-tmpfiles systemd-udevd udevadm busctl networkctl timedatectl; do
    [[ -x "/usr/bin/$command" || -x "/usr/lib/systemd/$command" || -x "/usr/lib/udev/$command" ]] || {
        printf 'Missing Systemd command: %s\n' "$command" >&2
        exit 1
    }
done
[[ -f /usr/lib/libsystemd.so ]]
[[ -f /usr/lib/libudev.so ]]
[[ -f /usr/lib/security/pam_systemd.so ]]
[[ -f /usr/lib/pam.d/systemd-user ]]
[[ "$(pkg-config --modversion pam)" == 1.7.1 ]]
[[ -d /usr/lib/systemd/system ]]
[[ -f /usr/share/man/man1/systemctl.1 ]]
[[ -f /usr/share/man/man5/systemd.service.5 ]]
[[ -s /etc/machine-id ]]
machine_id="$(cat /etc/machine-id)"
[[ "$machine_id" =~ ^[[:xdigit:]]{32}$ && "$machine_id" != 00000000000000000000000000000000 ]]
readelf -h /usr/bin/systemctl | grep -F 'Advanced Micro Devices X86-64'
ldd /usr/bin/systemctl | grep -E 'libc[.]so[.]6.*[/]usr/lib/'
printf 'SYSTEMD_FINAL_INSTALL=PASS\nSYSTEMD_PAM=PASS\nSYSTEMD_MACHINE_ID=SET\n'
BUILD

printf '\nSystemd Chapter 8 build/install completed; the package test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nStatus: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
