---
title: alpbahOS'a giriş
---

<p class="eyebrow">ALPBAHOS / BELGELER</p>

# Tanıdık bir masaüstü, Türkçe bir başlangıç.

<p class="lead">alpbahOS; okullar ve Windows’tan geçenler için geliştirilen, KDE Plasma tabanlı bir Linux masaüstüdür.</p>

<div class="intro-panel">

**Geliştirme durumu:** Test görüntüleri hazırlanıyor; henüz yayımlanmış bir sürüm veya genel indirme bağlantısı yok. Bu belgeler, mevcut testleri ve planları ayrı ayrı anlatır.

</div>

## alpbahOS nedir?

Proje, LFS/BLFS 13.1 temeli üzerinde kaynak koddan oluşturuluyor. Türkçe varsayılanlar, alt görev çubuğu ve Başlat menüsüne benzeyen uygulama menüsüyle tanıdık bir çalışma alanı hedefliyor. Grafik kurulum için Calamares, paketler için de `alp` geliştiriliyor.

## Kimler için?

- **Okullar:** Türkçe arayüz ve günlük masaüstü işleri için.
- **Windows'tan geçenler:** Görev çubuğu ve bilinen kısayollara yakın bir düzen için.
- **Merak edenler:** Kaynak kodunu ve proje kararlarını incelemek isteyenler için.

## Masaüstüne bir bakış

![alpbahOS masaüstü, sol üstte simgeler ve altta görev çubuğu](/images/screens/01-masaustu.webp)
<p class="image-caption">Geliştirme görüntüsü: alpbahOS masaüstü.</p>

<div class="image-grid">

![Hoş Geldin ekranında alpbahOS tema seçenekleri](/images/screens/05-hosgeldin-alpbahos.webp)
![Atatürk teması uygulanmış masaüstü](/images/screens/03-masaustu-ataturk.webp)

</div>

## Nereden başlamalı?

[Başlarken](/baslarken) sayfası canlı USB akışını, [Kurulum](/kurulum) sayfası yükleyicideki adımları anlatır. Projenin test edilmiş ve açık kalan işlerini [sürüm durumu](/yol-haritasi) sayfasında bulabilirsin.

## Projenin parçaları

### Masaüstü ve günlük kullanım

KDE Plasma, pencereleri, görev çubuğunu ve masaüstü ayarlarını bir araya getirir. Dosyalar için Dolphin, metinler için KWrite veya Kate gibi KDE uygulamaları kullanılır. Projede Türkçe arayüzün ve Türkçe Q klavyenin başlangıçta hazır gelmesi amaçlanıyor; istenirse ayarlar daha sonra değiştirilebilir.

### Canlı ortam ve kurulum

Canlı ortam, bilgisayarı USB'deki sistemle açarak masaüstünü inceleme olanağı sunar. İç diske kurulum bunun ardından kullanıcı tarafından başlatılan ayrı bir adımdır. Grafik yükleyici, kullanıcı ve disk seçimlerini gösterir; disk işlemlerini onaylamadan önce özet dikkatle incelenmelidir.

### Paketler ve uygulamalar

`alp`, sistem paketleri için geliştirilen komut satırı aracıdır. Grafik uygulama mağazası ve Flathub entegrasyonu da proje planında yer alır; tüm uygulama kurulum ve güncelleme akışları henüz son kullanıcı için doğrulanmış değildir.

## Bu belgeleri nasıl okumalı?

Bir sayfada **planlanıyor** deniyorsa özellik bir hedefi anlatır. **Sanal makinede denendi** ifadesi ise sonucun QEMU ortamına ait olduğunu gösterir. Gerçek bilgisayarda alınan sonuçlar ayrıca belirtilir. Bir cihazda başarılı olan işlem, farklı bir bilgisayarda aynı şekilde çalışacağının garantisi değildir.

Henüz yayımlanmış bir ISO bulunmadığından kurulum ve USB bölümleri, mevcut test akışını ve dikkat edilmesi gerekenleri anlatır; bir indirme rehberi olarak sunulmaz. Gelişmeler için [yol haritasına](/yol-haritasi) bakabilirsin.
