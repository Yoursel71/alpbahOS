#!/bin/bash
# REBUILD-R2: root-only part of MLFS 13.1 chapter 4 (run once, as root).
# Book sources:
#   4.2 Creating a Limited Directory Layout:
#       mkdir -pv $LFS/{lib64,etc,var} $LFS/usr/{bin,lib{,32},sbin}
#       for i in bin lib lib32 sbin; do ln -sv usr/$i $LFS/$i; done
#       mkdir -pv $LFS/tools
#   4.3 Adding the LFS User (the chown part):
#       chown -v lfs $LFS/{usr{,/*},var,etc,tools,lib64}
#   Chapter 3 intro: mkdir -v $LFS/sources; chmod -v a+wt $LFS/sources
# Deviation: the book's user is lfs; this uses the existing host user yrslf.
# Deviation: the book's "mv /etc/bash.bashrc" is not done. It only matters for
# interactive bash; the build runner uses --norc and an empty environment.
#
# Guard: refuses unless LFS=/mnt/lfs13, the caller is root, and $LFS is a btrfs subvolume.

set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/config.sh"

USER_NAME=yrslf

if [ "$(id -u)" -ne 0 ]; then
    echo "ch4-root: must run as root" >&2
    exit 1
fi
if [ "$LFS" != /mnt/lfs13 ]; then
    echo "ch4-root: refusing LFS=$LFS (must be /mnt/lfs13)" >&2
    exit 1
fi
if [ ! -d "$LFS" ]; then
    echo "ch4-root: $LFS does not exist" >&2
    exit 1
fi
if [ "$(findmnt -T "$LFS" -n -o FSTYPE)" != btrfs ]; then
    echo "ch4-root: $LFS is not on btrfs" >&2
    exit 1
fi
if ! btrfs subvolume show "$LFS" >/dev/null 2>&1; then
    echo "ch4-root: $LFS is not a btrfs subvolume" >&2
    exit 1
fi
if ! id "$USER_NAME" >/dev/null 2>&1; then
    echo "ch4-root: user $USER_NAME does not exist" >&2
    exit 1
fi

echo "== ch4-root: LFS=$LFS user=$USER_NAME"

# 4.2 directory layout
mkdir -pv "$LFS"/{lib64,etc,var} "$LFS"/usr/{bin,lib{,32},sbin}
for i in bin lib lib32 sbin; do
    if [ -L "$LFS/$i" ] && [ "$(readlink "$LFS/$i")" = "usr/$i" ]; then
        echo "exists: $LFS/$i -> usr/$i"
        continue
    fi
    ln -sv "usr/$i" "$LFS/$i"
done
mkdir -pv "$LFS/tools"

# Chapter 3 intro: sources directory
mkdir -pv "$LFS/sources"
chmod -v a+wt "$LFS/sources"

# 4.3 ownership (book uses lfs; here yrslf)
chown -v "$USER_NAME:$USER_NAME" "$LFS"/{usr{,/*},var,etc,tools,lib64}
chown -v "$USER_NAME:$USER_NAME" "$LFS/sources"

echo
echo "== layout"
ls -la "$LFS"
ls -la "$LFS/usr"
echo "RESULT: ch4-root OK"
