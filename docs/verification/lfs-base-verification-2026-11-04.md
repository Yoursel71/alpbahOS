# LFS 12.4-systemd temel sistem doğrulaması (2026-11-04)

## Önyükleme
- BIOS (i386-pc, SeaBIOS): GRUB -> kernel 6.16.1-lfs -> systemd -> `alpbahos login:` (seri + VGA).
- UEFI (x86_64-efi, OVMF, `--removable`): `/sys/firmware/efi` mevcut; `alpbahos login:`.
- Kök: sda2 ext4; ESP: sda3 vfat (/boot/efi). Disk imajı: ~/alpbahOS/scratch-lfs-bench/disk.img (gerçek disk kullanılmadı).

## Servisler (seri konsol)
- `systemctl is-system-running` -> running; `systemctl --failed` -> 0 birim.
- Aktif: getty@tty1, serial-getty@ttyS0, systemd-networkd, systemd-resolved, dbus, systemd-journald, systemd-udevd.
- Ağ: DHCP (`10.0.2.15/24`, gateway 10.0.2.2, DNS 10.0.2.3) -- `Name=en* eth*` düzeltmesiyle (QEMU NIC'i eth0).
- Root: parola alanı boş; seri/VGA'dan parolasız giriş çalışıyor.

## Bilinen test başarısızlıkları (13 kayıt, 12 paket) -- sınıflandırma
Kanıtlar: paketlerin kendi test logları (/mnt/lfs/sources/<paket>/...).

| Paket | Test | Sınıf | Kanıt / not |
|---|---|---|---|
| M4 1.4.20 | test-execute.sh (case 5) | belirsiz (gnulib) | gettext ile aynı test; posix_spawn ENOENT |
| Attr 2.5.2 | test/root/getfattr | ortam (host FS) | security.selinux etiketi; build dizini btrfs+SELinux |
| Acl 2.3.2 | test/cp | ortam (host FS) | cp -p sonrası `+` (ACL) işareti |
| Gettext 0.26 | test-execute.sh | belirsiz (gnulib) | M4 ile aynı hata |
| Autoconf 2.72 | parallel autotest + signal | ortam/kararsız | 5 hatanın 4'ü beklenen; 1 sinyal testi |
| Elfutils 0.193 | dwarf_srclang_check | bağımlılık yolu | libelf.so.1 test sırasında bulunamadı (rpath/LD_LIBRARY_PATH) |
| Python 3.13.7 | test_socket UDPLITE | kernel/ortam | UDP-Lite soket testleri; kernel yapılandırması incelenmedi |
| Tar 1.35 | capabilities binary store/restore | ortam (host FS) | security.capability xattr |
| Vim 9.1.1629 | Test_writedelay | zamanlama | 1 ms bekleyen gecikme, beklenen 0.3-999 |
| Systemd 257.8 | test-fd-util, test-mount-util (ninja) | chroot kısıtı | SIGABRT; mount/yetki ihtiyacı |
| Procps-ng 4.0.5 | pmap "same total" | kararsız | bellek haritası yarışı (ilk eşleşme) |
| Util-linux 2.41.1 | lsfd/option-inet | chroot/ağ kısıtı | süresiz asılı kaldı; harness durduruldu |

Yorum: 9 kayıt host dosya sistemi (btrfs+SELinux), zamanlama, chroot kısıtı veya kararsızlıktan kaynaklanıyor görünüyor.
M4/Gettext'teki gnulib testi ve Elfutils'teki libelf yolu gerçek bir yapılandırma sorunu olabilir; ayrıca incelenmeli.
Bu sınıflandırma kanıta dayanıyor ama her test için tekrar koşulmadı.

## Açık kalanlar (alpbahOS geliştirmeye hazır değil)
- BLFS/KDE Plasma masaüstü: yok. M07-M10 (gerçek oturum, canlı ISO, kurulum) bu aşamaya bağlı.
- Test başarısızlıklarının tekrar koşulması ve gnulib/elfutils düzeltmesi.
- Calamares/kurulum (M11), sürüm paketi (M12): henüz başlamadı.
