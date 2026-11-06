#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/grub-2.12-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/grub-2.12"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/grub-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/grub-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/grub-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/grub-before-files.tar"
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
[[ -r "$LFS/sources/grub-2.12.tar.xz" ]] || fail 'The GRUB 2.12 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous GRUB work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 GRUB 2.12 package for the target root only.\n'
printf 'No boot disk or EFI system partition will be modified.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The LFS book does not recommend the GRUB test suite; it is skipped.\n'

(
    cd "$LFS"
    command_names=(
        grub-bios-setup grub-editenv grub-file grub-fstest grub-glue-efi grub-install grub-kbdcomp grub-macbless
        grub-menulst2cfg grub-mkconfig grub-mkimage grub-mklayout grub-mknetdir grub-mkpasswd-pbkdf2 grub-mkrelpath
        grub-mkrescue grub-mkstandalone grub-ofpathname grub-probe grub-reboot grub-render-label grub-script-check
        grub-set-default grub-sparc64-setup grub-syslinux2cfg
    )
    sbin_commands=(
        grub-bios-setup grub-install grub-macbless grub-mkconfig grub-ofpathname grub-probe grub-reboot
        grub-set-default grub-sparc64-setup
    )
    for name in "${command_names[@]}"; do
        if [[ " ${sbin_commands[*]} " == *" $name "* ]]; then program_path="usr/sbin/$name"; else program_path="usr/bin/$name"; fi
        if [[ -e "$program_path" || -L "$program_path" ]]; then printf '%s\0' "$program_path"; fi
        for man_section in usr/share/man/man[0-9]*; do
            [[ -d "$man_section" ]] || continue
            section_number="${man_section##*/man}"
            path="$man_section/$name.$section_number"
            if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
        done
    done
    for path in etc/grub.d etc/default/grub etc/bash_completion.d/grub \
        usr/share/bash-completion/completions/grub usr/lib/grub usr/share/grub \
        usr/share/doc/grub-2.12 usr/share/info/grub.info usr/share/info/grub.info-1 \
        usr/share/info/grub.info-2 usr/share/info/grub-dev.info usr/share/info/dir; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    find usr/share/locale \( -type f -o -type l \) -path '*/LC_MESSAGES/grub.mo' -print0
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The GRUB backup archive is empty.'
    printf 'Existing GRUB-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing GRUB files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
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

tar -xJf /sources/grub-2.12.tar.xz -C "$work_root"
[[ -f "$source_root/configure" ]] || { printf 'GRUB configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
printf 'depends bli part_gpt\n' > grub-core/extra_deps.lst
unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --disable-efiemu \
    --disable-werror
make
make install
if [[ -e /usr/share/bash-completion/completions/grub || -L /usr/share/bash-completion/completions/grub ]]; then
    printf 'GRUB completion destination already exists; preserving it rather than overwriting.\n'
    [[ -f /usr/share/bash-completion/completions/grub ]]
    [[ ! -e /etc/bash_completion.d/grub && ! -L /etc/bash_completion.d/grub ]]
else
    mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
fi

grub_version="$(/usr/sbin/grub-install --version)"
printf '%s\n' "$grub_version"
[[ "$grub_version" == *'grub-install (GRUB) 2.12' ]]
for command in grub-install grub-mkconfig grub-probe; do
    [[ -x "/usr/sbin/$command" ]] || { printf 'Missing GRUB command: %s\n' "$command" >&2; exit 1; }
done
for command in grub-mkimage grub-script-check grub-editenv grub-file; do
    [[ -x "/usr/bin/$command" ]] || { printf 'Missing GRUB command: %s\n' "$command" >&2; exit 1; }
done
[[ -d /usr/lib/grub && -d /etc/grub.d && -d /usr/share/grub ]]
[[ -f /usr/share/bash-completion/completions/grub ]]
printf 'GRUB_FINAL_INSTALL=PASS\nGRUB_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nGRUB Chapter 8 build/install completed in the LFS target root; the boot device was not touched.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
