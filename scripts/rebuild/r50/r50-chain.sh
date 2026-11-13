#!/bin/bash
# Round 50 package chain (one alp record per step through pkg-url-r11.sh). Run as root, single writer on r4-root, snapshot
# r4-snapshots/r4-before-r50b taken first (`r50-chain.sh snapshot`). Usage: r50-chain.sh [snapshot|NAME ...]
# Steps (MirazParted first: it is the biggest visible gap of the real-PC day):
#   mirazparted   partitionmanager 26.08.3 (KDE Gear, matches the installed kpmcore 26.08.3), shown as MirazParted
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
A=$WT/scripts/rebuild/r50/chroot
export NICE=${NICE:-15} JOBS=${JOBS:-10}
mkdir -p "$SB/r10/dl"
ARGS=("$@")
w() { [ ${#ARGS[@]} -eq 0 ] && return 0; local x; for x in "${ARGS[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
if [ "${1:-}" = snapshot ]; then
  [ ! -e "$SB/r4-snapshots/r4-before-r50b" ] || { echo "snapshot exists"; exit 1; }
  btrfs subvolume snapshot -r "$SB/r4-root" "$SB/r4-snapshots/r4-before-r50b" > /dev/null; echo "snapshot r4-before-r50b"; exit 0
fi
step() {  # NAME VER URL TARBALL ROWNN MD5 SCRIPT [EXTRA FILES...]
    local n=$1 v=$2 u=$3 t=$4 nn=$5 m=$6 s=$7; shift 7
    [ -s "$SB/r10/dl/$t" ] || curl -sL --tlsv1.2 --max-time 600 -o "$SB/r10/dl/$t" "$u"
    [ "$(md5sum < "$SB/r10/dl/$t" | cut -c1-32)" = "$m" ] || { echo "MD5 mismatch: $t"; exit 1; }
    echo "== $n-$v ($(date +%T))"
    EXTRA_FILES="$s $*" CUSTOM_CMD="sh ../$(basename "$s")" \
      bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" "$n" "$v" "$u" "$t" custom - "$nn" "R50: $v, md5 $m (TOFU, first fetch 2026-11-13)"
}
K=https://download.kde.org/stable/release-service/26.08.3/src
w mirazparted && step mirazparted 26.08.3 $K/partitionmanager-26.08.3.tar.xz partitionmanager-26.08.3.tar.xz 466 4d011ca37c2bc8d42c4a23b795a90250 "$A/mirazparted.sh" "$WT/branding/icons/mirazparted.svg"
# --- filesystem tools and the udisks/upower stack (BLFS 13.1-systemd unless stated; md5 from the page) ---
P=https://www.linuxfromscratch.org/blfs/view/13.1-systemd
bstep() {  # NAME VER URL TARBALL KIND ROWNN MD5 PAGE [opts...]   (build-pkg-r10.sh kinds: configure|meson|cmake)
    local n=$1 v=$2 u=$3 t=$4 k=$5 nn=$6 m=$7 pg=$8; shift 8
    [ -s "$SB/r10/dl/$t" ] || curl -sL --tlsv1.2 --max-time 600 -o "$SB/r10/dl/$t" "$u"
    [ "$(md5sum < "$SB/r10/dl/$t" | cut -c1-32)" = "$m" ] || { echo "MD5 mismatch: $t"; exit 1; }
    echo "== $n-$v ($(date +%T))"
    bash "$WT/scripts/rebuild/r11/pkg-url-r11.sh" "$n" "$v" "$u" "$t" "$k" - "$nn" "R50: BLFS 13.1-systemd $pg: $v, book MD5 $m matches" "$@"
}
w lzo && bstep lzo 2.10 https://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz lzo-2.10.tar.gz configure 467 39d3f3f9c55c87b1e5d6888e1420f4b5 general/lzo.html --enable-shared --disable-static --docdir=/usr/share/doc/lzo-2.10
w cryptsetup && bstep cryptsetup 2.8.7 https://www.kernel.org/pub/linux/utils/cryptsetup/v2.8/cryptsetup-2.8.7.tar.xz cryptsetup-2.8.7.tar.xz configure 468 a9a19068e4db32f77c0ab95c378ab290 postlfs/cryptsetup.html --disable-ssh-token --disable-asciidoc
w btrfs-progs && bstep btrfs-progs v7.1 https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v7.1.tar.xz btrfs-progs-v7.1.tar.xz configure 469 5dbaaf17567022405d6fc9d0d185e812 postlfs/btrfs-progs.html --disable-static --disable-documentation
w ntfs-3g && step ntfs-3g 2026.7.7 https://github.com/tuxera/ntfs-3g/archive/2026.7.7/ntfs-3g-2026.7.7.tar.gz ntfs-3g-2026.7.7.tar.gz 470 254f0eae638ae2f1f0e24f0b76dd1dfc "$A/ntfs-3g.sh"
G=https://github.com
w libusb && bstep libusb 1.0.30 $G/libusb/libusb/releases/download/v1.0.30/libusb-1.0.30.tar.bz2 libusb-1.0.30.tar.bz2 configure 471 b0b0bacc2c6919515db8e863f0517db8 general/libusb.html --disable-static
w upower && bstep upower 1.91.3 https://gitlab.freedesktop.org/upower/upower/-/archive/v1.91.3/upower-v1.91.3.tar.bz2 upower-v1.91.3.tar.bz2 meson 472 bf09da2eb695224e249e38077460414c general/upower.html -D gtk-doc=false -D man=false
w keyutils && step keyutils 1.6.3 https://git.kernel.org/pub/scm/linux/kernel/git/dhowells/keyutils.git/snapshot/keyutils-1.6.3.tar.gz keyutils-1.6.3.tar.gz 473 6b70b2b381c1b6d9adfaf66d5d3e7c00 "$A/keyutils.sh"
w libbytesize && bstep libbytesize 2.12 $G/storaged-project/libbytesize/releases/download/2.12/libbytesize-2.12.tar.gz libbytesize-2.12.tar.gz configure 474 5314b773b20d1f3acdf3b2bf0c92549f general/libbytesize.html
w libnvme && bstep libnvme 1.16.2 $G/linux-nvme/libnvme/archive/v1.16.2/libnvme-1.16.2.tar.gz libnvme-1.16.2.tar.gz meson 475 a6554fb50022d762021fc1e949e01520 general/libnvme.html -D libdbus=auto
w libblockdev && bstep libblockdev 3.5.0 $G/storaged-project/libblockdev/releases/download/3.5.0/libblockdev-3.5.0.tar.gz libblockdev-3.5.0.tar.gz configure 476 68448042ea0a2073098fc4ae37b01cbf general/libblockdev.html --sysconfdir=/etc --with-python3 --without-escrow --without-gtk-doc --without-lvm --without-lvm_dbus --without-nvdimm --without-tools --without-smartmontools
w udisks2 && bstep udisks2 2.11.2 $G/storaged-project/udisks/releases/download/udisks-2.11.2/udisks-2.11.2.tar.bz2 udisks-2.11.2.tar.bz2 configure 477 9e8e8c7f43257bc501b4896f43db9eb8 general/udisks2.html --sysconfdir=/etc --localstatedir=/var --disable-static --enable-available-modules
w smartmontools && bstep smartmontools 7.5 $G/smartmontools/smartmontools/releases/download/RELEASE_7_5/smartmontools-7.5.tar.gz smartmontools-7.5.tar.gz configure 478 38c38b0b82db7fc4906cdd50d15a7931 "upstream release (no BLFS page; TOFU md5)" --sysconfdir=/etc --with-systemdsystemunitdir=/usr/lib/systemd/system
w rtkit && bstep rtkit 0.13 $G/heftig/rtkit/releases/download/v0.13/rtkit-0.13.tar.xz rtkit-0.13.tar.xz meson 479 90939b9886d1998fa5b15f6109bfd1ae "upstream release (no BLFS page; TOFU md5)"
w wireless-regdb && step wireless-regdb 2026.09.03 https://git.kernel.org/pub/scm/linux/kernel/git/wens/wireless-regdb.git/snapshot/wireless-regdb-master-2026-09-03.tar.gz wireless-regdb-master-2026-09-03.tar.gz 480 ab87f48fcce17d9adf950800a9634cfa "$A/wireless-regdb.sh"
w nvme-cli && bstep nvme-cli 3.2 $G/linux-nvme/nvme-cli/archive/refs/tags/v3.2.tar.gz nvme-cli-v3.2.tar.gz meson 481 e338c5112d32932891257ec669fad89a "upstream release v3.2 (no BLFS page; TOFU md5; builds its own libnvme)"
w adwaita-fonts && step adwaita-fonts 51.0 https://download.gnome.org/sources/adwaita-fonts/51/adwaita-fonts-51.0.tar.xz adwaita-fonts-51.0.tar.xz 482 39ec1236312148f883915a14f1b01b59 "$A/adwaita-fonts.sh"
w kdialog && step kdialog 26.08.3 $K/kdialog-26.08.3.tar.xz kdialog-26.08.3.tar.xz 483 6edf517a305021337957ebd06f29d931 "$A/kdialog.sh"
w grub-dm && step grub-dm 2.14 https://ftpmirror.gnu.org/grub/grub-2.14.tar.xz grub-2.14.tar.xz 484 383f9effad01c235d2535357ff717543 "$A/grub-dm.sh"
echo "r50 chain done $(date +%T)"
