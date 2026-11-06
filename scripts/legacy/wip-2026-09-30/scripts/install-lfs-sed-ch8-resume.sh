#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly WORK_ROOT=/sources/sed-4.9-ch8-20260927T001220069007828Z
readonly SOURCE_ROOT="$WORK_ROOT/sed-4.9"
readonly BACKUP_ARCHIVE="$DATA/backups/sed-pass2-before-final-20260927T001220069007828Z/sed-pass2-files.tar"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly LOG="$LOG_DIR/sed-ch8-install-resume-$STAMP.log"
readonly CHROOT_LOG="$WORK_ROOT/sed-install-resume.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA/lfs" ]] || fail 'The LFS target or HDD build directory is missing.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
[[ -f "$LFS$SOURCE_ROOT/Makefile" && -f "$LFS$SOURCE_ROOT/doc/sed.html" ]] || fail 'The completed Sed build or HTML documentation is missing.'
[[ -s "$BACKUP_ARCHIVE" ]] || fail 'The Pass 2 Sed backup is missing.'
[[ -x "$LFS/usr/bin/sed" ]] || fail 'The current Sed executable is missing.'
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
exec 9>"$DATA/locks/lfs-build-writer.lock"
flock -n 9 || fail 'Another LFS writer holds the build lock.'
exec > >(tee "$LOG") 2>&1

printf 'Resuming LFS Sed 4.9 install sequentially after parallel install commands raced with the /usr/bin/sed replacement.\n'
printf 'Build tree: %s\nStarted: %s\n\n' "$SOURCE_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j1 \
    /bin/bash -s -- "$SOURCE_ROOT" "$CHROOT_LOG" <<'CHROOT'
set -Eeuo pipefail
source_root="$1"
install_log="$2"
mkdir -p "$(dirname "$install_log")"
exec > >(tee "$install_log") 2>&1
cd "$source_root"
make -j1 install
install -d -m755 /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9
/usr/bin/sed --version | head -n 1
[[ -s /usr/share/doc/sed-4.9/sed.html ]]
printf 'SED_SERIAL_INSTALL=PASS\n'
CHROOT

printf '\nSequential Sed install completed.\nInstall log: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
