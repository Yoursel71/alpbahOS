#!/usr/bin/env bash
# Shared target and writer-lock guard for LFS Chapter 8 host orchestrators.
# Ordinary builds retain the historical HDD/ext4 identity check. D34 mode is
# enabled only when the caller inherits the already-locked writer FD and names
# the exact Btrfs mount/subvolume identity prepared by the transaction runner.

lfs_guard_die() {
    printf 'ERROR: LFS build guard: %s\n' "$*" >&2
    exit 1
}

lfs_d34_verify_lock_fd() {
    local data_root="$1" fd="${ALPBAHOS_D34_LOCK_FD:-}" lock_path expected_path actual_path
    [[ "$fd" =~ ^[0-9]+$ ]] || lfs_guard_die 'D34 mode requires an inherited lock file descriptor.'
    lock_path="$data_root/locks/lfs-build-writer.lock"
    [[ -f "$lock_path" && ! -L "$lock_path" ]] || lfs_guard_die "invalid lock file: $lock_path"
    [[ -e "/proc/$$/fd/$fd" ]] || lfs_guard_die "inherited lock descriptor $fd is not open."
    expected_path="$(realpath -e -- "$lock_path")"
    actual_path="$(readlink -e -- "/proc/$$/fd/$fd" 2>/dev/null || true)"
    [[ "$actual_path" == "$expected_path" ]] || lfs_guard_die 'inherited descriptor does not refer to the LFS writer lock.'
    flock -n "$fd" || lfs_guard_die 'inherited descriptor is not holding the exclusive LFS writer lock.'
}

lfs_d34_verify_target() {
    local root="$1" data_root="$2" fs_uuid mount_id root_identity subvolume_text subvolume_uuid subvolume_id
    lfs_d34_verify_lock_fd "$data_root"
    [[ "$root" == /mnt/lfs && -d "$root" && ! -L "$root" ]] || lfs_guard_die 'D34 target must be the real /mnt/lfs mountpoint.'
    [[ "$(realpath -e -- "$root")" == "$root" ]] || lfs_guard_die 'D34 target path does not resolve to /mnt/lfs.'
    [[ "$(findmnt -n -o FSTYPE -T "$root")" == btrfs ]] || lfs_guard_die 'D34 target is not on Btrfs.'

    fs_uuid="$(findmnt -n -o UUID -T "$root")"
    [[ "$fs_uuid" == "${ALPBAHOS_D34_FS_UUID:-}" ]] || lfs_guard_die 'D34 filesystem UUID mismatch.'
    mount_id="$(findmnt -n -o ID -T "$root")"
    [[ "$mount_id" == "${ALPBAHOS_D34_MOUNT_ID:-}" ]] || lfs_guard_die 'D34 target mount ID mismatch.'
    root_identity="$(stat -Lc '%d:%i' -- "$root")"
    [[ "$root_identity" == "${ALPBAHOS_D34_ROOT_DEVICE_INODE:-}" ]] || lfs_guard_die 'D34 target device/inode mismatch.'

    subvolume_text="$(sudo -n btrfs subvolume show "$root")" || lfs_guard_die 'cannot inspect D34 target subvolume.'
    subvolume_uuid="$(awk -F: '/^[[:space:]]*UUID:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' <<<"$subvolume_text")"
    subvolume_id="$(awk -F: '/^[[:space:]]*Subvolume ID:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' <<<"$subvolume_text")"
    [[ "$subvolume_uuid" == "${ALPBAHOS_D34_SUBVOL_UUID:-}" ]] || lfs_guard_die 'D34 target subvolume UUID mismatch.'
    [[ "$subvolume_id" == "${ALPBAHOS_D34_SUBVOL_ID:-}" ]] || lfs_guard_die 'D34 target subvolume ID mismatch.'
}

lfs_validate_target() {
    local root="$1" data_root="$2"
    if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
        lfs_d34_verify_target "$root" "$data_root"
        return 0
    fi
    [[ "$(findmnt -n -o FSTYPE -T "$root")" == ext4 ]] || lfs_guard_die "$root is not on ext4."
    [[ "$(stat -c '%d:%i' -- "$root")" == "$(stat -c '%d:%i' -- "$data_root/lfs")" ]] || lfs_guard_die "$root is not the expected HDD bind mount."
}

lfs_acquire_writer_lock() {
    local data_root="$1"
    if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
        lfs_d34_verify_lock_fd "$data_root"
        return 0
    fi
    exec 9>"$data_root/locks/lfs-build-writer.lock"
    flock -n 9 || lfs_guard_die 'Another LFS writer holds the build lock.'
}
