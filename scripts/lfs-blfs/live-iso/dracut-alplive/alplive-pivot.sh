#!/bin/sh
# pre-pivot kancası: dracut ISO'yu $NEWROOT'a bağladı (root=LABEL=ALPBAH_LIVE).
# squashfs alt katman, tmpfs üst katman overlay'i $NEWROOT'a taşınır; ISO ortamı kalıcı yola bağlanır.
type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

getarg alp.live >/dev/null || exit 0

mkdir -p /run/initramfs/live /run/initramfs/squash /run/initramfs/rw /run/initramfs/overlay_root
mount --bind "$NEWROOT" /run/initramfs/live || { warn "alplive: ISO bind basarisiz"; exit 1; }
mount -t squashfs -o ro /run/initramfs/live/LiveOS/squashfs.img /run/initramfs/squash || { warn "alplive: squashfs baglanamadi"; exit 1; }
mount -t tmpfs -o mode=0755 tmpfs /run/initramfs/rw || exit 1
mkdir -p /run/initramfs/rw/upper /run/initramfs/rw/work
mount -t overlay overlay -o lowerdir=/run/initramfs/squash,upperdir=/run/initramfs/rw/upper,workdir=/run/initramfs/rw/work /run/initramfs/overlay_root || { warn "alplive: overlay kurulamadi"; exit 1; }
umount "$NEWROOT" || { warn "alplive: ISO ayrilamadi"; exit 1; }
mount --move /run/initramfs/overlay_root "$NEWROOT" || { warn "alplive: overlay tasinamadi"; exit 1; }
mkdir -p "$NEWROOT/lib/live/mount/medium"
mount --bind /run/initramfs/live "$NEWROOT/lib/live/mount/medium" || warn "alplive: medium kalici yola baglanamadi"
info "alplive: kok overlay hazir"
