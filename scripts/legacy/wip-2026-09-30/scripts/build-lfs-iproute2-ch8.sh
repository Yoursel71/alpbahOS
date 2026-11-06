#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/iproute2-6.16.0-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/iproute2-6.16.0"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/iproute2-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/iproute2-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/iproute2-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/iproute2-before-files.tar"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"

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
[[ -r "$LFS/sources/iproute2-6.16.0.tar.xz" ]] || fail 'The IPRoute2 6.16.0 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous IPRoute2 work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 IPRoute2 6.16.0.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The IPRoute2 package has no working test suite.\n'
printf 'The unused arpd man-page source will be preserved; the man Makefile will exclude it from installation.\n'

(
    cd "$LFS"
    command_names=(bridge ctstat genl ifstat ip lnstat nstat routel rtacct rtmon rtstat ss tc)
    for name in "${command_names[@]}"; do
        if [[ -e "usr/sbin/$name" || -L "usr/sbin/$name" ]]; then printf 'usr/sbin/%s\0' "$name"; fi
    done
    while IFS= read -r source_file; do
        case "$source_file" in
            iproute2-6.16.0/man/man[378]/*.[378])
                relative_path="${source_file#iproute2-6.16.0/}"
                target_path="usr/share/$relative_path"
                if [[ -e "$target_path" || -L "$target_path" ]]; then printf '%s\0' "$target_path"; fi
                ;;
        esac
    done < <(tar -tJf "$LFS/sources/iproute2-6.16.0.tar.xz")
    for path in usr/share/iproute2 usr/include/iproute2 usr/lib/tc \
        usr/share/bash-completion/completions/tc usr/share/bash-completion/completions/devlink \
        usr/share/doc/iproute2-6.16.0; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The IPRoute2 backup archive is empty.'
    printf 'Existing IPRoute2-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing IPRoute2 files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
fi
printf 'Pre-existing path count: %s\n' "$(wc -l < "$MANIFEST")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WORK_ROOT" "$SOURCE_ROOT" "$CHROOT_LOG" <<'CHROOT'
set -Eeuo pipefail
work_root="$1"
source_root="$2"
build_log="$3"
mkdir -pv "$work_root"
exec > >(tee "$build_log") 2>&1

tar -xJf /sources/iproute2-6.16.0.tar.xz -C "$work_root"
[[ -f "$source_root/Makefile" && -f "$source_root/man/man8/Makefile" ]] || {
    printf 'IPRoute2 makefiles are missing.\n' >&2
    exit 1
}
cd "$source_root"
sed -i /ARPD/d Makefile
sed -i 's|^MAN8PAGES = .*|MAN8PAGES = $(TARGETS) $(filter-out $(TARGETS) arpd.8,$(wildcard *.8))|' man/man8/Makefile
make NETNS_RUN_DIR=/run/netns
make SBINDIR=/usr/sbin install
install -vDm644 COPYING README* -t /usr/share/doc/iproute2-6.16.0

[[ "$(/usr/sbin/ip -Version)" == 'ip utility, iproute2-6.16.0' ]]
[[ "$(/usr/sbin/tc -V)" == 'tc utility, iproute2-6.16.0' ]]
for command in bridge ctstat genl ifstat ip lnstat nstat routel rtacct rtmon rtstat ss tc; do
    [[ -x "/usr/sbin/$command" ]] || { printf 'Missing IPRoute2 command: %s\n' "$command" >&2; exit 1; }
done
[[ -d /usr/share/iproute2 && -d /usr/lib/tc && -f /usr/include/iproute2/bpf_elf.h ]]
[[ -f /usr/share/doc/iproute2-6.16.0/COPYING ]]
[[ -f /usr/share/bash-completion/completions/tc ]]
[[ -f /usr/share/bash-completion/completions/devlink ]]
[[ -f /usr/share/iproute2/rt_tables ]]
[[ ! -e /usr/sbin/rtpr && ! -e /usr/bin/rtpr ]]
[[ -f man/man8/arpd.8 ]]
[[ ! -e /usr/share/man/man8/arpd.8 && ! -L /usr/share/man/man8/arpd.8 ]]
printf 'IPROUTE2_FINAL_INSTALL=PASS\nIPROUTE2_WORK_TREE=%s\nARPD_SOURCE_PRESERVED=YES\n' "$source_root"
CHROOT

printf '\nIPRoute2 Chapter 8 build/install completed; its non-working test suite was skipped.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
