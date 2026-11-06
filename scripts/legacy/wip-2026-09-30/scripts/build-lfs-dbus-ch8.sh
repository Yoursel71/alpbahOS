#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly ARCHIVE="$LFS/sources/dbus-1.16.2.tar.xz"
readonly WORK_ROOT="/sources/dbus-1.16.2-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/dbus-1.16.2"
readonly BUILD_ROOT="$SOURCE_ROOT/build"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/dbus-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/dbus-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/dbus-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/dbus-before-files.tar"
readonly INSTALL_PLAN="$BACKUP_DIR/dbus-installed-paths.json"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"
readonly STATUS="$LOG_DIR/dbus-ch8-$STAMP.status"

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
[[ -r "$ARCHIVE" ]] || fail 'The D-Bus 1.16.2 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous D-Bus work tree: $WORK_ROOT"
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
        printf 'DBUS_SCRIPT_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'DBUS_SCRIPT_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building LFS Chapter 8 D-Bus 1.16.2.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work. The package test suite is skipped per user preference; Meson wrap fallback is disabled.\n'

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

tar -xJf /sources/dbus-1.16.2.tar.xz -C "$work_root"
[[ -f "$source_root/meson.build" ]] || { printf 'D-Bus meson.build is missing.\n' >&2; exit 1; }
mkdir -pv "$build_root"
meson setup "$build_root" "$source_root" \
    --prefix=/usr --buildtype=release --wrap-mode=nofallback \
    > "$work_root/configure.log" 2>&1
meson introspect --installed "$build_root" > "$work_root/meson-installed-paths.json"
[[ -s "$work_root/meson-installed-paths.json" ]]
printf 'DBUS_MESON_SETUP=PASS\n'
PREPARE

sudo -n chown "$(id -u):$(id -g)" "$LFS$WORK_ROOT/meson-installed-paths.json"
cp "$LFS$WORK_ROOT/meson-installed-paths.json" "$INSTALL_PLAN"
python3 - "$LFS" "$INSTALL_PLAN" "$MANIFEST0" <<'PY'
import json
import os
import sys

root, plan_path, output_path = sys.argv[1:]
with open(plan_path, encoding="utf-8") as stream:
    plan = json.load(stream)
if not isinstance(plan, dict):
    raise SystemExit("Meson installed-path plan is not a JSON object")

destinations = set(plan.values())
destinations.update({"/var/lib/dbus", "/var/lib/dbus/machine-id"})
existing = []
for destination in destinations:
    if not isinstance(destination, str) or not destination.startswith("/"):
        raise SystemExit(f"Unexpected Meson install destination: {destination!r}")
    normalized = os.path.normpath(destination)
    if normalized == "/" or ".." in normalized.split("/"):
        raise SystemExit(f"Unsafe D-Bus target path: {destination!r}")
    relative = normalized.lstrip("/")
    if os.path.lexists(os.path.join(root, relative)):
        existing.append(relative)

with open(output_path, "wb") as stream:
    for relative in sorted(set(existing)):
        stream.write(os.fsencode(relative) + b"\0")
print(f"Meson install targets: {len(destinations)}; pre-existing paths to archive: {len(set(existing))}")
PY
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The D-Bus pre-install backup archive is empty.'
    printf 'Existing D-Bus-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing D-Bus install targets were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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
    printf 'DBUS_BUILD_RESULT=PASS\n'
else
    result=$?
    printf 'DBUS_BUILD_RESULT=FAIL exit=%s\n' "$result"
    tail -n 100 compile.log
    exit "$result"
fi
ninja install
mkdir -p /var/lib/dbus
ln -sfn /etc/machine-id /var/lib/dbus/machine-id

/usr/bin/dbus-daemon --version | grep -F '1.16.2'
for command in dbus-cleanup-sockets dbus-daemon dbus-launch dbus-monitor \
    dbus-run-session dbus-send dbus-test-tool dbus-update-activation-environment dbus-uuidgen; do
    [[ -x "/usr/bin/$command" ]] || { printf 'Missing D-Bus command: %s\n' "$command" >&2; exit 1; }
done
[[ -f /usr/lib/libdbus-1.so ]]
[[ -f /etc/dbus-1/system.conf ]]
[[ -d /usr/share/dbus-1 ]]
[[ -L /var/lib/dbus/machine-id && "$(readlink /var/lib/dbus/machine-id)" == /etc/machine-id ]]
readelf -h /usr/bin/dbus-daemon | grep -F 'Advanced Micro Devices X86-64'
ldd /usr/bin/dbus-daemon | grep -E 'libc[.]so[.]6.*[/]usr/lib/'
printf 'DBUS_FINAL_INSTALL=PASS\n'
BUILD

printf '\nD-Bus Chapter 8 build/install completed; the package test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nStatus: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
