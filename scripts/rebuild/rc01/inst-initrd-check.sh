# read-only: the installed system's initramfs carries the patched libply-splash-core (strip -g of the snapshot library)
B=/home/yrslf/alpbahOS/scratch-lfs-bench; IMG=${1:-$B/rc01/inst-bios-msdos-rc01.raw}; NAME=${2:-I1}
O=$B/lfs13-logs/iso-beta-0.9/rc01/matrix/initrd-check-$NAME.txt; [ ! -e $O ] || { echo exists; exit 2; }
SNAP=$B/r4-snapshots/r4-rc01-2026-11-12; W=$(mktemp -d /tmp/rc01-ic.XXXX); mkdir $W/m $W/x
LO=$(sudo losetup -r -f -P --show "$IMG"); P=""; for p in ${LO}p*; do [ "$(sudo blkid -o value -s TYPE $p)" = ext4 ] && P=$p; done
sudo mount -o ro,noload $P $W/m
{
I=$(ls $W/m/boot/initramfs-*.img)
echo "== $NAME installed initramfs $(basename $I) $(stat -c %s $I) bytes"
sudo cat $I > $W/i.img
( cd $W/x && /usr/lib/dracut/skipcpio $W/i.img | zstd -dc 2>/dev/null | cpio -id --quiet 'usr/lib/libply-splash-core.so.5.0.0' 'etc/plymouth/plymouthd.conf' 'usr/sbin/plymouthd' ) 2>&1 | head -2
cp $SNAP/usr/lib/libply-splash-core.so.5.0.0 $W/p.so; strip -g -o $W/pg.so $W/p.so
echo "installed /usr/lib library: $(sha256sum $W/m/usr/lib/libply-splash-core.so.5.0.0 | cut -c1-16) (snapshot $(sha256sum $W/p.so | cut -c1-16))"
echo "initramfs library: $(sha256sum $W/x/usr/lib/libply-splash-core.so.5.0.0 2>/dev/null | cut -c1-16); strip -g of the patched build: $(sha256sum $W/pg.so | cut -c1-16) -> $(cmp -s $W/x/usr/lib/libply-splash-core.so.5.0.0 $W/pg.so && echo IDENTICAL || echo DIFFERENT)"
echo "initramfs plymouthd.conf: $(grep ^UseSimpledrm $W/x/etc/plymouth/plymouthd.conf 2>&1)"
echo "installed alp.py: $(sha256sum $W/m/usr/lib/alp/alp.py | cut -c1-16)"
} > $O 2>&1
sudo umount $W/m; sudo losetup -d $LO; rm -rf $W; cat $O
