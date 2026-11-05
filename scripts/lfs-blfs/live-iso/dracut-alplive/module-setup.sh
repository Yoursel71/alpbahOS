#!/bin/bash
# alpbahOS canlı ortam dracut modülü: ISO kökünü squashfs+overlay ile örter (pre-pivot).
# dmsquash-live device-mapper (dmsetup) gerektirdiği için bu sistemde yerine geçer.

check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst_multiple blkid mount umount mkdir
    inst_hook pre-pivot 50 "$moddir/alplive-pivot.sh"
}
