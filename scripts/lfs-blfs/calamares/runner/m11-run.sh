#!/bin/bash
# M11 modül koşucusu (alpbahOS, Calamares 3.3.14 loadmodule).
#
# Ne yapar: yeni bir sanal disk dosyasını (yalnız bu dosya) loop aygıtına bağlar,
# GPT bölümleri açar, kök bölümünü /var/tmp/m11-target'a bağlar (sanal dosya
# sistemleri dahil), sonra kurucu modüllerini LFS chroot'unda (/mnt/lfs) TEK TEK
# çalıştırır: unpackfs, machineid, localecfg, fstab, networkcfg, hwclock, grubcfg,
# bootloader, umount.
#
# Önyükleme modu M11_FIRMWARE ile seçilir (varsayılan bios):
#  - bios: p1 BIOS boot (1 MiB) + p2 ext4 kök. Kanıt: docs/verification/m11-d144-*.
#  - uefi: p1 EFI System 512 MiB (FAT32, /boot/efi) + p2 ext4 kök. Ayrıntı ve
#          QEMU/OVMF komutu: runner/README.md.
#
# Sınırlar (kanıt belgesinde sapma olarak yazılır):
#  - Bölümleme, mkfs ve kök bağlama bu betikte yapılır; Calamares'in partition ve
#    mount modülleri koşmaz (mount modülü kendi geçici kök dizinini açar, gs'i
#    değiştirir; başsız koşucuda sonraki modüller yanlış kökü görür).
#  - UEFI: ESP, unpackfs'ten sonra ve bootloader'dan hemen önce bu betikte bağlanır
#    (gerçek Calamares'te mount modülü bağlar). rsync'in FAT üzerinde izin/sahiplik
#    hatası vermemesi için bilinçli sapma.
#  - locale ve keyboard GUI görünüm modülleridir; başsız koşmaz.
#  - Kurulum canlı ISO içinde değil, ana makinedeki LFS chroot'unda koşar.
#  - Önyükleme kanıtı ayrı bir VM oturumunda (-cdrom yok) yapılır.
#  - UEFI NVRAM güvenliği: grub-install --no-nvram sarmalayıcısı (yalnız hedefte,
#    bootloader adımı süresince), efivarfs bağlı olmaması denetimi, efiBootMgr=/usr/bin/false.
#
# Kullanım: sudo bash m11-run.sh <YENİ-hedef.img> <log-dizini>
#           sudo M11_FIRMWARE=uefi bash m11-run.sh <YENİ-hedef.img> <log-dizini>
set -eu

IMG=${1:?kullanım: m11-run.sh <yeni-hedef.img> <log-dizini>}
LOGD=${2:?kullanım: m11-run.sh <yeni-hedef.img> <log-dizini>}
R=$(dirname "$(readlink -f "$0")")
LFS=/mnt/lfs
# Squashfs source: override with M11_SQUASHFS=<path> (e.g. the output of live-iso/build-iso.sh).
SQ=${M11_SQUASHFS:-/home/yrslf/alpbahOS/scratch-lfs-bench/alp-iso/LiveOS/squashfs.img}
# M11_HOSTTOOLS=0: use the chroot's own rsync/unsquashfs (packages 339/340) instead of the Fedora copies.
HOSTTOOLS=${M11_HOSTTOOLS:-1}
# M11_FIRMWARE=bios|uefi (varsayılan bios). BIOS yolu değişmeden kalır.
FW=${M11_FIRMWARE:-bios}
TOOLS=/home/yrslf/alpbahOS/scratch-lfs-bench/m11-runner/hosttools
CAL=/sources/blfs-build/calamares-3.3.14/build/loadmodule
TARGET_IN_CHROOT=/var/tmp/m11-target
TGT="$LFS$TARGET_IN_CHROOT"
# UEFI: grub-install sarmalayıcısı (yalnız hedefte, bootloader adımı süresince).
WRAP_REL=/usr/local/sbin/grub-install-no-nvram
WRAP="$TGT$WRAP_REL"
# ESP bağlama seçenekleri (Calamares mount.conf örneğindeki efi girişiyle aynı).
ESP_MOUNT_OPTS="defaults,umask=0077"
LOOP=""
SQ_BIND=0
TOOLS_BIND=0
MADE_LIVE_DIR=0
WRAP_MADE=0
SBIN_MADE=0

target_unmount() {
    if mountpoint -q "$TGT"; then umount -R "$TGT"; fi
}

cleanup() {
    set +e
    # Sarmalayıcı hedef hâlâ bağlıyken kaldırılır (hata çıkışında da).
    if [ "$WRAP_MADE" = 1 ] && [ -e "$WRAP" ]; then rm -f "$WRAP"; fi
    if [ "$SBIN_MADE" = 1 ]; then rmdir "$TGT/usr/local/sbin" "$TGT/usr/local" 2>/dev/null; fi
    target_unmount
    # unpackfs, squashfs'i kendi geçici dizininde bağlar; hata çıkışında kalabilir.
    for d in "$LFS"/tmp/tmp*/squashfs; do
        [ -d "$d" ] && mountpoint -q "$d" && umount "$d"
        rmdir "$d" "${d%/squashfs}" 2>/dev/null
    done
    if [ "$SQ_BIND" = 1 ]; then umount "$LFS/usr/lib/live/mount/medium/LiveOS/squashfs.img"; fi
    if [ "$MADE_LIVE_DIR" = 1 ]; then rm -rf "$LFS/usr/lib/live"; fi
    if [ "$TOOLS_BIND" = 1 ]; then umount "$LFS/run/m11tools"; fi
    if [ "${HOSTTOOLS:-1}" != 1 ]; then rm -f "$LFS/run/m11tools/bin/rsync"; fi
    if [ -n "$LOOP" ]; then losetup -d "$LOOP"; fi
    # Boş bağlama noktasını bu koşucu açtı; kalıntı bırakma.
    rmdir "$TGT" 2>/dev/null || true
}
trap cleanup EXIT
trap 'echo "M11 koşucu HATA: satır $LINENO" >&2' ERR

# NVRAM koruması (UEFI): efivars dizinleri boş olmalı ve LFS altında efivarfs bağlı olmamalı.
# Boş efivars = efivarfs bağlı değil; bu durumda grub-install hiçbir değişkeni okuyup yazamaz.
efi_guard() {
    local d
    for d in "$LFS/sys/firmware/efi/efivars" "$TGT/sys/firmware/efi/efivars"; do
        if [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ]; then
            echo "DURDU (NVRAM koruması): $d boş değil; efivarfs bağlı olabilir" >&2
            return 1
        fi
    done
    if awk -v p="$LFS" '$3 == "efivarfs" && index($2, p) == 1 { f = 1 } END { exit !f }' /proc/self/mounts; then
        echo "DURDU (NVRAM koruması): $LFS altında efivarfs bağlı" >&2
        return 1
    fi
    return 0
}

[ "$(id -u)" = 0 ] || { echo "root gerekli"; exit 1; }
case "$FW" in
    bios|uefi) ;;
    *) echo "DURDU: M11_FIRMWARE=bios veya uefi olmalı (verilen: $FW)"; exit 1 ;;
esac
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
if [ "$HOSTTOOLS" = 1 ]; then
    [ -x "$TOOLS/bin/rsync" ] && [ -x "$TOOLS/bin/unsquashfs" ] || { echo "ön koşul: $TOOLS eksik (devir 024)"; exit 1; }
else
    [ -x "$LFS/usr/bin/rsync" ] && [ -x "$LFS/usr/bin/unsquashfs" ] || { echo "ön koşul: chroot rsync/unsquashfs yok (paket 339/340)"; exit 1; }
fi
[ -f "$SQ" ] || { echo "ön koşul: squashfs yok: $SQ"; exit 1; }
mkdir -p "$LOGD"
if [ "$FW" = uefi ]; then
    # UEFI ön koşulları: dosyalar chroot'taki paketlerden gelir (dosyalar yoksa dur).
    [ -x "$LFS/usr/sbin/mkfs.vfat" ] && [ -x "$LFS/usr/sbin/fsck.vfat" ] \
        || { echo "ön koşul: $LFS/usr/sbin/{mkfs,fsck}.vfat yok (dosfstools paketi, UEFI modu)"; exit 1; }
    [ -x "$LFS/usr/sbin/grub-install" ] && [ -d "$LFS/usr/lib/grub/x86_64-efi" ] \
        || { echo "ön koşul: GRUB x86_64-efi kurulumu yok ($LFS/usr/lib/grub/x86_64-efi)"; exit 1; }
    efi_guard || { echo "DURDU: UEFI NVRAM ön denetimi başarısız (yukarıya bakın)"; exit 1; }
fi

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
echo "loop=$LOOP img=$IMG fw=$FW" | tee "$LOGD/00-loop.log"
if [ "$FW" = uefi ]; then
    # p1: ESP 512 MiB (1048576 sektör), p2: kök (1050624 = 2048'in katı).
    printf 'label: gpt\nstart=2048, size=1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="esp"\nstart=1050624, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="alproot"\n' \
        | chroot "$LFS" sfdisk --wipe always "$LOOP" > "$LOGD/01-sfdisk.log" 2>&1
else
    printf 'label: gpt\nstart=2048, size=2048, type=21686148-6449-6E6F-744E-656564454649, name="bios"\nstart=4096, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="alproot"\n' \
        | chroot "$LFS" sfdisk --wipe always "$LOOP" > "$LOGD/01-sfdisk.log" 2>&1
fi
partprobe "$LOOP"
sleep 1
[ -b "${LOOP}p2" ] || { echo "${LOOP}p2 yok"; exit 1; }
if [ "$FW" = uefi ]; then
    [ -b "${LOOP}p1" ] || { echo "${LOOP}p1 yok"; exit 1; }
    chroot "$LFS" /usr/sbin/mkfs.vfat -F 32 -n ALPESP "${LOOP}p1" > "$LOGD/02-mkfs-esp.log" 2>&1
    ESP_UUID=$(blkid -s UUID -o value "${LOOP}p1" || true)
    ESP_PUUID=$(blkid -s PARTUUID -o value "${LOOP}p1" || true)
    [ -n "$ESP_UUID" ] && [ -n "$ESP_PUUID" ] || { echo "DURDU: ESP UUID/PARTUUID okunamadı (${LOOP}p1)"; exit 1; }
    echo "esp_uuid=$ESP_UUID esp_partuuid=$ESP_PUUID" | tee -a "$LOGD/02-mkfs-esp.log"
fi
chroot "$LFS" mkfs.ext4 -q -F -L alpbah-root "${LOOP}p2" > "$LOGD/02-mkfs.log" 2>&1
UUID=$(blkid -s UUID -o value "${LOOP}p2")
PUUID=$(blkid -s PARTUUID -o value "${LOOP}p2")
echo "partuuid=$PUUID" | tee -a "$LOGD/02-mkfs.log"
echo "root_uuid=$UUID" | tee -a "$LOGD/02-mkfs.log"

# 2) Chroot içi girdiler: araç köprüsü, squashfs (ISO'daki yolla aynı), hedef kök.
mkdir -p "$LFS/run/m11tools" "$TGT" "$LFS/root/m11-runner"
if [ "$HOSTTOOLS" = 1 ]; then mount --bind "$TOOLS" "$LFS/run/m11tools"; TOOLS_BIND=1
else
    # Test-host only: Fedora runs SELinux, so the kernel labels every file written to the
    # loop-mounted target and rsync -X then fails to remove security.selinux (exit 23,
    # 2026-11-06). The live ISO has no SELinux, so the product rsync call is unchanged; this
    # wrapper (on $LFS/run, a tmpfs) only adds a filter for that one xattr.
    mkdir -p "$LFS/run/m11tools/bin"
    printf '%s\n' '#!/bin/sh' 'exec /usr/bin/rsync --filter="-x security.selinux" "$@"' > "$LFS/run/m11tools/bin/rsync"
    chmod 755 "$LFS/run/m11tools/bin/rsync"
fi
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
if [ "$FW" = uefi ]; then
    efi_guard || { echo "DURDU: UEFI NVRAM denetimi (hedef sysfs bağlandıktan sonra) başarısız"; exit 1; }
fi

# 3) Koşucu girdileri (ürün yapılandırmasının kopyası; yalnız çekirdek arama yolu ve test konsolu).
cp "$R/settings.conf" "$LFS/root/m11-runner/settings.conf"
# Modül yapılandırmaları repodan kopyalanır (chroot'taki /etc kopyası kullanılmaz).
install -m 644 "$R/../modules/bootloader.conf" "$LFS/root/m11-runner/bootloader.conf"
install -m 644 "$R/../modules/grubcfg.conf" "$LFS/root/m11-runner/grubcfg.conf"
# Yalnız test: seri konsol parametresi (ürün kararı değil).
sed -i 's|^kernelParams:.*|kernelParams: [ "quiet", "console=tty0", "console=ttyS0,115200n8" ]|' \
    "$LFS/root/m11-runner/bootloader.conf"
if [ "$FW" = uefi ]; then
    # Yalnız koşucu kopyası: grub-install sarmalayıcıyı çağırır, efibootmgr yerine /usr/bin/false.
    # Repodaki ürün bootloader.conf'u değişmez.
    sed -e 's|^grubInstall:.*|grubInstall: "/usr/local/sbin/grub-install-no-nvram"|' \
        -e 's|^efiBootMgr:.*|efiBootMgr: "/usr/bin/false"|' \
        "$LFS/root/m11-runner/bootloader.conf" > "$LFS/root/m11-runner/bootloader-uefi.conf"
    grep -qx 'grubInstall: "/usr/local/sbin/grub-install-no-nvram"' "$LFS/root/m11-runner/bootloader-uefi.conf" \
        && grep -qx 'efiBootMgr: "/usr/bin/false"' "$LFS/root/m11-runner/bootloader-uefi.conf" \
        && grep -qx 'efiBootLoader: "grub"' "$LFS/root/m11-runner/bootloader-uefi.conf" \
        && grep -qx 'installEFIFallback: true' "$LFS/root/m11-runner/bootloader-uefi.conf" \
        || { echo "DURDU: UEFI bootloader-uefi.conf beklenen anahtarları içermiyor"; exit 1; }
fi
if [ "$FW" = uefi ]; then
cat > "$LFS/root/m11-runner/gs.yaml" <<EOF
rootMountPoint: "$TARGET_IN_CHROOT"
partitions:
  - device: "${LOOP}p2"
    fs: "ext4"
    mountPoint: "/"
    uuid: "$UUID"
    claimed: true
  - device: "${LOOP}p1"
    fs: "fat32"
    mountPoint: "/boot/efi"
    uuid: "$ESP_UUID"
    partuuid: "$ESP_PUUID"
    claimed: true
bootLoader:
  installPath: null
localeConf:
  LANG: "tr_TR.UTF-8"
mountOptionsList:
  - mountpoint: "/"
    option_string: "defaults,noatime"
  - mountpoint: "/boot/efi"
    option_string: "$ESP_MOUNT_OPTS"
efiSystemPartition: "/boot/efi"
firmwareType: "efi"
branding:
  bootloaderEntryName: "alpbahOS"
  productName: "alpbahOS"
EOF
else
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
fi

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
# M11-FIX-02: /tmp (1777) and /root must come from the squashfs. Without them the
# installed system's first boot fails PrivateTmp/ProtectSystem units with 226/NAMESPACE
# while / is still read-only. The squashfs must be built with build-iso.sh.
[ -d "$TGT/tmp" ] && [ "$(stat -c %a "$TGT/tmp")" = 1777 ] && [ -d "$TGT/root" ] \
    || { echo "DURDU: unpackfs sonrası hedef kökte /tmp (1777) veya /root yok (M11-FIX-02). squashfs scripts/lfs-blfs/live-iso/build-iso.sh ile üretilmeli."; exit 1; }
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

if [ "$FW" = uefi ]; then
    # fstab ESP satırı: fstab modülü ESP'yi gs'deki mountPoint'ten yazar.
    grep -q "^UUID=$ESP_UUID[[:space:]]\+/boot/efi[[:space:]]\+vfat[[:space:]]" "$TGT/etc/fstab" \
        || { echo "DURDU: fstab ESP satırı yok (UUID=$ESP_UUID /boot/efi vfat)"; exit 1; }
    # ESP'yi bootloader'dan önce bağla: grub-install ve EFI dosyaları burada yazılır.
    # Bağlama noktası boş değilse bağlama onu gizler; bu yüzden dur.
    if [ -d "$TGT/boot/efi" ] && [ -n "$(ls -A "$TGT/boot/efi")" ]; then
        echo "DURDU: $TGT/boot/efi boş değil; ESP bağlanırsa içeriği gizlenir"; exit 1
    fi
    mkdir -p "$TGT/boot/efi"
    mount -t vfat -o "$ESP_MOUNT_OPTS" "${LOOP}p1" "$TGT/boot/efi"
    mountpoint -q "$TGT/boot/efi" || { echo "DURDU: ESP $TGT/boot/efi bağlanamadı"; exit 1; }
    # grub-install sarmalayıcısı: --no-nvram ekler, host NVRAM'ine dokunmaz.
    [ -x "$TGT/usr/sbin/grub-install" ] || { echo "DURDU: hedefte /usr/sbin/grub-install yok"; exit 1; }
    [ ! -e "$WRAP" ] || { echo "DURDU: $WRAP zaten var"; exit 1; }
    if [ ! -d "$TGT/usr/local/sbin" ]; then mkdir -p "$TGT/usr/local/sbin"; SBIN_MADE=1; fi
    printf '%s\n' '#!/bin/sh' \
        '# alpbahOS M11 koşucusu: grub-install host NVRAM değişkenlerine dokunmasın (geçici).' \
        'exec /usr/sbin/grub-install --no-nvram "$@"' > "$WRAP"
    chmod 755 "$WRAP"
    WRAP_MADE=1
    BL_CONF=/root/m11-runner/bootloader-uefi.conf
else
    BL_CONF=/root/m11-runner/bootloader.conf
fi
run_mod bootloader "$BL_CONF"
if [ "$FW" = uefi ]; then
    # Sarmalayıcı yalnız bootloader adımında var olmalı; şimdi kaldır.
    rm -f "$WRAP"
    WRAP_MADE=0
    [ ! -e "$WRAP" ] || { echo "DURDU: sarmalayıcı kaldırılamadı: $WRAP"; exit 1; }
    if [ "$SBIN_MADE" = 1 ]; then rmdir "$TGT/usr/local/sbin" "$TGT/usr/local" 2>/dev/null || true; fi
    efi_guard || { echo "DURDU: UEFI NVRAM denetimi (bootloader sonrası) başarısız"; exit 1; }
fi
grep -q "root=PARTUUID=$PUUID" "$TGT/boot/grub/grub.cfg" \
    || { echo "DURDU: grub.cfg root=PARTUUID=$PUUID içermiyor"; exit 1; }
grep -q "console=ttyS0,115200n8" "$TGT/boot/grub/grub.cfg" \
    || { echo "DURDU: grub.cfg seri konsol parametresi yok"; exit 1; }
if [ "$FW" = uefi ]; then
    ESPM="$TGT/boot/efi"
    mountpoint -q "$ESPM" || { echo "DURDU: ESP bootloader sonrası bağlı değil"; exit 1; }
    [ -f "$ESPM/EFI/alpbahOS/grubx64.efi" ] \
        || { echo "DURDU: EFI/alpbahOS/grubx64.efi yok"; exit 1; }
    # FAT büyük/küçük harf duyarsızdır; Calamares fallback dizinini küçük harfle de açabilir.
    FB=$(find "$ESPM/EFI" -mindepth 2 -maxdepth 2 -type f -ipath '*/boot/bootx64.efi' | head -1)
    [ -n "$FB" ] || { echo "DURDU: EFI/BOOT/BOOTX64.EFI yok (fallback)"; exit 1; }
    cmp -s "$ESPM/EFI/alpbahOS/grubx64.efi" "$FB" \
        || { echo "DURDU: fallback BOOTX64.EFI, grubx64.efi ile aynı değil"; exit 1; }
    echo "[uefi-post] esp ok: $FB" | tee "$LOGD/12-uefi-post.log"
fi
run_mod umount /etc/calamares/modules/umount.conf

# Son denetim: hedef bağlı kalmamalı; dosya sistemi temiz olmalı.
target_unmount
sync
e2fsck -f -n "${LOOP}p2" > "$LOGD/20-e2fsck.log" 2>&1 || { echo "DURDU: e2fsck hata"; exit 1; }
if [ "$FW" = uefi ]; then
    chroot "$LFS" /usr/sbin/fsck.vfat -n "${LOOP}p1" > "$LOGD/21-fsck-vfat.log" 2>&1 \
        || { echo "DURDU: fsck.vfat hata (ESP)"; exit 1; }
    echo "M11 koşucu TAMAM (UEFI): img=$IMG uuid=$UUID esp_uuid=$ESP_UUID"
else
    echo "M11 koşucu TAMAM: img=$IMG uuid=$UUID"
fi
