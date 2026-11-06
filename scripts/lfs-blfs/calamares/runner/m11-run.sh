#!/bin/bash
# M11 modül koşucusu (alpbahOS, Calamares 3.3.14 loadmodule).
#
# Ne yapar: yeni bir sanal disk dosyasını (yalnız bu dosya) loop aygıtına bağlar,
# GPT + BIOS boot + ext4 kök bölümü açar, kök bölümünü /var/tmp/m11-target'a
# bağlar (sanal dosya sistemleri dahil), sonra kurucu modüllerini LFS chroot'unda
# (/mnt/lfs) TEK TEK çalıştırır: unpackfs, machineid, localecfg, fstab, networkcfg,
# hwclock, bootloader, umount.
#
# Sınırlar (kanıt belgesinde sapma olarak yazılır):
#  - Bölümleme, mkfs ve kök bağlama bu betikte yapılır; Calamares'in partition ve
#    mount modülleri koşmaz (mount modülü kendi geçici kök dizinini açar, gs'i
#    değiştirir; başsız koşucuda sonraki modüller yanlış kökü görür).
#  - locale ve keyboard GUI görünüm modülleridir; başsız koşmaz.
#  - Kurulum canlı ISO içinde değil, ana makinedeki LFS chroot'unda koşar.
#  - Önyükleme kanıtı ayrı bir VM oturumunda (-cdrom yok) yapılır.
#
# Kullanım: sudo bash m11-run.sh <YENİ-hedef.img> <log-dizini>
set -eu

IMG=${1:?kullanım: m11-run.sh <yeni-hedef.img> <log-dizini>}
LOGD=${2:?kullanım: m11-run.sh <yeni-hedef.img> <log-dizini>}
R=$(dirname "$(readlink -f "$0")")
LFS=/mnt/lfs
SQ=/home/yrslf/alpbahOS/scratch-lfs-bench/alp-iso/LiveOS/squashfs.img
TOOLS=/home/yrslf/alpbahOS/scratch-lfs-bench/m11-runner/hosttools
CAL=/sources/blfs-build/calamares-3.3.14/build/loadmodule
TARGET_IN_CHROOT=/var/tmp/m11-target
TGT="$LFS$TARGET_IN_CHROOT"
LOOP=""
SQ_BIND=0
TOOLS_BIND=0
MADE_LIVE_DIR=0

target_unmount() {
    if mountpoint -q "$TGT"; then umount -R "$TGT"; fi
}

cleanup() {
    set +e
    target_unmount
    # unpackfs, squashfs'i kendi geçici dizininde bağlar; hata çıkışında kalabilir.
    for d in "$LFS"/tmp/tmp*/squashfs; do
        [ -d "$d" ] && mountpoint -q "$d" && umount "$d"
        rmdir "$d" "${d%/squashfs}" 2>/dev/null
    done
    if [ "$SQ_BIND" = 1 ]; then umount "$LFS/usr/lib/live/mount/medium/LiveOS/squashfs.img"; fi
    if [ "$MADE_LIVE_DIR" = 1 ]; then rm -rf "$LFS/usr/lib/live"; fi
    if [ "$TOOLS_BIND" = 1 ]; then umount "$LFS/run/m11tools"; fi
    if [ -n "$LOOP" ]; then losetup -d "$LOOP"; fi
    # Boş bağlama noktasını bu koşucu açtı; kalıntı bırakma.
    rmdir "$TGT" 2>/dev/null || true
}
trap cleanup EXIT
trap 'echo "M11 koşucu HATA: satır $LINENO" >&2' ERR

[ "$(id -u)" = 0 ] || { echo "root gerekli"; exit 1; }
[ ! -e "$IMG" ] || { echo "hedef zaten var, yeniden kullanılmaz: $IMG"; exit 1; }
[ ! -e "$LFS/usr/lib/live" ] || { echo "$LFS/usr/lib/live zaten var; durduruldu"; exit 1; }
[ ! -e "$TGT" ] || { echo "$TGT zaten var; durduruldu"; exit 1; }
mountpoint -q "$LFS/proc" && mountpoint -q "$LFS/dev" || { echo "chroot sanal bağlar eksik (mount_lfs.sh)"; exit 1; }
# Ön koşullar (yeniden üretim: devir notu 024).
# unpackfs squashfs'i okuyamazsa sessizce boş dönebilir (devir 024 madde 4): hard fail.
grep -qw squashfs /proc/filesystems || { echo "DURDU: çekirdekte squashfs yok (/proc/filesystems). Önce: sudo modprobe squashfs"; exit 1; }
[ -f "$R/../modules/grubcfg.conf" ] && [ -f "$R/../modules/bootloader.conf" ] \
    || { echo "DURDU: repo modül yapılandırması eksik: $R/../modules/{grubcfg,bootloader}.conf"; exit 1; }
[ -x "$LFS$CAL" ] || { echo "ön koşul: $LFS$CAL yok (BUILD_TESTING=ON ile loadmodule derlemesi, devir 024)"; exit 1; }
[ -x "$TOOLS/bin/rsync" ] && [ -x "$TOOLS/bin/unsquashfs" ] || { echo "ön koşul: $TOOLS eksik (devir 024)"; exit 1; }
[ -f "$SQ" ] || { echo "ön koşul: squashfs yok: $SQ"; exit 1; }
mkdir -p "$LOGD"

# Modül günlüğü kontrolü: loadmodule çıkış kodu 0 dönse de iş (job) hatası
# günlükte kalabilir (ör. umount 32, grub-install 127). Bu yüzden günlüğü de denetle.
check_log() {
    local f=$1 pat="returned non-zero|FATAL|Traceback|failed to run command|ERROR:|Configuration Error"
    # grubcfg kendi yoklamalarını (which, grep -q) bilerek başarısız çalıştırır; onları sayma.
    local nonzero='Exit code: [1-9]'
    if grep -E -q "$pat" "$f" \
        || awk '/Exit code: [1-9]/ && !/which|grep -q|test -/ {found=1} END{exit !found}' "$f"; then
        echo "DURDU: günlük hata içeriyor: $f" >&2
        grep -E "$pat|$nonzero" "$f" | grep -v -E "which|grep -q" | head -5 >&2
        exit 1
    fi
}

# 1) Hedef: yeni sparse dosya, loop aygıtı, yalnız bu aygıt bölümlenir.
truncate -s 20G "$IMG"
LOOP=$(losetup -f --show "$IMG")
echo "loop=$LOOP img=$IMG" | tee "$LOGD/00-loop.log"
printf 'label: gpt\nstart=2048, size=2048, type=21686148-6449-6E6F-744E-656564454649, name="bios"\nstart=4096, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="alproot"\n' \
    | chroot "$LFS" sfdisk --wipe always "$LOOP" > "$LOGD/01-sfdisk.log" 2>&1
partprobe "$LOOP"
sleep 1
[ -b "${LOOP}p2" ] || { echo "${LOOP}p2 yok"; exit 1; }
chroot "$LFS" mkfs.ext4 -q -F -L alpbah-root "${LOOP}p2" > "$LOGD/02-mkfs.log" 2>&1
UUID=$(blkid -s UUID -o value "${LOOP}p2")
PUUID=$(blkid -s PARTUUID -o value "${LOOP}p2")
echo "partuuid=$PUUID" | tee -a "$LOGD/02-mkfs.log"
echo "root_uuid=$UUID" | tee -a "$LOGD/02-mkfs.log"

# 2) Chroot içi girdiler: araç köprüsü, squashfs (ISO'daki yolla aynı), hedef kök.
mkdir -p "$LFS/run/m11tools" "$TGT" "$LFS/root/m11-runner"
mount --bind "$TOOLS" "$LFS/run/m11tools"; TOOLS_BIND=1
mkdir -p "$LFS/usr/lib/live/mount/medium/LiveOS"; MADE_LIVE_DIR=1
touch "$LFS/usr/lib/live/mount/medium/LiveOS/squashfs.img"
mount --bind "$SQ" "$LFS/usr/lib/live/mount/medium/LiveOS/squashfs.img"; SQ_BIND=1
mount "${LOOP}p2" "$TGT"
# Hedef içindeki chroot komutları için sanal dosya sistemleri (mount modülünün işi).
mkdir -p "$TGT/dev" "$TGT/proc" "$TGT/sys" "$TGT/run"
mount --bind "$LFS/dev" "$TGT/dev"
mount -t proc proc "$TGT/proc"
mount -t sysfs sysfs "$TGT/sys"
mount --bind "$LFS/run" "$TGT/run"

# 3) Koşucu girdileri (ürün yapılandırmasının kopyası; yalnız çekirdek arama yolu ve test konsolu).
cp "$R/settings.conf" "$LFS/root/m11-runner/settings.conf"
# Modül yapılandırmaları repodan kopyalanır (chroot'taki /etc kopyası kullanılmaz).
install -m 644 "$R/../modules/bootloader.conf" "$LFS/root/m11-runner/bootloader.conf"
install -m 644 "$R/../modules/grubcfg.conf" "$LFS/root/m11-runner/grubcfg.conf"
# Yalnız test: seri konsol parametresi (ürün kararı değil).
sed -i 's|^kernelParams:.*|kernelParams: [ "quiet", "console=tty0", "console=ttyS0,115200n8" ]|' \
    "$LFS/root/m11-runner/bootloader.conf"
cat > "$LFS/root/m11-runner/gs.yaml" <<EOF
rootMountPoint: "$TARGET_IN_CHROOT"
partitions:
  - device: "${LOOP}p2"
    fs: "ext4"
    mountPoint: "/"
    uuid: "$UUID"
    claimed: true
bootLoader:
  installPath: "$LOOP"
localeConf:
  LANG: "tr_TR.UTF-8"
mountOptionsList:
  - mountpoint: "/"
    option_string: "defaults,noatime"
firmwareType: "bios"
branding:
  bootloaderEntryName: "alpbahOS"
  productName: "alpbahOS"
EOF

run_mod() {
    local name=$1 conf=${2:-}
    local log="$LOGD/10-$name.log"
    local extra=""
    [ -n "$conf" ] && extra="-j $conf"
    set +e
    chroot "$LFS" /bin/sh -c "cd /root/m11-runner && env PATH=/run/m11tools/bin:/usr/sbin:/usr/bin:/sbin:/bin QT_QPA_PLATFORM=offscreen QT_PLUGIN_PATH=/usr/lib/plugins:/opt/qt6/plugins $CAL -S settings.conf -g gs.yaml $extra $name" > "$log" 2>&1
    local rc=$?
    set -e
    echo "[$name] rc=$rc"
    if [ "$rc" != 0 ]; then
        echo "DURDU: $name başarısız rc=$rc (log: $log)" >&2
        exit 1
    fi
    check_log "$log"
}

run_mod unpackfs /etc/calamares/modules/unpackfs.conf
# unpackfs rc=0 dönse de hedef boş kalabilir (squashfs okunamadı): kök dosyalarını doğrula.
[ -x "$TGT/usr/bin/bash" ] && [ -d "$TGT/etc" ] && [ -d "$TGT/boot" ] \
    || { echo "DURDU: unpackfs sonrası hedef kökte dosya yok (/usr/bin/bash, /etc, /boot)"; exit 1; }
# Canlı ISO'nun initramfs'i (alplive kancası) kurulu sisteme kopyalandı; disk kökünü
# canlı medyaya bağlayacağı için grub-mkconfig'in ona yazmaması gerekir.
rm -f "$TGT"/boot/initramfs-live-*.img
echo "[rm-live-initramfs] ok" | tee "$LOGD/11-rm-live-initramfs.log"
run_mod machineid /etc/calamares/modules/machineid.conf
run_mod localecfg
run_mod fstab /etc/calamares/modules/fstab.conf
# Modül yapılandırma hataları (ör. eksik mountOptionsList) rc=0 ile dönebilir ve
# dosyayı hiç yazmayabilir; bu yüzden sonucu dosyada doğrula.
grep -q "^UUID=$UUID[[:space:]]\+/[[:space:]]" "$TGT/etc/fstab" \
    || { echo "DURDU: fstab kök satırı yok (UUID=$UUID)"; exit 1; }
run_mod networkcfg
run_mod hwclock
run_mod grubcfg /root/m11-runner/grubcfg.conf
[ -f "$TGT/etc/default/grub" ] && grep -q "^GRUB_DISTRIBUTOR='alpbahOS'" "$TGT/etc/default/grub" \
    || { echo "DURDU: grubcfg /etc/default/grub yazmadı veya GRUB_DISTRIBUTOR='alpbahOS' yok"; exit 1; }
grep -q "^GRUB_DISABLE_LINUX_PARTUUID='false'" "$TGT/etc/default/grub" \
    && grep -q "^GRUB_DISABLE_LINUX_UUID='true'" "$TGT/etc/default/grub" \
    || { echo "DURDU: grubcfg PARTUUID ayarları /etc/default/grub içinde yok"; exit 1; }
# Kurulu sistemde initramfs yok (canlı ISO'nun alplive initramfs'i kaldırıldı).
# Çekirdek root=UUID= değerini initramfs olmadan çözemez; bölüm UUID'sini (PARTUUID)
# çekirdek GPT üzerinden kendisi bulur (CONFIG_EFI_PARTITION=y). grub-mkconfig'in
# D144: ürün yolu grubcfg.conf içindeki GRUB_DISABLE_LINUX_UUID=true +
# GRUB_DISABLE_LINUX_PARTUUID=false ayarıdır; 10_linux root=PARTUUID= yazar.
# Eski zorlama yolu (GRUB_DEVICE) yalnız M11_GRUB_DEVICE_OVERRIDE=1 ile kullanılır.
if [ "${M11_GRUB_DEVICE_OVERRIDE:-0}" = 1 ]; then
    echo "GRUB_DEVICE='PARTUUID=$PUUID'" >> "$TGT/etc/default/grub"
fi
# Yalnız test: seri konsol (VM'de seri günlükle giriş istemini kanıtlamak için).
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT='quiet console=tty0 console=ttyS0,115200n8'|" "$TGT/etc/default/grub"
run_mod bootloader "/root/m11-runner/bootloader.conf"
grep -q "root=PARTUUID=$PUUID" "$TGT/boot/grub/grub.cfg" \
    || { echo "DURDU: grub.cfg root=PARTUUID=$PUUID içermiyor"; exit 1; }
grep -q "console=ttyS0,115200n8" "$TGT/boot/grub/grub.cfg" \
    || { echo "DURDU: grub.cfg seri konsol parametresi yok"; exit 1; }
run_mod umount /etc/calamares/modules/umount.conf

# Son denetim: hedef bağlı kalmamalı; dosya sistemi temiz olmalı.
target_unmount
sync
e2fsck -f -n "${LOOP}p2" > "$LOGD/20-e2fsck.log" 2>&1 || { echo "DURDU: e2fsck hata"; exit 1; }
echo "M11 koşucu TAMAM: img=$IMG uuid=$UUID"
