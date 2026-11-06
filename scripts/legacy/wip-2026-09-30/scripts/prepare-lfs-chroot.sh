#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly ROOT_ID="$(stat -c '%d:%i' "$LFS")"
readonly DATA_ID="$(stat -c '%d:%i' "$DATA/lfs")"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" == 0 ]] || fail 'Run this host preparation script as root.'
[[ "$(findmnt -n -o FSTYPE -T "$LFS")" == ext4 ]] || fail "$LFS is not on ext4."
[[ "$ROOT_ID" == "$DATA_ID" ]] || fail "$LFS is not the expected HDD build directory."
[[ -x "$LFS/usr/bin/bash" && -x "$LFS/usr/bin/env" && -x "$LFS/usr/bin/gcc" ]] || fail 'Chapter 6 Bash, Coreutils, or GCC Pass 2 is missing.'
[[ -x "$LFS/usr/bin/g++" && -x "$LFS/usr/bin/tar" ]] || fail 'Chapter 6 C++ compiler or Tar is missing.'
[[ ! -e "$LFS/usr/lib64" && ! -L "$LFS/usr/lib64" ]] || fail 'LFS requires /usr/lib64 to be absent.'

for dir in usr var etc tools; do
    [[ -d "$LFS/$dir" ]] || fail "Required LFS directory is missing: $LFS/$dir"
done

printf 'Changing only Chapter 7 LFS paths from lfs ownership to root.\n'
chown --from=lfs -R root:root "$LFS"/{usr,var,etc,tools}
case "$(uname -m)" in
    x86_64) chown --from=lfs -R root:root "$LFS/lib64" ;;
esac

mkdir -pv "$LFS"/{dev,proc,sys,run}

ensure_mount() {
    local target="$1" fstype="$2" source="$3" options="${4:-}"
    if mountpoint -q "$target"; then
        local current_type
        current_type="$(findmnt -n -o FSTYPE -M "$target")"
        [[ "$current_type" == "$fstype" ]] || fail "Unexpected existing filesystem at $target: $current_type"
        printf 'Keeping existing %s mount at %s.\n' "$fstype" "$target"
        return
    fi
    if [[ -n "$options" ]]; then
        mount -v -t "$fstype" -o "$options" "$source" "$target"
    else
        mount -v -t "$fstype" "$source" "$target"
    fi
}

if ! mountpoint -q "$LFS/dev"; then
    mount -v --bind /dev "$LFS/dev"
else
    [[ "$(findmnt -n -o MAJ:MIN -M "$LFS/dev")" == "$(findmnt -n -o MAJ:MIN -M /dev)" ]] || fail "Unexpected existing mount at $LFS/dev"
    printf 'Keeping existing /dev bind mount.\n'
fi

ensure_mount "$LFS/dev/pts" devpts devpts 'gid=5,mode=0620'
ensure_mount "$LFS/proc" proc proc
ensure_mount "$LFS/sys" sysfs sysfs
ensure_mount "$LFS/run" tmpfs tmpfs

if [[ -h /dev/shm ]]; then
    install -d -m 1777 "$LFS$(realpath /dev/shm)"
else
    ensure_mount "$LFS/dev/shm" tmpfs tmpfs 'nosuid,nodev'
fi

printf '\nLFS virtual filesystems are ready:\n'
findmnt -R "$LFS"

printf '\nPreparing essential Chapter 7 files inside chroot.\n'
chroot "$LFS" /usr/bin/env -i \
    HOME=/root \
    TERM="${TERM:-linux}" \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    MAKEFLAGS=-j4 \
    TESTSUITEFLAGS=-j4 \
    /bin/bash --login -s < "$SCRIPT_DIR/lfs-chapter7-base-in-chroot.sh"

printf '\nChapter 7 base prepared in %s.\n' "$LFS"
