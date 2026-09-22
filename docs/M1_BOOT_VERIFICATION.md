# M01 / BOOT-01 — Önyükleme doğrulaması

Tarih: 22 Eylül 2026  
Builder: Ubuntu 24.04.5 LTS, Hyper-V misafiri, x86_64  
Temel sistem: LFS 12.4-systemd x86_64  
Son artifact: `artifacts/alpbahOS-m1-final-v2.vhdx`

## Disk ve önyükleme düzeni

20 GiB GPT disk üç bölüm kullanır: BIOS boot (`sda1`), EFI System Partition (`sda2`) ve ext4 root (`sda3`). GRUB 2.12 hem i386-pc hem x86_64-efi hedefiyle kuruldu. Kernel `6.16.1-alpbahOS` ve systemd 257.8 içerir.

İlk testte `root=UUID=...` kullanılmıştı. Bu imaj initramfs içermediği için kernel bu UUID değerini tek başına aygıta dönüştüremedi; disk bulunmasına rağmen root mount başarısız oldu. Hedef disk denetleyicisinde kök bölüm `sda3` olduğundan GRUB kernel satırı şu şekilde düzeltildi:

```text
root=/dev/sda3 rootfstype=ext4 rootwait ro console=tty0
```

## Kanıtlanan sonuçlar

| Test | Sonuç |
|---|---|
| BIOS/QEMU, VHDX, IDE disk | Geçti: GRUB, kernel, ext4 root mount, systemd, `alpbahos login:` |
| UEFI/OVMF, VHDX, ATA disk | Geçti: GRUB, kernel, ext4 root mount, systemd, `alpbahos login:` |
| Hyper-V Gen2, UEFI/SCSI | Geçti: GRUB, `6.16.1-alpbahOS`, framebuffer konsolu ve `alpbahos login:` kullanıcı görüntüsüyle doğrulandı |
| Hyper-V ağı | Geçti: Default Switch üzerinden DHCP; yeniden başlatma sonrası `172.28.166.77`; hosttan iki ICMP isteği başarılı |
| Kontrollü kapatma/yeniden açma | Geçti: Hyper-V entegrasyonuyla `Running -> Off -> Running`; yeniden açılışta heartbeat `Tamam` ve ping başarılı |
| Kök dosya sistemi | `/dev/sda3`, UUID `5ffe83c9-83e8-4955-8584-dc21a80d42ff`, ext4 mount kanıtlandı |
| Son VHDX checksum | SHA-256 `07123bf1e653e8b735e6c68324fed20d2402f68ba39657d30a521738f37ade86` |

İlk Hyper-V denemesinde ağ önyüklemesi diskin önündeydi; firmware sırası `Drive,Network` olarak düzeltildi. Yazılmakta olan raw imajdan üretilen bir ara VHDX ext4 bitmap hataları verdi. Son imaj daha önce doğrulanmış tabandan yeniden üretildi; FAT ve ext4 bölümleri çevrimdışı `fsck` ile hatasız kontrol edildi. `/etc/shadow`, root kurtarma hesabı, systemd ağ kullanıcıları ve DHCP ağ profili tamamlandı. Otomatik Hyper-V checkpoint'leri test VM'inde kapatıldı.

M1 temel boot imajı tamamlandı. BOOT-01'in Hyper-V Gen1 kolu ile grafik masaüstü, canlı ISO ve kurucu sonraki aşamalardadır. Secure Boot bu geliştirme imajında kapalıdır.
