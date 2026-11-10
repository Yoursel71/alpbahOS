#!/bin/bash
# GRUB-THEME-01 (D1) preview: a small hybrid ISO that only shows the GRUB menu with the alpbahOS theme, built with the
# target's GRUB 2.14 (r4-root grub-mkimage and modules, run on the host) for BIOS and UEFI. No kernel: the entries
# copy the installed titles and only echo text. Used to check the look before an ISO and install cycle.
# Runs on the host as the build user (no root). Usage: grub-preview.sh <out-dir> [timeout-seconds] [gfxmode]
# The grub.cfg mirrors what 00_header writes for GRUB_TERMINAL_OUTPUT=gfxterm with GRUB_FONT and GRUB_THEME.
set -euo pipefail
OUT=$1; TMO=${2:-30}; GFX=${3:-auto}   # GFX: gfxmode for the preview (product: auto)
WT=$(cd "$(dirname "$0")/../../.." && pwd)
R4=/home/yrslf/alpbahOS/scratch-lfs-bench/r4-root
THEME_SRC=$WT/branding/grub-theme/alpbahos
[ ! -e "$OUT" ] || { echo "$OUT exists" >&2; exit 2; }
mkdir -p "$OUT/tree/boot/grub/themes/alpbahos" "$OUT/tree/boot/grub/i386-pc" "$OUT/tree/boot/grub/x86_64-efi"
T=$OUT/tree/boot/grub
cp "$THEME_SRC"/*.png "$THEME_SRC"/*.pf2 "$T/themes/alpbahos/"
# Version line from the rootfs os-release (same rule as the package staging script).
VER=$(. "$R4/etc/os-release"; echo "$VERSION")
sed "s|@VERSION_LINE@|$VER · x86_64|" "$THEME_SRC/theme.txt.in" > "$T/themes/alpbahos/theme.txt"
for p in i386-pc x86_64-efi; do
    find "$R4/usr/lib/grub/$p" -maxdepth 1 \( -name '*.mod' -o -name '*.lst' \) -exec cp {} "$T/$p/" \;
done
cat > "$T/grub.cfg" <<EOF
insmod part_gpt
insmod part_msdos
set default=0
set timeout_style=menu
set timeout=$TMO
if loadfont \$prefix/themes/alpbahos/jbm-16.pf2 ; then
  set gfxmode=$GFX
  insmod all_video
  insmod gfxterm
fi
terminal_output gfxterm
insmod gfxmenu
$(for f in "$THEME_SRC"/*.pf2; do echo "loadfont \$prefix/themes/alpbahos/$(basename "$f")"; done)
insmod png
set theme=\$prefix/themes/alpbahos/theme.txt
export theme
menuentry 'alpbahOS GNU/Linux, with Linux 7.1.8-alpbahos' --class alpbahos {
    echo 'preview: no kernel'
    sleep 5
}
if [ "\$grub_platform" = efi ]; then
menuentry 'UEFI Firmware Settings' { fwsetup }
fi
menuentry 'Türkçe harf denemesi: ç ğ ı İ ö ş ü Ç Ğ Ö Ş Ü' { true }
EOF
printf 'search --no-floppy --file --set=root /boot/grub/grub.cfg\nset prefix=($root)/boot/grub\n' > "$OUT/embed.cfg"
MODS="iso9660 part_gpt part_msdos fat search search_fs_file normal configfile echo test gfxterm gfxmenu all_video png font"
"$R4/usr/bin/grub-mkimage" -d "$R4/usr/lib/grub/i386-pc" -O i386-pc-eltorito -o "$T/i386-pc/eltorito.img" \
    -p /boot/grub -c "$OUT/embed.cfg" biosdisk $MODS
"$R4/usr/bin/grub-mkimage" -d "$R4/usr/lib/grub/x86_64-efi" -O x86_64-efi -o "$OUT/bootx64.efi" \
    -p /boot/grub -c "$OUT/embed.cfg" $MODS
mkdir -p "$OUT/tree/EFI/BOOT"; cp "$OUT/bootx64.efi" "$OUT/tree/EFI/BOOT/BOOTX64.EFI"
truncate -s 4M "$OUT/tree/boot/grub/efi.img"
mformat -i "$OUT/tree/boot/grub/efi.img" ::
mmd -i "$OUT/tree/boot/grub/efi.img" ::/EFI ::/EFI/BOOT
mcopy -i "$OUT/tree/boot/grub/efi.img" "$OUT/bootx64.efi" ::/EFI/BOOT/BOOTX64.EFI
xorriso -as mkisofs -quiet -o "$OUT/preview.iso" -V GRUBPREVIEW \
    -b boot/grub/i386-pc/eltorito.img -no-emul-boot -boot-load-size 4 -boot-info-table \
    --grub2-boot-info --grub2-mbr "$R4/usr/lib/grub/i386-pc/boot_hybrid.img" \
    -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat "$OUT/tree"
sha256sum "$OUT/preview.iso" > "$OUT/preview.iso.sha256"
echo "preview ISO: $OUT/preview.iso"
