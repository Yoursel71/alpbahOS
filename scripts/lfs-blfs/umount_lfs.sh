#!/bin/bash
# LFS sanal dosya sistemlerini ters sırayla çözer. Çalıştır: sudo bash umount_lfs.sh
LFS=/mnt/lfs
for m in $LFS/dev/shm $LFS/dev/pts $LFS/dev $LFS/run $LFS/proc $LFS/sys; do
  mountpoint -q "$m" && umount -v "$m"
done
mountpoint -q $LFS/dev && umount -v -l $LFS/dev || true
echo "kalan bağlar:"; mount | grep "$LFS" || echo "yok"
