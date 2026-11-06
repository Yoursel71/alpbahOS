#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly VERSION=6.9.2
readonly ARCHIVE="qtbase-everywhere-src-$VERSION.tar.xz"
readonly URL="https://download.qt.io/archive/qt/6.9/6.9.2/submodules/$ARCHIVE"
readonly WORK_ROOT="/sources/qtbase-$VERSION-wayland-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/qtbase-everywhere-src-$VERSION"
readonly BUILD_ROOT="$WORK_ROOT/build"
readonly STAGE_ROOT="$WORK_ROOT/stage"
readonly PACKAGE_LOG_INSIDE="$WORK_ROOT/package.log"
readonly LOG_DIR="$DATA/logs/blfs-12.4-systemd"
readonly LOG="$LOG_DIR/qtbase-$VERSION-wayland-$STAMP.log"
readonly STATUS="$LOG_DIR/qtbase-$VERSION-wayland-$STAMP.status"
readonly PACKAGE_STATUS="$LOG_DIR/qtbase-$VERSION-wayland-$STAMP.package.status"
readonly BACKUP_DIR="$DATA/backups/qtbase-before-final-$STAMP"
readonly ARCHIVE_PATH="$LFS/sources/qt/$ARCHIVE"
readonly TEMP_DOWNLOAD="$DATA/downloads/$ARCHIVE.part-$STAMP"
readonly STAGED0="$BACKUP_DIR/staged-paths.list0"
readonly EXISTING0="$BACKUP_DIR/preexisting-paths.list0"
readonly CONFIG_EXISTING0="$BACKUP_DIR/preexisting-qt-config.list0"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "ninja" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/ninja/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$DATA/backups" "$DATA/downloads" "$(dirname "$ARCHIVE_PATH")"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1
record_result() {
    local result=$?
    if (( result == 0 )); then
        printf 'BLFS_QTBASE_WAYLAND_RESULT=PASS\nLOG=%s\n' "$LOG" > "$STATUS"
    else
        printf 'BLFS_QTBASE_WAYLAND_RESULT=FAIL exit=%s\nLOG=%s\n' "$result" "$LOG" > "$STATUS"
    fi
}
trap record_result EXIT

printf 'Building QtBase %s for the alpbahOS Wayland stack.\n' "$VERSION"
printf 'Prefix /opt/qt6; XCB/X11 and examples disabled; linked D-Bus/OpenSSL, system SQLite, journald enabled.\n'
printf 'The BLFS full Qt meta build is avoided; this is QtBase only. Package tests/checksum work are skipped.\n'
printf 'Target: %s\nStarted: %s\n' "$LFS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
if [[ ! -r "$ARCHIVE_PATH" ]]; then
    curl --fail --location --retry 3 --output "$TEMP_DOWNLOAD" "$URL"
    sudo -n install -o 0 -g 0 -m 0644 "$TEMP_DOWNLOAD" "$ARCHIVE_PATH"
    rm -f "$TEMP_DOWNLOAD"
else
    printf 'Using existing QtBase source archive: %s\n' "$ARCHIVE_PATH"
fi
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite isolated build tree $WORK_ROOT"
mkdir -p "$BACKUP_DIR"

if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$ARCHIVE" "$WORK_ROOT" "$SOURCE_ROOT" "$BUILD_ROOT" "$STAGE_ROOT" "$PACKAGE_LOG_INSIDE" <<'CHROOT'
set -Eeuo pipefail
archive="$1"; work_root="$2"; source_root="$3"; build_root="$4"; stage_root="$5"; package_log="$6"
mkdir -pv "$work_root"
exec > >(tee "$package_log") 2>&1
tar -xf "/sources/qt/$archive" -C "$work_root"
[[ -d "$source_root" && -x "$source_root/configure" ]] || { printf 'Expected QtBase configure tree missing: %s\n' "$source_root" >&2; exit 1; }
mkdir -pv "$build_root"
cd "$build_root"
if ../qtbase-everywhere-src-6.9.2/configure \
    -opensource -confirm-license \
    -prefix /opt/qt6 -sysconfdir /etc/xdg \
    -dbus-linked -openssl-linked -system-sqlite -journald \
    -nomake examples -no-rpath -no-sbom -no-xcb \
    > "$work_root/configure.log" 2>&1; then
    printf 'QTBASE_CONFIGURE=PASS\n'
else
    result=$?; tail -n 180 "$work_root/configure.log"; exit "$result"
fi
if ninja -j4 > "$work_root/compile.log" 2>&1; then
    printf 'QTBASE_BUILD=PASS\n'
else
    result=$?; tail -n 180 "$work_root/compile.log"; exit "$result"
fi
mkdir -pv "$stage_root"
DESTDIR="$stage_root" cmake --install . > "$work_root/staged-install.log" 2>&1
[[ -x "$stage_root/opt/qt6/bin/qmake6" && -f "$stage_root/opt/qt6/lib/libQt6Core.so.6" ]]
[[ -f "$stage_root/opt/qt6/lib/libQt6Gui.so.6" && -f "$stage_root/opt/qt6/lib/libQt6DBus.so.6" ]]
printf 'STAGED_INSTALL=PASS\n'
CHROOT
then
    if sudo -n test -f "$LFS$PACKAGE_LOG_INSIDE"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"; fi
    printf 'QTBASE_RESULT=FAIL_BUILD_OR_STAGE\nLOG=%s\n' "$LOG" > "$PACKAGE_STATUS"
    fail "QtBase build or staged install failed; see $LOG"
fi
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"

sudo -n find "$LFS$STAGE_ROOT" \( -type f -o -type l \) -printf '%P\0' | sort -zu > "$STAGED0"
python3 - "$LFS" "$STAGED0" "$EXISTING0" <<'PY'
import os, sys
root, staged_path, existing_path = sys.argv[1:]
with open(staged_path, "rb") as stream:
    staged = [path for path in stream.read().split(b"\0") if path]
existing = []
for raw in staged:
    relative = os.fsdecode(raw)
    if os.path.isabs(relative) or ".." in relative.split("/"):
        raise SystemExit(f"Unsafe staged target: {relative!r}")
    if os.path.lexists(os.path.join(root, relative)):
        existing.append(raw)
with open(existing_path, "wb") as stream:
    for raw in sorted(set(existing)):
        stream.write(raw + b"\0")
print(f"Staged QtBase files/symlinks: {len(staged)}; pre-existing paths: {len(set(existing))}")
PY
if [[ -s "$EXISTING0" ]]; then
    sudo -n tar --create --file="$BACKUP_DIR/preexisting-files.tar" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$EXISTING0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_DIR/preexisting-files.tar"
    sudo -n tar --list --file="$BACKUP_DIR/preexisting-files.tar" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'QtBase pre-install backup is empty.'
    printf 'Existing QtBase target backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_DIR/preexisting-files.tar")"
else
    printf 'No pre-existing QtBase files; no package backup was needed.\n'
fi

for path in etc/ld.so.conf.d/qt6.conf etc/profile.d/qt6.sh; do
    if sudo -n test -e "$LFS/$path"; then printf '%s\0' "$path" >> "$CONFIG_EXISTING0"; fi
done
if [[ -s "$CONFIG_EXISTING0" ]]; then
    sudo -n tar --create --file="$BACKUP_DIR/preexisting-qt-config.tar" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$CONFIG_EXISTING0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_DIR/preexisting-qt-config.tar"
    sudo -n tar --list --file="$BACKUP_DIR/preexisting-qt-config.tar" > "$BACKUP_DIR/qt-config-archive.list"
    [[ -s "$BACKUP_DIR/qt-config-archive.list" ]] || fail 'Qt environment config backup is empty.'
fi

if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$BUILD_ROOT" "$PACKAGE_LOG_INSIDE" <<'INSTALL'
set -Eeuo pipefail
build_root="$1"; package_log="$2"
exec > >(tee -a "$package_log") 2>&1
cmake --install "$build_root"
install -d -m 0755 /etc/ld.so.conf.d /etc/profile.d
cat > /etc/ld.so.conf.d/qt6.conf <<'EOF'
/opt/qt6/lib
EOF
cat > /etc/profile.d/qt6.sh <<'EOF'
QT6DIR=/opt/qt6
export QT6DIR
PATH="$QT6DIR/bin:$PATH"
PKG_CONFIG_PATH="$QT6DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PATH PKG_CONFIG_PATH
EOF
ldconfig
[[ "$(qmake6 -query QT_VERSION)" == 6.9.2 ]]
[[ -f /opt/qt6/lib/libQt6Core.so.6 && -f /opt/qt6/lib/libQt6Gui.so.6 ]]
[[ -f /opt/qt6/lib/libQt6DBus.so.6 && -f /opt/qt6/lib/libQt6Sql.so.6 ]]
printf 'QTBASE_FINAL_INSTALL=PASS\n'
INSTALL
then
    if sudo -n test -f "$LFS$PACKAGE_LOG_INSIDE"; then sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"; fi
    printf 'QTBASE_RESULT=FAIL_FINAL_INSTALL\nLOG=%s\n' "$LOG" > "$PACKAGE_STATUS"
    fail "QtBase final install or verification failed; see $LOG"
fi
sudo -n install -o "$(id -u)" -g "$(id -g)" -m 0644 "$LFS$PACKAGE_LOG_INSIDE" "$LOG"
printf 'QTBASE_RESULT=PASS\nLOG=%s\nBUILD_TREE=%s\nBACKUP_DIR=%s\n' "$LOG" "$LFS$WORK_ROOT" "$BACKUP_DIR" > "$PACKAGE_STATUS"
printf '\nQtBase %s build/install passed; Wayland/XKB/SQLite integration enabled where detected, XCB disabled; no package test or smoke suite ran.\n' "$VERSION"
printf 'Build tree: %s\nHost log: %s\nStatus: %s\nFinished: %s\n' "$LFS$WORK_ROOT" "$LOG" "$STATUS" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
