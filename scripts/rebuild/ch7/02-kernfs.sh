#!/bin/bash
# CONTEXT: host
# Multilib LFS 13.1, chapter 7, sections 7.3.1-7.3.2: Preparing Virtual Kernel File Systems.
# Runs on the host as root (run-chroot.sh). Every mount target is under $LFS = /mnt/lfs13.
# run-chroot.sh unmounts all of them on exit, whatever the result.
set -euo pipefail
[[ ${LFS:-} == /mnt/lfs13 ]] || { echo "refusing LFS=${LFS:-unset}" >&2; exit 1; }
[[ $(id -u) -eq 0 ]] || { echo "must run as root" >&2; exit 1; }

mkdir -pv $LFS/{dev,proc,sys,run}

# 7.3.1 Mounting and Populating /dev
mount -v --bind /dev $LFS/dev

# 7.3.2 Mounting Virtual Kernel File Systems
mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
  install -v -d -m 1777 $LFS$(realpath /dev/shm)
else
  mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
fi

# Check: every expected mount is in place, and no mount was made outside $LFS.
for m in $LFS/dev $LFS/dev/pts $LFS/proc $LFS/sys $LFS/run; do
  mountpoint -q "$m" || { echo "not mounted: $m" >&2; exit 1; }
done
bad=$(findmnt -rn -o TARGET | grep -E '^/mnt/lfs13/' | grep -v -E '^/mnt/lfs13/(dev|dev/pts|dev/shm|proc|sys|run)$' || true)
if [[ -n $bad ]]; then
  echo "unexpected mounts under $LFS: $bad" >&2
  exit 1
fi
echo "OK 02-kernfs"
