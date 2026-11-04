# LFS 12.4-systemd disk imajı önyükleme testi (2026-11-04)

- İmaj: ~/alpbahOS/scratch-lfs-bench/disk.img (12 GiB, GPT: 1 MiB BIOS boot + ext4 `lfsroot` = sda2)
- Kurulum: build_image.sh (LFS kökü tar ile kopyalandı, /sources ve /tools hariç; GRUB i386-pc `grub-install`, chroot içinde)
- Çekirdek: 6.16.1-lfs-12.4-systemd (defconfig + kitabın zorunlu seçenekleri, WERROR kapalı), derleme 233 sn
- Ana makine: QEMU 10.2.2, KVM, 2 GiB RAM, AHCI disk (/dev/sda), SeaBIOS
- Sonuç: GRUB → kernel → systemd → `alpbahos login:` istemi (ekran görüntüsü: boot-screen.png)
- Hostname `alpbahos` uygulandı (ch9 config)
- Sınırlar: root parolası ayarlanmadı (Shadow bölümünde atlandı); tzselect/timezone çalışma zamanında değil; giriş yapılıp servisler doğrulanmadı; UEFI denenmedi.
