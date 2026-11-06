#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.84.1: Cleaning up (chroot paths).
# The 13.1 book has no separate stripping section in chapter 8; this is the book's cleanup only.
# The book's tarball backup is not written: the read-only btrfs snapshot after-ch8 is the backup.
set -euo pipefail

# Test-run leftovers in /tmp (the book's glob also matches . and .., which rm refuses).
rm -rf /tmp/* /tmp/.[!.]* /tmp/..?*

# Libtool archive files are not needed (book).
find /usr/lib /usr/lib32 /usr/libexec -name '*.la' -delete

# Leftover cross-toolchain files from chapters 5 and 6 (book).
find /usr -depth -name 'x86_64-lfs-linux-gnu*' | xargs -r rm -rf

# Temporary tester account from chapter 7 (book).
userdel -r tester

echo "OK 82-cleanup"
