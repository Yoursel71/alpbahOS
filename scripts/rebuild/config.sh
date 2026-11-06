#!/bin/bash
# REBUILD-R2: shared build environment for the MLFS 13.1 multilib rebuild.
# Sourced by every script in scripts/rebuild/ (never executed directly).
#
# Source of values: MLFS 13.1 book, chapter 4.4 "Setting Up the Environment"
# (the .bashrc block), chapter 4.2 and the multilib prologue.
# Deviations (see scripts/rebuild/README.md): user yrslf instead of lfs; the
# environment is clean (env -i in run-chapter.sh) instead of .bash_profile/.bashrc.
#
# D146: no -march/-mtune/CFLAGS with host-detected flags anywhere. This file sets none.

# Book 4.4: turn off bash command hashing so new tools are found immediately.
set +h
# Book 2.6 / 4.4: default umask.
umask 022

LFS=/mnt/lfs13
LC_ALL=POSIX
LFS_TGT=x86_64-lfs-linux-gnu
LFS_TGT32=i686-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
# Host deviation: Fedora's /usr/bin/yacc is byacc; the book needs yacc = Bison. A one-line shim
# (exec /usr/bin/bison -y) sits after the cross tools and before /usr/bin. Host files are untouched.
LFS_HOSTSHIM=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-hostshim
PATH=$LFS/tools/bin:$LFS_HOSTSHIM:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
MAKEFLAGS=-j16
export LFS LC_ALL LFS_TGT LFS_TGT32 PATH CONFIG_SITE MAKEFLAGS

# lfs_guard: call at the top of every build script (after sourcing this file).
# Exits 1 unless: LFS is /mnt/lfs13, $LFS/sources exists, the caller is not root,
# and $LFS is on btrfs.
lfs_guard() {
    if [ "$LFS" != /mnt/lfs13 ]; then
        echo "lfs_guard: refusing LFS=$LFS (must be /mnt/lfs13)" >&2
        exit 1
    fi
    if [ ! -d "$LFS/sources" ]; then
        echo "lfs_guard: $LFS/sources is missing (run ch4-root.sh as root first)" >&2
        exit 1
    fi
    if [ "$(id -u)" -eq 0 ]; then
        echo "lfs_guard: refusing to run as root (chapters 5-6 are unprivileged)" >&2
        exit 1
    fi
    if [ "$(findmnt -T "$LFS" -n -o FSTYPE 2>/dev/null)" != btrfs ]; then
        echo "lfs_guard: $LFS is not on btrfs" >&2
        exit 1
    fi
}
