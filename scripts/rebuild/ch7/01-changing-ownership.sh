#!/bin/bash
# CONTEXT: host
# Multilib LFS 13.1, chapter 7, section 7.2: Changing Ownership.
# The book says "--from lfs"; the build user on this host is yrslf (scripts/rebuild/README.md).
# Runs on the host as root (run-chroot.sh). Targets are under $LFS = /mnt/lfs13 only.
set -euo pipefail
[[ ${LFS:-} == /mnt/lfs13 ]] || { echo "refusing LFS=${LFS:-unset}" >&2; exit 1; }
[[ $(id -u) -eq 0 ]] || { echo "must run as root" >&2; exit 1; }

chown --from yrslf -R root:root $LFS/{usr,lib64,var,etc,tools}

# Check: nothing under those trees is still owned by a non-root user.
left=$(find $LFS/{usr,lib64,var,etc,tools} ! -user root -print -quit)
if [[ -n $left ]]; then
  echo "not root-owned after chown: $left" >&2
  exit 1
fi
echo "OK 01-changing-ownership"
