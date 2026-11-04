# LFS 12.4-systemd disk imajı önyükleme testi (2026-11-04)

- İmaj: ~/alpbahOS/scratch-lfs-bench/disk.img (12 GiB, GPT: 1 MiB BIOS boot + ext4 `lfsroot` = sda2)
- Kurulum: build_image3.sh (LFS kökü cp -a ile, /sources ve /tools hariç; GRUB i386-pc, chroot içinde grub-install)
- Kernel: 6.16.1-lfs-12.4-systemd, LFS chroot'unda kitabın yapılandırmasıyla derlendi (GCC 15.2.0, binutils 2.45)
- Önyükleme: GRUB (BIOS) -> kernel -> systemd -> `alpbahos login:`
- Root: parola alanı boş (`root::`), seri konsoldan parolasız giriş çalışıyor
- Doğrulama (seri konsol, ASCII): `cat /proc/version`, `/usr/bin/whoami` -> `root`, `ls /usr/lib` ve `ls /usr/sbin` listeleniyor

## Düzeltme (önceki not)
İlk denemelerde `/usr/bin`, `/usr/sbin`, `/usr/lib` "No such file" gibi göründü. Kök neden dosya sistemi/kernel değildi:
QEMU VGA konsolunda `sendkey i` komutu guest'in Türkçe Q (`trq`) düzeninde noktasız `ı` üretiyordu;
başarısız olan tüm isimler `i` içeriyordu (bin, sbin, lib, include, libexec, whoami, printenv).
Seri konsol (ASCII) ile yapılan testlerde aynı kernel ve aynı imaj sorunsuz çalıştı.
Ayrıca fsck, dizin indeksleri, mkfs özellikleri, CRC32C, hash algoritması ve GCC/host derleyici değişkenleri
denendi; hiçbiri gerekli değildi ve imajda kalıcı bir değişiklik olarak bırakılmadı.

## Sınırlar
- Konsol düzeni: /etc/vconsole.conf KEYMAP=trq; QEMU sendkey ile `i` yazmak yanlış karakter üretir (test aracının sorunu, gerçek trq klavyede sorun yok).
- Yedek GRUB girişi: Fedora kernel 7.2.7 (initramfs'siz) -- LFS kernel'i ile sorun çıkarsa.
- Servisler tek tek doğrulanmadı; UEFI denenmedi; saat dilimi /etc/localtime Europe/Istanbul (Glibc bölümünde ayarlandı).
