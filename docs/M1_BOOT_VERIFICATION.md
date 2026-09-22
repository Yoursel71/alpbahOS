# M01 / BOOT-01 — Önyükleme doğrulaması

Tarih: 22 Eylül 2026  
Builder: Ubuntu 24.04.5 LTS, Hyper-V misafiri, x86_64  
Temel sistem: LFS 12.4-systemd x86_64  
Artifact: `artifacts/alpbahOS-m1-bootable.vhdx`

## Disk ve önyükleme düzeni

20 GiB GPT disk üç bölüm kullanır: BIOS boot (`sda1`), EFI System Partition (`sda2`) ve ext4 root (`sda3`). GRUB 2.12 hem i386-pc hem x86_64-efi hedefiyle kuruldu. Kernel `6.16.1-alpbahOS` ve systemd 257.8 içerir.

İlk testte `root=UUID=...` kullanılmıştı. Bu imaj initramfs içermediği için kernel bu UUID değerini tek başına aygıta dönüştüremedi; disk bulunmasına rağmen root mount başarısız oldu. Hedef disk denetleyicisinde kök bölüm `sda3` olduğundan GRUB kernel satırı şu şekilde düzeltildi:

```text
root=/dev/sda3 rootfstype=ext4 rootwait ro console=tty0 console=ttyS0,115200n8
```

## Kanıtlanan sonuçlar

| Test | Sonuç |
|---|---|
| BIOS/QEMU, VHDX, IDE disk | Geçti: GRUB, kernel, ext4 root mount, systemd, `alpbahos login:` |
| UEFI/OVMF, VHDX, ATA disk | Geçti: GRUB, kernel, ext4 root mount, systemd, `alpbahos login:` |
| Kök dosya sistemi | `/dev/sda3`, UUID `5ffe83c9-83e8-4955-8584-dc21a80d42ff`, ext4 mount kanıtlandı |
| VHDX checksum | `5816717f6777595e924be419bd5117381d4cf129313ec3ecb6314c0a29c92b92` |

QEMU testleri donanım emülasyonudur. Hyper-V Gen1 ve Gen2'de gerçek açılış, ağ ve yeniden başlatma henüz ayrı bir kabul kontrolüdür. Bu imaj grafik masaüstü, canlı ISO veya kurucu içermez; bunlar sonraki aşamalardadır.
