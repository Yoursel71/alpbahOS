---
title: alpbahOS'a giriş
---

<p class="eyebrow">ALPBAHOS / BELGELER</p>

# Tanıdık bir masaüstü, Türkçe bir başlangıç.

<p class="lead">alpbahOS; okullar ve Windows’tan geçenler için geliştirilen, KDE Plasma tabanlı bir Linux masaüstüdür.</p>

<div class="intro-panel">

**Geliştirme durumu:** Beta 0.9 test aşaması. En yeni test ISO'su R53e (28 Kasım 2026) [Internet Archive'da](https://archive.org/details/alpbahos-beta-0.9-r53e); indirme ve doğrulama adımları [Başlarken](/baslarken) sayfasında. Kararlı sürüm henüz yok. Bu belgeler, mevcut testleri ve planları ayrı ayrı anlatır.

</div>

## alpbahOS nedir?

Proje, LFS/BLFS 13.1 temeli üzerinde kaynak koddan oluşturuluyor. Türkçe varsayılanlar, alt görev çubuğu ve Başlat menüsüne benzeyen uygulama menüsüyle tanıdık bir çalışma alanı sunar. Kurulum Calamares ile, paketler `alp` ile yapılır.

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

KDE Plasma, pencereleri, görev çubuğunu ve masaüstü ayarlarını bir araya getirir. Dosyalar için Dolphin, metinler için KWrite veya Kate gibi KDE uygulamaları kullanılır. Türkçe arayüz ve Türkçe Q klavye hazır gelir; istenirse ayarlardan değiştirilebilir.

### Canlı ortam ve kurulum

Canlı ortam, bilgisayarı USB'deki sistemle açarak masaüstünü inceleme olanağı sunar. İç diske kurulum bunun ardından kullanıcı tarafından başlatılan ayrı bir adımdır. Grafik yükleyici, kullanıcı ve disk seçimlerini gösterir; disk işlemlerini onaylamadan önce özet dikkatle incelenmelidir.

### Paketler ve uygulamalar

`alp`, sistem paketlerini kuran komut satırı aracıdır; katalogda olmayan uygulamalar için Flathub'daki karşılığını önerir. Sistem güncellemeleri imzalı gelir ve geri alınabilir.

## Bu belgeleri nasıl okumalı?

**Sanal makinede test edildi** ifadesi sonucun QEMU ortamına ait olduğunu, **gerçek bilgisayarda** ifadesi fiziksel bir cihazda denendiğini gösterir. Neyin çalıştığı ve sıradaki işler [sürüm durumu](/yol-haritasi) sayfasında.
