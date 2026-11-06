#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.5.3 (Glibc 32-bit), the book's step that was missing from
# 03-glibc.sh: add the 32-bit library directory to the dynamic loader config, then update the cache.
# Not part of the 01-82 order. Run once on the existing build root with: run-chroot.sh ch8 00 00
# (no glibc rebuild). 03-glibc.sh now contains the same step for fresh builds.
set -euo pipefail

echo "/usr/lib32" > /etc/ld.so.conf.d/lib32.conf
cat /etc/ld.so.conf.d/lib32.conf
ldconfig
ldconfig -p | grep -E 'libm\.so\.6|libstdc\+\+|libc\.so\.6' | grep -c . > /dev/null
echo "OK 00-glibc-lib32-conf"
