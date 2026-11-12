B=/home/yrslf/alpbahOS/scratch-lfs-bench; ISO=$B/rc02/alpbahos-beta-0.9-rc02-2026-11-12.iso; SNAP=$B/r4-snapshots/r4-rc02-2026-11-12
O=$B/lfs13-logs/iso-beta-0.9/rc02/iso-verify.txt; [ ! -e $O ] || { echo exists; exit 2; }
W=$(mktemp -d /tmp/rc02-iv.XXXX); I=$W/iso; S=$W/sq; mkdir $I $S
sudo mount -o loop,ro "$ISO" $I && sudo mount -o loop,ro $I/LiveOS/squashfs.img $S
{
echo "== ISO $(sha256sum "$ISO" | cut -c1-64)"
echo "snapshot libply-splash-core: $(sha256sum $SNAP/usr/lib/libply-splash-core.so.5.0.0 | cut -c1-16)"
echo "squashfs libply-splash-core: $(sha256sum $S/usr/lib/libply-splash-core.so.5.0.0 | cut -c1-16)"
echo "snapshot alp.py: $(sha256sum $SNAP/usr/lib/alp/alp.py | cut -c1-16); squashfs alp.py: $(sha256sum $S/usr/lib/alp/alp.py | cut -c1-16); ALP-LOCK-MSG text: $(grep -c "sudo" $S/usr/lib/alp/alp.py)"
python3 -c 'import json,sys; p=json.load(open(sys.argv[1]))["packages"]; print("squashfs alp db:", {k: p[k]["version"] for k in ("plymouth","alp-lockmsg-rc01","protobuf","netavark-rc02","aardvark-dns-rc02","alp-catalog") if k in p}, len(p), "records")' $S/var/lib/alp/db.json
echo "squashfs podman helpers: $(ls -l $S/usr/libexec/podman | tr -s " " | cut -d" " -f1,5,9 | paste -sd";")"; echo "squashfs netavark: $(sha256sum $S/usr/libexec/podman/netavark | cut -c1-16) aardvark-dns: $(sha256sum $S/usr/libexec/podman/aardvark-dns | cut -c1-16); snapshot: $(sha256sum $SNAP/usr/libexec/podman/netavark | cut -c1-16) $(sha256sum $SNAP/usr/libexec/podman/aardvark-dns | cut -c1-16)"
echo "squashfs plymouthd.conf: $(grep ^UseSimpledrm $S/etc/plymouth/plymouthd.conf)"
lsinitrd -f usr/lib/libply-splash-core.so.5.0.0 $I/boot/initramfs-live.img > $W/i.so 2>/dev/null
cp $SNAP/usr/lib/libply-splash-core.so.5.0.0 $W/p.so; strip -g -o $W/p-g.so $W/p.so
echo "initramfs-live libply-splash-core: $(sha256sum $W/i.so | cut -c1-16) $(stat -c %s $W/i.so) bytes; strip -g of the snapshot library: $(sha256sum $W/p-g.so | cut -c1-16) $(cmp -s $W/i.so $W/p-g.so && echo IDENTICAL || echo differs)"
} > $O 2>&1
sudo umount $S; sudo umount $I; rm -rf $W; cat $O; echo "loops: $(losetup -a | grep -c rc02)"
