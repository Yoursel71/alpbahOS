# Devir notu 024 — 6 Kasım 2026 (M11 modül koşucusu)

Durum: M11 **kısmi kabul**. BIOS sanal diske kurulum ve seri giriş istemi (`alpbahos login:`) kanıtlandı. Ayrıntı: `docs/verification/m11-module-runner-2026-11-06.md`.

## Kanıtlı olanlar
- Koşucu `scripts/lfs-blfs/calamares/runner/m11-run.sh`: 12 denemenin son hali (logs-12) tüm modüllerde temiz. Hedef yalnız yeni bir sanal disk dosyası; hiçbir gerçek disk yazılmadı.
- Hedef doğrulaması: fsck temiz, fstab kök satırı UUID, GRUB `root=PARTUUID=…`, MBR ve bios_grub core yerinde.
- VM (oturum C, 10:58): giriş istemi. Kapatma ACPI ile temiz (`reboot: Power down`).

## Açık (öncelik sırasıyla)
1. **Ürün sekansı (Codex):** `scripts/lfs-blfs/calamares/settings.conf` içinde `grubcfg` yok. Bootloader'dan önce eklenmeli. Yoksa GRUB kök aygıtını host yolu olarak yazar.
2. **Ürün bootloader.conf (Codex):** `kernelSearchPath: /usr/lib/modules` değil `/boot` olmalı (kernel `/boot/vmlinuz-6.16.1-lfs-12.4-systemd`).
3. **Karar gerekli (kullanıcı + Codex):** kurulu sistemde initramfs yok, bootloader `root=UUID=` yazar; çekirdek çözemez. Ya `root=PARTUUID=` (bu kanıtta kullanıldı) ya da alplive hook'suz bir initramfs (dracut). Kararı DECISIONS.md'ye işle.
4. **unpackfs:** squashfs desteği yoksa sessizce rc=0 döner (yanıltıcı). Hata vermeli. Fedora ana makinede `squashfs` modülü yüklü değildi; koşudan sonra `rmmod` ile kaldırıldı.
5. **ISO'da araçlar:** `rsync` ve `unsquashfs` (squashfs-tools) canlı ISO'da olmalı; doğrulanmadı.
6. **Ağ servisleri (kanıt: `docs/verification/m11-boot-serial-2026-11-06.log`):** `systemd-oomd` ve `systemd-resolved`, namespace hatası (`/tmp` bağlama, `/usr/lib/systemd/...` "No such file"). Kök neden bilinmiyor. Sonraki VM oturumunda `systemctl status` ile bakılacak.
7. **UEFI:** OVMF ile kurulum ve önyükleme yapılmadı (ESP gerekli).
8. **GUI kurucu:** yöntem 1 (tıklama testi) kullanıcı seçimiyle ertelendi.

## Kullanıcı kuralları ve onaylar (bu oturum)
- VM oturumu başına bir açılış, en fazla bir saat. **Bu oturumda iki açılış yapıldı** (10:51 kernel panic, 10:58 giriş). Oturum A (10:49) önyüklemeden önce durdu. Kullanıcıya bildirilmeli.
- Ana makine kapatılmadı. Büyük dosyada SHA ve uzun test yapılmadı (20 GB sparse imaj yalnız bağlandı ve fsck -n ile okundu).
- Repo main'e push yapılmadı. M12 yayını ayrı onay ister.
- Test şifreleri repo dışında kaldı; bu oturumda parola yazılmadı.

## Dosyalar ve yollar
- Çalışma: `/home/yrslf/alpbahOS/wt-t2-kisayol` (branch `claude/t2-kisayol-2026-11-05`).
- Koşucu günlükleri ve hedef: `/home/yrslf/alpbahOS/scratch-lfs-bench/m11-runner/` (`logs-1` … `logs-12`, `boot-vm2/`, `m11-target.img`).
- Yardımcı araçlar: `scratch-lfs-bench/m11-runner/hosttools/` (rsync/unsquashfs sarmalayıcıları).
- Chroot: `/mnt/lfs` (`scripts/lfs-blfs/mount_lfs.sh` ile bağlı). Koşucu sonunda kendi bağlarını ve loop aygıtlarını kaldırır.

## Kullanım
```
sudo bash scripts/lfs-blfs/calamares/runner/m11-run.sh <YENİ-hedef.img> <log-dizini>
```
Hedef dosya önceden varsa durur (üzerine yazmaz). Her denemede yeni bir dosya kullanın.
