#!/bin/bash
# REBUILD-R2: replaces book chapter 4.3 (user lfs) and 4.4 (.bash_profile/.bashrc)
# for user yrslf. Nothing here needs root. It verifies the layout made by
# ch4-root.sh and prints the build environment that config.sh provides
# (run-chapter.sh starts every build script in a clean env, so no dotfiles are used).

set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/config.sh"
lfs_guard

bad=0

check_dir() {
    if [ -d "$1" ] && [ ! -L "$1" ] && [ "$(stat -c %U "$1")" = yrslf ]; then
        echo "OK    dir  $1 (owner yrslf)"
    else
        echo "FAIL  dir  $1 (missing, a symlink, or not owned by yrslf)"
        bad=$((bad + 1))
    fi
}

check_link() {
    if [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; then
        echo "OK    link $1 -> $2"
    else
        echo "FAIL  link $1 (expected -> $2)"
        bad=$((bad + 1))
    fi
}

echo "== layout check for $LFS"
for d in etc var tools sources lib64 usr usr/bin usr/lib usr/lib32 usr/sbin; do
    check_dir "$LFS/$d"
done
for i in bin lib lib32 sbin; do
    check_link "$LFS/$i" "usr/$i"
done
if [ -e "$LFS/usr/lib64" ] || [ -L "$LFS/usr/lib64" ]; then
    echo "FAIL  $LFS/usr/lib64 must not exist (book 4.2 note)"
    bad=$((bad + 1))
else
    echo "OK    no $LFS/usr/lib64"
fi

echo
echo "== build environment (from config.sh)"
echo "LFS=$LFS"
echo "LC_ALL=$LC_ALL"
echo "LFS_TGT=$LFS_TGT"
echo "LFS_TGT32=$LFS_TGT32"
echo "PATH=$PATH"
echo "CONFIG_SITE=$CONFIG_SITE"
echo "MAKEFLAGS=$MAKEFLAGS"

if [ "$bad" -ne 0 ]; then
    echo "RESULT: FAIL ($bad problem(s))"
    exit 1
fi
echo "RESULT: ch4-user OK"
