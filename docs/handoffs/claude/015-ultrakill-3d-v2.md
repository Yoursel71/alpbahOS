# Claude devir belgesi 015 — ULTRAKILL 3D ikinci tur (tutorial, tüm silahlar, parry, rekabetçi mobil düzen)

Görev ID / durum: Backlog dışı, kullanıcı talebinin devamı ([devir 010](010-ultrakill-3d-fan-game.md)). Bu turdaki istekler:

- Ölüm ekranı ve intro orijinaldeki gibi yazıların gelmesiyle,
- ilk bölümde gerçek oyundaki gibi tutorial ve sonradan alınan silahlar,
- daha iyi düşmanlar, sesler ve silahlar,
- genel mobil uyum,
- renkli düşmanlar, tüm silahlar, daha iyi parry ve rekabetçi buton düzeni.

Durum: tamamlandı; oynanabilir ikinci sürüm.

Çalışılan host ve branch: Claude Code bulut oturumu (Linux konteyner), dal `claude/3d-ultrakill-game-dev-qzqj42`, önceki commit `12474b2`. Windows host, Hyper-V VM'leri, `/mnt/lfs`, paket manifesti ve `alp` motoru kullanılmadı ve değiştirilmedi.

Değişen dosyalar: yalnız `apps/ultrakill-3d/**`, bu belge ve `docs/WORKLOG.md` sonundaki kayıt.

- Yeni dosyalar: `src/typer.js` ve `tests/tutorial.mjs`.
- Diğer kaynak, test ve README dosyaları güncellendi.
- `dist/ultrakill-3d.html` yeniden üretildi (~820 KB).

## Gerçekleştirilen davranış

### Intro ve ölüm ekranı

- Intro terminal satırları harf harf yazılır, yükleme çubukları ve daktilo sesi vardır.
- Ardından sarsıntılı, glitch efektli büyük yazılar gelir: "İNSANLIK ÖLDÜ. / KAN YAKITTIR. / CEHENNEM DOLU.".
- Ölüm ekranı sırası:
  1. ağır çekim ve gri/kırmızı post efekti,
  2. karartma ve parazit,
  3. harf harf yazılan 5 terminal satırı,
  4. çarpan "ÖLDÜN" başlığı,
  5. yeniden doğuş istemi.
- Ölümde alınan silahlar korunur. Arena kapı ve öldürme durumu checkpoint anına döner.

### Tutorial

Bölüm silahsız başlar. Tutorial kanadı sırasıyla şunları öğretir:

1. İniş.
2. Atılma zıplaması: normal zıplamayla geçilemeyen boşluk.
3. Kayma: alçak engel.
4. Duvar sıçraması: kuyu.
5. Çakış sıçrayışı: yüksek çıkıntı.
6. Revolver sunağı.

Silah sunakları arenalar arasına yayıldı:

- Whiplash, Nailgun ve Shotgun sunakları.
- Parry eğitmeni: yalnız savuşturmayla ölen mavi düşman. Ölünce kapıyı açar ve öldürme sayısına eklenmez.
- Silah deposu: Railcannon, Rocket Launcher ve Knuckleblaster.

Menüde "Tüm silahlarla başla" seçeneği var.

### Silahlar

5 silah × 3 varyant:

- Revolver: Piercer, Marksman, Sharpshooter.
- Shotgun: Core Eject, Pump Charge, Sawed-On.
- Nailgun: Attractor, Overheat, Sawblade.
- Railcannon: Electric, Screwdriver, Malicious.
- Rocket Launcher: Freezeframe, S.R.S. Cannon, Firestarter.

Kollar ve kanca:

- Feedbacker ve Knuckleblaster (G ile değişir).
- Whiplash kancası (E).

Diğer iyileştirmeler:

- Yeni görünür silah modelleri.
- Mermi deliği izleri, kovan fırlatma, namlu dumanı.
- Yanma ve delme hasarı zamana yayılır.

### Parry

- Yumruktan sonra 0,12 sn tampon penceresi var.
- Geri yollanan mermi nişan alınan düşmana yönelir.
- Çekirdek, roket ve gülle fırlatılabilir.
- Bozuk paraya yumruk atılabilir.
- Yakın mesafede shotgun parry'si var.
- Parry'de ekran nabzı ve titreşim olur.
- Knuckleblaster mermi savuşturmaz.
- Öfke fazındaki boss, parry ile hasarsız kalmaz (hata düzeltmesi).

### Düşmanlar

- Renkli tipler: yeşil Filth, turuncu Stray, mor Schism, sarı zırhlı Swordsmachine.
- Rengi koruyan parlama.
- Vuruş tepkisi yaylanması, sersemleme ve saldırı bölme, kafa takibi.
- Filth atlayış saldırısı (parry penceresiyle).
- Ölüm biçimleri: parçalanma, kafa kopması (kan fıskiyesi) ve cesedin yığılıp batması.

### Ses

- JS içinde DSP ile üretilen örnekler: biquad filtre, doygunluk, konvolüsyon yankısı.
- Mekânsal konum ve mesafe alçak geçirgeni.
- Ses bankası ilk tıklamada takılmasın diye parça parça üretilir.
- Müzik: DSP davul ve distorsiyonlu gitar. Stil rütbesine göre katman açılır.

### Mobil

Rekabetçi düzen:

- Büyük sağ ATEŞ ve sol başparmak için sol ATEŞ.
- Merkezde PARRY, çevresinde ZIPLA, ATIL, KAY ve ALT.
- Kanca ve kol butonları yalnız alınınca görünür.
- Üst şeritte 1-5, istatistik, tam ekran ve duraklat.

Kontroller:

- Analog joystick.
- İvmeli sürükleyerek bakış.
- Nişan yardımı ve titreşim.
- Mobilde düşük çözünürlük ve daha az ışık varsayılanı.

Düzen düzenleyici:

- Butonlar ve joystick sürükle-yerleştir ile taşınır.
- Konumlar ekran oranı olarak kaydedilir. SIFIRLA ile varsayılana dönülür.
- Düzenleme sırasında ipucu ve mesaj gizlenir.

İpucu kutusu dokunmatik modda butonlarla çakışmayacak biçimde daraltıldı ve konumlandırıldı.

## Çalıştırılan doğrulama ve sonuç

Ortam: bulut konteyner, Node 22, playwright-core 1.63.0, headless Chromium 1194 (SwiftShader yazılım GL).

- `node build.mjs`: `dist/ultrakill-3d.html` üretildi.
- `node tests/smoke.mjs`: **36/36 geçti**. Kapsam:
  - Önceki kontroller.
  - Silahsız tutorial başlangıcı ve Revolver sunağı.
  - Yeni silahların isabeti ve üçüncü varyantlar.
  - Tüm silahlar seçeneği.
- `node tests/tutorial.mjs`: **11/11 geçti**. Tuş girdisiyle oynayan bot:
  - Atılma zıplamasıyla boşluğu geçti. Normal zıplamayla geçemedi.
  - Kayarak engeli geçti. Ayakta geçemedi.
  - Duvar sıçramasıyla kuyudan çıktı.
  - Çakış sıçrayışıyla çıkıntıya çıktı.
  - Parry eğitmenini savuşturmayla öldürdü ve kapı açıldı.

  Ayrıca intro aşamaları ve ölüm ekranının dört aşaması doğrulandı.
- `node tests/mobile.mjs`: **19/19 geçti**. Kapsam:
  - 844×390 dokunmatik emülasyon ve CDP touch olayları.
  - Joystick, bakış ve tüm butonlar.
  - Sol ATEŞ ve kol butonu.
  - Düzen düzenleyicide sürükleme ve kaydetme.
- Görsel kontrol: masaüstü ve 844×390 mobil ekran görüntüleri incelendi. Sayfa hatası 0.
  - Renkli düşmanlar, silah deposu ve silah modelleri görüldü.
  - Mobil ipucu çakışması düzeltildi.

Çalıştırılmadı:

- Gerçek GPU'lu masaüstünde ve gerçek telefonda insan oyun testi. Titreşim ve tam ekran gerçek cihazda denenmedi.
- Ses çıktısını kulakla dinleme. Yalnız hatasız üretildiği doğrulandı.
- alpbahOS imajı içinde tarayıcıyla çalıştırma (masaüstü/BLFS henüz yok).

Zorluk dengesi ve sıralama eşikleri tahminidir.

Log / artifact: test ekran görüntüleri `apps/ultrakill-3d/tests/out/` altına yazılır (git'e eklenmez).

## Bilinen sorun ve açık karar

- Resmî olmayan hayran yapımıdır. Ticari dağıtım veya alpbahOS varsayılan uygulama listesine alınması ayrıca kullanıcı kararı gerektirir.
- Headless yazılım GL'de menü FPS'i ~24'tür. Gerçek GPU performansı ölçülmedi.
- Whiplash dünyaya tutunmaz. Yalnız düşmanlarla çalışır: hafif düşmanı çeker, ağır düşmana doğru fırlatır.

## Entegrasyon için gereken

Yok. Oyun bağımsızdır.

Sonraki eylem: kullanıcının gerçek cihazda (masaüstü ve telefon) oynayıp his, denge ve buton düzeni geri bildirimi vermesi.
