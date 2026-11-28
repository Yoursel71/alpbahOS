# Başlarken

alpbahOS'u USB bellekten açıp diske kurmadan deneyebilir, beğenirsen grafik kurulum programıyla kurabilirsin.

::: tip Beta 0.9
En yeni test ISO'su **R53e** (28 Kasım 2026): [Internet Archive](https://archive.org/details/alpbahos-beta-0.9-r53e). Sürüm notları GitHub'da: [R53e](https://github.com/Yoursel71/alpbahOS/releases/tag/beta-0.9-r53e-20261128). Kararlı sürüm henüz yok; kurmadan önce önemli verilerini yedekle.
:::

## ISO'yu indirme ve doğrulama

1. [Internet Archive sayfasından](https://archive.org/details/alpbahos-beta-0.9-r53e) `alpbahos-beta-0.9-2026-11-28-r53e.iso` dosyasını indir (6,3 GB, tek dosya; sayfada torrent bağlantısı da var). Bütün alpbahOS duvar kâğıtları zip olarak [R53d sayfasında](https://archive.org/details/alpbahos-beta-0.9-r53d).
2. Dosyayı doğrula. `sha256sum alpbahos-beta-0.9-2026-11-28-r53e.iso` çıktısı şu olmalı:
   `b87e8e480663d82348dc92fb7235277971466e169b94c12b84f2f67faa4f2b8d`
   Windows'ta: `certutil -hashfile alpbahos-beta-0.9-2026-11-28-r53e.iso SHA256`.

::: warning R53c kurduysan
İlk iş terminalde bir kez `sudo alpbahos-update` yaz (ya da menüden **alpbahOS Güncelleme**). R53c'de güncelleme bildirimi yok; bundan sonra yeni güncellemeler oturum açınca bildirilir.
:::

R52 ve önceki sürümler GitHub'daki [ön sürümlerde](https://github.com/Yoursel71/alpbahOS/releases) 1,9 GB'lık parçalar halindedir: bütün `.part` dosyalarını ve `birlestir` dosyalarını aynı klasöre indir, Windows'ta `birlestir.bat`, Linux'ta `birlestir.sh` çalıştır.

## Canlı USB hazırlama

ISO'yu [Ventoy](https://www.ventoy.net) ile (ISO'yu USB'ye kopyalaman yeterli) ya da KDE ISO Image Writer, Rufus gibi bir araçla USB'ye yaz. Ventoy dışındaki araçlar **USB'nin içeriğini siler**.

## USB'den açma

1. Secure Boot'u BIOS/UEFI ayarlarından kapat.
2. USB'yi tak, bilgisayarı yeniden başlat ve açılış menüsünden (üreticiye göre F12, F11, F8 veya Esc) USB'yi seç.
3. Canlı masaüstü açılır. Bu oturum iç diske yazmaz.

BIOS ve UEFI açılışı her turda sanal makinede, ayrıca gerçek bir bilgisayarda test edildi.

## Canlı oturumda neye bakmalı?

Ekran çözünürlüğünü, klavyeyi, sesi ve ağ bağlantısını kontrol et. Canlı oturumda yaptığın değişiklikler ve kaydettiğin dosyalar kapatınca silinir.

## Sonraki adım

Kurmaya karar verdiysen [Kurulum](/kurulum) sayfasına geç.

## USB açılmazsa

Secure Boot'un kapalı olduğunu ve açılış menüsünde doğru USB'yi seçtiğini kontrol et. Sorun sürerse cihaz modelini, BIOS/UEFI modunu ve ekrandaki mesajı [bildir](https://github.com/Yoursel71/alpbahOS/issues).
