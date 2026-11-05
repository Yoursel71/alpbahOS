# M11 kurucu zinciri — Calamares 3.3.14 (5 Kasım 2026)

Durum: **derleme ve kurulum tamam; sanal disk kurulum testi (M11 kabulü) henüz yapılmadı.** Ortam: LFS chroot (`/mnt/lfs`), Qt 6.9.2 (`/opt/qt6`), KF6 6.17.

## Kaynaklar ve doğrulama

| Paket | Sürüm | Kaynak | sha256 | Doğrulama | Sonuç |
|---|---|---|---|---|---|
| yaml-cpp | 0.9.0 | github.com/jbeder/yaml-cpp (etiket arşivi) | `25cb0432…efd49` | upstream sha/imza yok (D56) | RC=0; `libyaml-cpp.so.0.9` |
| GNU parted | 3.6 | ftpmirror.gnu.org | `3b43dbe3…e612` | GPG **geçerli**; imzalayan anahtar (`B4C6B451…`, Brian C. Lane) **süresi dolmuş** (D56) | RC=0 (ikinci derleme; `-Wno-incompatible-pointer-types`) |
| kpmcore | 25.08.3 | github.com/KDE/kpmcore (etiket arşivi) | `298e801d…f09` | upstream sha/imza yok (D56) | RC=0; `libkpmcore.so.25.08.3` |
| Calamares | 3.3.14 | github.com/calamares/calamares (etiket arşivi) | `fa158d67…d5a` | upstream sha/imza yok (D56) | RC=0; `/usr/bin/calamares` |

## Derleme notları

- yaml-cpp: `BUILD_SHARED_LIBS=ON`, testler/araçlar kapalı.
- parted: `--disable-device-mapper --without-readline --disable-doc --disable-nls`. GCC 15, `incompatible-pointer-types` hatasını ilk derlemede verdi; uyarı kapatılarak yeniden derlendi (kaynak değişmedi).
- kpmcore: Calamares 3.3.14'ün gereksinimi `KPMcore >= 24.01.75` (Qt 6); 25.08.3 seçildi.
- Calamares: `WITH_QT6=ON`. Python tabanlı yapılandırma doğrulayıcısı (`yaml-schema`) bağımlılığı eksik, atlandı. Python çevirileri atlandı.

## Açık (M11 kabulü)

1. Sanal diskte BIOS ve UEFI kurulum testi (`docs/handoffs`'taki M11 kriteri: önce sanal disk, sonra yetkilendirilmiş gerçek disk).
2. Kurucu modülleri (unpackfs için squashfs, bootloader için GRUB, kullanıcı ve dil) yapılandırılmadı.
3. Canlı ISO (M09) henüz yok; Calamares'in çalıştığı ortam bu ISO ile kurulacak.

## Kurucu yapılandırması (chroot'ta yükleme testi)

- Dosyalar: `scripts/lfs-blfs/calamares/settings.conf` (sıra düzenlendi: initcpio/initramfs/displaymanager çıkarıldı), `scripts/lfs-blfs/calamares/unpackfs.conf` (kaynak `/run/live/medium/live/filesystem.squashfs`, squashfs). Modül yapılandırmaları (49 `.conf`) rootfs `/etc/calamares/modules/` altına kaynak ağacından kopyalandı.
- Test: `QT_QPA_PLATFORM=offscreen QT_PLUGIN_PATH=/usr/lib/plugins:/opt/qt6/plugins calamares -d` chroot içinde: 60 modül bulundu; `welcome`, `locale`, `keyboard` yüklendi; bölümleme arka ucu `pmsfdiskbackendplugin` yüklendi.
- Önceki hata (`Failed to initialize KPMcore backend`) yanlış `QT_PLUGIN_PATH` yüzündendi (`/usr/lib/plugins` eklenince çözüldü).
- Kalan uyarılar (chroot): D-Bus sistem soketi yok; `ckbcomp` yok (klavye önizlemesi devre dışı); `/etc/locale.gen` yok.
- Henüz yapılmadı: gerçek kurulum (sanal disk) — canlı ISO (M09) gerekiyor.
