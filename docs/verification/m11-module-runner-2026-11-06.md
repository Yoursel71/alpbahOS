# M11 modül koşucusu: kurulum kanıtı (6 Kasım 2026)

Durum: **M11 KISMİ KABUL.** BIOS sanal diske kurulum ve giriş istemine kadar önyükleme kanıtlandı. UEFI, GUI kurucu tıklama testi ve ağ servislerinin düzeltilmesi açık.

## İşe başlama kaydı

- Görev: M11 kurulum kabulü, yöntem 2 (kurulum modüllerini doğrudan çalıştıran koşucu). Yöntem kullanıcı tarafından seçildi (devir notu 023, açık madde 1).
- Sahiplik: `docs/BACKLOG.md` INSTALL-01 Codex'e ait. Görev bu oturumda kullanıcı tarafından Claude'a doğrudan verildi.
- Ortam: Fedora ana makine (QEMU/KVM), LFS chroot `/mnt/lfs` yerel. Ana makine kapatılmadı.
- Sınırlar: VM oturumu başına bir açılış, en fazla bir saat (kullanıcı onayı). Hedef yalnız yeni bir sanal disk dosyası; `alp-target.img` yazılmadı.

## Üretilen dosyalar

| Dosya | Açıklama |
|---|---|
| `scripts/lfs-blfs/calamares/runner/m11-run.sh` | Koşucu: sanal disk, bölümleme, kök bağlama, modül sırası, doğrulamalar |
| `scripts/lfs-blfs/calamares/runner/settings.conf` | Test sekansının ayarı (VM `/root/cal-test` kopyası + eksik zorunlu anahtarlar) |
| `docs/verification/m11-boot-serial-2026-11-06.log` | Son önyüklemenin seri günlüğü (giriş istemi, ANSI kodları temizlendi) |
| `docs/verification/m11-calamares-chain-2026-11-05.md` | Önceki zincir belgesi (değişmedi; yol notu aşağıda) |

Ana makine scratch (repo dışı): `scratch-lfs-bench/m11-runner/` içinde `logs-1` ... `logs-12` (her deneme), `hosttools/` (rsync/unsquashfs köprüsü), `m11-target.img` (son hedef, 20 GB sparse).

## Son koşu (logs-12)

Tüm modüller rc=0 ve günlük denetimi temiz:

- unpackfs (squashfs `/lib/live/mount/medium/LiveOS/squashfs.img`, ISO ile aynı dosya), rm-live-initramfs, machineid, localecfg, fstab, networkcfg, hwclock, grubcfg, bootloader, umount.
- Hedef doğrulamaları (koşucu içinde): `/etc/fstab` kök satırı `UUID=…`, `grub.cfg` içinde `root=PARTUUID=…` ve `console=ttyS0,115200n8`.
- Çevrimdışı kontrol: `e2fsck -fn` temiz. MBR imzası `55 aa`. `bios_grub` bölümünde GRUB core (`52 56 be 1b…`). `/boot`: `vmlinuz-6.16.1-lfs-12.4-systemd`, `config`, `System.map`. Canlı `initramfs-live` kaldırıldı.

## Önyükleme kanıtı

| Oturum | Açılış | Sonuç |
|---|---|---|
| A | 10:49 | QEMU hedef dosyayı açamadı (`Permission denied`; dosya root sahipli). Önyükleme olmadı. Dosya sahibi düzeltildi. |
| B | 10:51 | Kernel panic: `VFS: Unable to mount root fs on unknown-block(0,0)`. Sebep: `root=UUID=` initramfs olmadan çözülmez. Ekran görüntüsü alındı, VM kapatıldı (QEMU çıkış 0). |
| C | 10:58 | **Giriş istemi:** `alpbahos login:` (seri, ttyS0). Kernel 6.16.1 x86_64. Başarısız birimler: `systemd-oomd`, `systemd-resolved` (namespace hatası, `/tmp`). ACPI ile kapatıldı (`reboot: Power down`). |

**Not (sapma):** Oturum B ile C arasında bir kez daha açılış yapıldı. Kural "oturum başına 1 açılış" idi. Kullanıcı bunu bilmeli ve onaylamalıdır. Oturum C 45 dakikalık sınırın içinde kaldı (yaklaşık bir dakika çalıştı, giriş istemi görülünce kapatıldı).

## Düzeltilen sorunlar (12 deneme)

1. `mount` modülü kendi geçici kökünü açıp gs'teki `rootMountPoint`'i değiştiriyor. Sonraki modüller boş dizini görüp `grub-install` 127 döndü. Çözüm: kök betikte bağlandı, `mount` modülü atlandı.
2. `loadmodule` iş hatalarında da 0 dönebiliyor (`umount` 32, `fstab` "Configuration Error"). Çözüm: günlük denetimi (`check_log`) ve dosya bazlı doğrulama.
3. Fedora ana makinede `squashfs` modülü yüklü değildi. unpackfs hiçbir şey kopyalamadan rc=0 döndü. Çözüm: `modprobe squashfs` (koşudan sonra `rmmod`).
4. Chroot'ta `rsync`, `unsquashfs` ve bazı kütüphaneler yoktu; `libacl` sürümü de eskiydi. Çözüm: `hosttools/` köprüsü. Sarmalayıcılar `LD_LIBRARY_PATH`'i yalnız kendi ikililerine verir, hedefin GRUB'ı etkilenmez.
5. `locale` ve `keyboard` GUI görünüm modülleri; başsız koşmaz. Çözüm: atlandı, `localecfg` gs `localeConf` ile koşar.
6. `fstab` `mountOptionsList` ister; `grubcfg` `firmwareType` ve `branding.bootloaderEntryName` ister. Eksikken hata döner ama dosya yazılmaz. Çözüm: gs'e eklendi, dosya sonuçları doğrulanır.
7. `grub-mkconfig` kök aygıtı host loop yolu (`/dev/loop0p2`) olarak yazdı. Çözüm: `GRUB_DEVICE`. Ara deneme olarak `/dev/disk/by-uuid` bağlantısı denendi; başsız loop'ta udev bağlantı üretmediği için başarısız oldu ve kaldırıldı.
8. Kurulu sistemde initramfs yok. Kernel `root=UUID=`'yi çözemez (kanıt: oturum B). Çözüm: `root=PARTUUID=…` (kernel `CONFIG_EFI_PARTITION=y` ile GPT'yi kendisi okur).
9. Test amaçlı seri konsol (`console=ttyS0,115200n8`) GRUB'a eklendi. Ürün kararı değildir.

## Sapmalar (kabul kapsamı)

- Bölümleme (sfdisk: GPT, BIOS boot 1 MiB, ext4 kök), mkfs ve kök bağlama betikte yapıldı. `partition` modülü koşmadı.
- `mount`, `locale` ve `keyboard` modülleri koşmadı. `users` ve `services-systemd` test sekansında yok.
- Kurulum canlı ISO içinde değil, ana makinedeki LFS chroot'unda koştu. ISO'nun kendisiyle kurulum testi yapılmadı.
- Kök aygıt PARTUUID ile yazıldı (initramfs yok). Bu bir ürün kararı gerektirir (aşağıda).
- UEFI: test edilmedi (OVMF yok, bu oturumda ESP oluşturulmadı).
- Kurulumdan sonra SDDM/oturum kontrolü yapılmadı. Giriş istemine kadar kanıtlandı.

## Ürün açıkları (Codex alanı; bu oturumda değiştirilmedi)

1. `scripts/lfs-blfs/calamares/settings.conf` sekansında `grubcfg` yok. Bu olmadan GRUB kök aygıtını host yolu olarak yazar. Ekle: `grubcfg` (bootloader'dan önce).
2. `bootloader.conf` (kaynak varsayılanı) `kernelSearchPath: /usr/lib/modules` kullanıyor. Kernel bu rootfs'te `/boot` altında. Değer `/boot` olmalı.
3. Kurulu sistem initramfs'siz. Bootloader `root=UUID=` yazıyor ve çekirdek bunu çözemiyor. Seçenekler: `root=PARTUUID=` (bu kanıtta kullanıldı) ya da alplive hook'u olmayan bir initramfs (dracut).
4. `unpackfs` squashfs desteği yoksa sessizce rc=0 dönüyor. Bu yanıltıcı; hata vermeli.
5. Canlı ISO'da `rsync` ve `unsquashfs` (squashfs-tools) olmalı. ISO içinde doğrulanmadı.
6. Kurulu sistemde `systemd-oomd` ve `systemd-resolved` başarısız. Namespace hatası (`/tmp` bağlama, `/usr/lib/systemd/...` "No such file"). Kök neden doğrulanmadı. Bu, ağ çözümlemesini (DNS) etkiliyor.
7. Devir notu 023 M11 yolunu `/run/live/medium/…` olarak yazıyor. Ürün yapılandırması `/lib/live/mount/medium/LiveOS/squashfs.img` (M09 ile tutarlı). Yol notu doğru olarak bu.

## Açık işler (M11 tam kabul için)

- UEFI kurulum ve önyükleme (OVMF, ESP).
- Calamares GUI tıklama testi (ayrıca yöntem 1; isteğe bağlı).
- Ürün sekansının (`grubcfg`, `kernelSearchPath`, PARTUUID/initramfs kararı) düzeltilip bu koşucuyla yeniden kanıtlanması.
- Ağ servisleri (`systemd-resolved`, `systemd-oomd`) düzeltilip giriş ve ağ kanıtı.
- Canlı ISO içinde kurulum testi (rsync/unsquashfs dahil).

## Test sırları

Bu oturumda parola yazılmadı ve kullanılmadı. `users` modülü test sekansında yok. Kök parolası `test-secrets/root.pw` içinde kalır.
