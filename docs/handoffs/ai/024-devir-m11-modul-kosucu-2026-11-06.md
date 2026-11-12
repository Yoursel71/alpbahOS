# Devir notu 024 — 6 Kasım 2026 (M11 modül koşucusu)

Durum: M11 **kısmi kabul**. BIOS sanal diske kurulum ve seri giriş istemi (`alpbahos login:`) kanıtlandı. Ayrıntı: `docs/verification/m11-module-runner-2026-11-06.md`.

## Kanıtlı olanlar
- Koşucu `scripts/lfs-blfs/calamares/runner/m11-run.sh`: 12 denemenin son hali (logs-12) tüm modüllerde temiz. Hedef yalnız yeni bir sanal disk dosyası; hiçbir gerçek disk yazılmadı.
- Hedef doğrulaması: fsck temiz, fstab kök satırı UUID, GRUB `root=PARTUUID=…`, MBR ve bios_grub core yerinde.
- VM (oturum C, 10:58): giriş istemi. Kapatma ACPI ile temiz (`reboot: Power down`).

## Açık (öncelik sırasıyla)
1. **Ürün sekansı (Codex, engel değil):** `scripts/lfs-blfs/calamares/settings.conf` içinde `grubcfg` yok. Eklenmesi önerilir (dağıtıcı adı ve GRUB varsayılanları için). Kök aygıtını düzeltmez; kök `grub-mkconfig` tarafından belirlenir.
2. **Ürün bootloader.conf (Codex):** `kernelSearchPath: /usr/lib/modules` değil `/boot` olmalı (kernel `/boot/vmlinuz-6.16.1-lfs-12.4-systemd`).
3. **ENGELLEYİCİ, karar gerekli (kullanıcı + Codex):** gerçek diskte `grub-mkconfig` (`/usr/sbin/grub-mkconfig` satır 136) `GRUB_DEVICE_UUID`'yi grub-probe ile doldurur; `10_linux` `root=UUID=…` yazar. Kurulu sistemde initramfs yok; çekirdek fs UUID'sini çözemez ve panik olur (oturum B). Seçenekler: (a) alplive hook'suz bir initramfs (dracut), (b) `GRUB_DEVICE` ile `root=PARTUUID=…` (bu kanıtta kullanıldı; GPT ve `CONFIG_EFI_PARTITION=y` şart). Kararı DECISIONS.md'ye işle. Kararsız kalırsa M11 kabulü bu karara bağlı.
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
- Çalışma: `/home/yrslf/alpbahOS/wt-t2-kisayol` (branch `ai/t2-kisayol-2026-11-05`).
- Koşucu günlükleri ve hedef: `/home/yrslf/alpbahOS/scratch-lfs-bench/m11-runner/` (`logs-1` … `logs-12`, `boot-vm2/`, `m11-target.img`).
- Yardımcı araçlar: `scratch-lfs-bench/m11-runner/hosttools/` (rsync/unsquashfs sarmalayıcıları).
- Chroot: `/mnt/lfs` (`scripts/lfs-blfs/mount_lfs.sh` ile bağlı). Koşucu sonunda kendi bağlarını ve loop aygıtlarını kaldırır.

## Yeniden üretim (ön koşullar)

Koşucu başlamadan şunları denetler ve eksikse durur.

1. **Chroot bağları:** `sudo bash scripts/lfs-blfs/mount_lfs.sh`.
2. **loadmodule (Codex'in derleme ağacında DEĞİŞİKLİK):** `/mnt/lfs/sources/blfs-build/calamares-3.3.14/build` içinde `BUILD_TESTING` kapalıydı; bu oturumda açıldı ve yalnız `loadmodule` derlendi. Bu, Codex'in o ağacının `CMakeCache.txt` dosyasını değiştirir. Sonraki yapıda testler de derlenir. Codex'e bildir.
   ```
   sudo chroot /mnt/lfs /bin/sh -c 'cd /sources/blfs-build/calamares-3.3.14/build && cmake -DBUILD_TESTING=ON . && make loadmodule -j16'
   ```
   Geri almak için `cmake -DBUILD_TESTING=OFF .` çalıştırın; loadmodule kaldırılmaz ama yeniden derlenmez.
3. **hosttools (`scratch-lfs-bench/m11-runner/hosttools/`):** Fedora'dan kopyalandı:
   - `bin/rsync.real`, `bin/unsquashfs.real` (`/usr/bin/rsync`, `/usr/bin/unsquashfs`)
   - `lib/`: `libpopt.so.0`, `libxxhash.so.0`, `liblzo2.so.2` (ldd'de chroot'ta yoktu) ve Fedora'nın `libacl.so.1` (chroot'takinde `ACL_1.3` yok)
   - `bin/rsync`, `bin/unsquashfs`: `exec env LD_LIBRARY_PATH=/run/m11tools/lib /run/m11tools/bin/<ad>.real "$@"` sarmalayıcıları (chmod 755)
4. **squashfs (ana makine):** `sudo modprobe squashfs`. Koşu sonrası `sudo rmmod squashfs` ile kaldırıldı. Koşucu başlamadan önce kontrol eder.

## Kullanım
```
sudo bash scripts/lfs-blfs/calamares/runner/m11-run.sh <YENİ-hedef.img> <log-dizini>
```
Hedef dosya önceden varsa durur (üzerine yazmaz). Her denemede yeni bir dosya kullanın. Koşucu sonunda hedefi, loop aygıtını ve bağları kaldırır; `/mnt/lfs/root/m11-runner` (girdi dizini) kalır.
