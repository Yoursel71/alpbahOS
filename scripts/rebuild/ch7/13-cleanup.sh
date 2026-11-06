#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 7, section 7.15.1: Cleaning up (chroot paths).
# The book's 7.15.2 tarball backup is not written here: the read-only btrfs snapshot
# after-ch7-2026-11-06 is the backup (same as after-ch5 and after-ch6).
set -euo pipefail

rm -rf /usr/share/{info,man,doc}/*
find /usr/lib /usr/lib32 /usr/libexec -name '*.la' -delete

# The cross toolchain in /tools (= $LFS/tools) is not part of the temporary system.
rm -rf /tools

echo "OK 13-cleanup"
