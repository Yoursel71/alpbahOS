#!/bin/bash
# BLFS sıralı çalıştırıcı (root, chroot). İlk hatada durur. Başarılı NN'ler blfs.ok'a yazılır.
B=/home/yrslf/alpbahOS/scratch-lfs-bench/blfs-plan
LFS=/mnt/lfs
touch $B/blfs.ok; touch $B/blfs.status
bash /home/yrslf/alpbahOS/scratch-lfs-bench/lfs-build-plan/mount_lfs.sh >/dev/null 2>&1
for NN in $(awk '{print $1}' $B/order.txt | uniq); do
  grep -qx "$NN" $B/blfs.ok && continue
  case "$NN" in 017|018|020|191) echo "SKIP $NN (kaynak yok)" >> $B/blfs.status; continue;; esac
  python3 $B/gen_blfs_chroot.py $NN >/dev/null 2>&1 || { echo "GEN_FAIL $NN" >> $B/blfs.status; exit 1; }; chown yrslf:yrslf $B/gen_blfs/$NN.sh
  cp $B/gen_blfs/$NN.sh $LFS/sources/.blfs-$NN.sh
  start=$(date +%s)
  if chroot $LFS /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j16 /bin/bash --login +h /sources/.blfs-$NN.sh > $B/logs/$NN.log 2>&1; then
    echo "$NN" >> $B/blfs.ok; echo "OK $NN $(( $(date +%s)-start ))s" >> $B/blfs.status
  else
    echo "FAIL $NN $(( $(date +%s)-start ))s (log: $B/logs/$NN.log)" >> $B/blfs.status; exit 1
  fi
done
echo DONE >> $B/blfs.status
