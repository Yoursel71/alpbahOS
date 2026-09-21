# ADR 0001 — Native paket yığını

Durum: Kabul edildi, entegrasyon prototipi bekliyor. Tarih: 21 Eylül 2026.

## Karar

alpbahOS taban paketleri için pacman/libalpm kullanılacak. Kullanıcı arayüzü `pkg` adlı ince bir komut ailesi olacak. Grafik mağaza adayı Discover; native depo bağlantısı PackageKit alpm backend üzerinden yapılacak. alpbahOS kendi imzalı paketlerini ve kendi depo metadata'sını üretecek. Arch Linux deposu işletim sisteminin taban deposu olmayacak.

## Gerekçe

- Hazır bağımlılık çözümü, dosya sahipliği, işlem kilidi ve hook altyapısı.
- Basit arşiv/depo yapısı LFS üzerinde paket üretmeye uygun.
- libalpm, `pkg` için aynı işlem motoruna doğrudan erişim sağlar.
- PackageKit kaynak ağacında alpm backend bulunur; Discover PackageKit backend sağlayabilir.
- Kullanıcı sıfırdan büyük bir paket yöneticisi yazmak istemiyor.

## Koşullar

1. LFS/multilib üzerinde pacman bootstrap prototipi geçmeli.
2. `pkg`, ikinci paket veri tabanı oluşturamaz.
3. Discover ile CLI aynı alpm kilidi ve veritabanını kullanmalı.
4. PackageKit/alpm/Discover sürümleri için kur, kaldır, güncelle, iptal ve hata testleri geçmeli.
5. Kısmi sistem yükseltmesi desteklenmez; yayın deposu tutarlı sürüm kümesi olarak güncellenir.
6. AppStream verisi paket sürümleriyle birlikte üretilir.

## Geri dönüş koşulu

M02 prototipinde PackageKit entegrasyonu veya LFS bootstrap sürdürülemez çıkarsa dpkg/APT + PackageKit alternatifi için yeni ADR hazırlanır. Aynı rootfs'de iki bağımsız native paket sistemi tutulmaz.
