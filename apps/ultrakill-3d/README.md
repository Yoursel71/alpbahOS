# ULTRAKILL 3D — hayran yapımı (PRELUDE: "İLK KAN", 0-1 → 0-5)

ULTRAKILL'in PRELUDE bölümlerine saygı duruşu olarak yapılmış, tarayıcıda çalışan 3D bir hayran oyunu.
Tüm 3D modeller, dokular, sesler ve müzik çalışma anında kodla üretilir; orijinal oyundan hiçbir
varlık kullanılmaz. **Resmî değildir**; ULTRAKILL, Arsi "Hakita" Patala / New Blood Interactive'in
oyunudur.

## Nasıl oynanır

`dist/ultrakill-3d.html` tek dosyadır: çift tıklayıp Chromium/Firefox tabanlı bir tarayıcıda aç
(sunucu gerekmez, internet gerekmez; yalnız yazı tipleri çevrimiçiyse Google Fonts'tan gelir,
değilse yedek yazı tiplerine düşer). WebGL2 gerekir.

0-1 gerçek oyundaki gibi **silahsız** başlar: önce tutorial kanadında hareket öğretilir, sonra
Revolver sunaktan alınır. Diğer her şey (silahlar, varyantlar, kollar) bölümlerdeki yeşil
**DÜKKÂN** terminallerinden, stil puanından biriken **P** ile satın alınır. Bölümler sırayla açılır;
bitirdiğin bölüm menüden tekrar oynanabilir. Ayarlar → OYUN → "Test modu: tüm silahlar" dükkânı atlar.

P kuralları: stil puanı anında P olur ama kasaya checkpoint'te, dükkânı açınca ve bölüm sonunda
girer; ölünce son checkpoint'ten beri kazanılan P kaybolur. Gizli küre +1000 P; bölüm sonunda sıraya
göre ödül (P-rank 5000 … D 300) ve meydan okuma +1000 P.

### Klavye + fare

| Tuş | Eylem |
|---|---|
| W A S D | Hareket |
| BOŞLUK | Zıpla · havada duvara doğru: duvar sıçraması (yere değmeden 3 kez) |
| SHIFT | Atıl (dash) — kısa süre hasar almazsın, 3 stamina |
| C | Yerde kay · havada yere çak (slam); çakıştan hemen sonra zıpla = yüksek sıçrayış |
| SHIFT → BOŞLUK | Atılma zıplaması (uzun atlayış) |
| Sol / sağ tık | Ateş / alternatif ateş |
| F | Yumruk ve PARRY |
| G | Kol değiştir (Feedbacker ↔ Knuckleblaster) |
| E | Whiplash kancası (hafif düşmanı kendine çek · ağır düşmana doğru fırla) |
| B | Dükkân (yeşil terminalin önündeyken) |
| 1 2 3 4 5 · Q · tekerlek | Silah seç (aynı tuşa tekrar: varyant) · son silah · değiştir |
| TAB · R · ESC | İstatistik · ölünce checkpoint · duraklat |

Kayma/çakma tuşu bilinçli olarak `C`'dir: tarayıcıda Ctrl+W sekmeyi kapatabilir.

### Dokunmatik (mobil)

Dokunmatik cihazda kontroller otomatik açılır (Ayarlar → Dokunmatik: Otomatik/Açık/Kapalı).
Telefonu yatay tut.

- Sol altta kayan **joystick** ile yürü (analog: az it = yavaş), ekranın sağ tarafında
  **sürükleyerek** bak (ivmeli bakış; ATEŞ basılıyken de bakılabilir).
- Rekabetçi düzen: büyük sağ ATEŞ, sol başparmak için ikinci **sol ATEŞ**, merkezde PARRY,
  çevresinde ZIPLA / ATIL / KAY-ÇAK / ALT; kanca ve kol butonları yalnız alınınca görünür.
  Terminalin önüne gelince ortada **DÜKKÂN** butonu çıkar. Üstte 1-5 silah, ≡ istatistik,
  ⛶ tam ekran, II duraklat.
- **Nişan yardımı** (Ayarlar → Dokunmatik): KAPALI / HAFİF (mermi hafif bükülür) / GÜÇLÜ
  (varsayılan: ateş ya da ALT basılıyken bakış yakındaki düşmana doğru kayar, nişangâh
  düşmanın üstündeyken bakış yavaşlar).
- Telefonda sade arayüz: menüde bölüm kartları ve hep görünen BAŞLA, ağır efektler kapalı; menü,
  duraklatma, dükkân ve sonuç ekranları daha az kare çizer (pil/ısı). Sonuç ekranına dokunmak
  animasyonu atlar.
- Ayarlar → **SÜRÜKLE-YERLEŞTİR**: her buton ve joystick sürüklenip yeniden yerleştirilebilir;
  konumlar ekran oranı olarak kaydedilir (farklı telefonlarda da çalışır). SIFIRLA varsayılana döner.
- Ayarlanabilir: bakış hassasiyeti, nişan yardımı, buton boyutu ve saydamlığı. Desteklenen
  cihazlarda titreşim geri bildirimi.

### Android APK

`dist/ultrakill-3d.apk` (~510 KB, sürüm 1.1) telefona kurulabilir. Uygulama aynı oyunu tam ekran, yatay ve
**tamamen çevrimdışı** çalıştıran bir WebView kabuğudur (yazı tipleri de içinde; ağ izni yok).
Gerekenler: Android 7.0+ ve güncel "Android System WebView" (WebGL2).

- Kurulum: APK'yı telefona indir, aç, "bilinmeyen kaynaklardan yükleme" iznini ver. Play Protect
  tanımadığı geliştirici uyarısı gösterebilir ("Yine de yükle").
- GERİ tuşu: oyunda duraklat/devam, introyu geç, dükkânı ve buton düzenleyiciyi kapat; ana menüde
  iki kez basınca çıkar.
- Uygulama arka plana gidince oyun duraklar ve ses susar. Titreşim yerel Vibrator ile çalışır.
- Yeniden derleme başka bir imza anahtarıyla yapıldıysa, güncellemeden önce eski uygulamayı kaldır.

## İçerik

- Açılış, ana menü (bölüm, zorluk, ayarlar, kontroller, hakkında), harf harf yazılan terminal
  introsu ve büyük sarsıntılı başlık yazıları, bölüm başlık kartı
- Ölüm ekranı: ağır çekim + gri/kırmızı görüntü, karartma, harf harf yazılan terminal satırları,
  çarpan "ÖLDÜN" başlığı ve yeniden doğuş istemi; ölünce alınan silahlar kaybolmaz
- PRELUDE: İLK KAN (her bölümün kendi teması, sis/gökyüzü renkleri, sıralama eşikleri ve
  meydan okuması var):
  - **0-1 ATEŞİN İÇİNE**: tutorial kanadı (atılma zıplaması, kayma, duvar sıçraması, çakış
    sıçrayışı) → Revolver sunağı → 3 arena, parry eğitmeni, 2 dükkân → boss Swordsmachine
  - **0-2 KIYMA MAKİNESİ**: dönen öğütücülü çukurlar (düşmanları içine it), kasap salonu, kayarak
    geçilen koridor + dükkân, iki katlı kıyma çukuru arenası
  - **0-3 ÇİFTE BELA**: harabe avlusunda ilk Malicious Face, lav nehri, yanık tapınak (iki Malicious
    Face) → boss: aynı anda iki Swordsmachine (tek boss çubuğunda toplam can)
  - **0-4 TEK MAKİNELİK ORDU**: kolezyumda altı dalgalı tek meydan savaşı (Malicious Face'ler ve
    bir Swordsmachine dahil)
  - **0-5 CERBERUS**: heykel koridoru → kaidelerinde uyuyan iki Cerberus; biri yarı cana inince
    diğeri uyanır, biri ölünce öteki öfkelenir → Cehennemin kapısı
- Silahlar (her biri 3 varyant, aynı tuşa tekrar basınca değişir):
  - Revolver: Piercer (şarjlı delici) · Marksman (bozuk para, RICOSHOT) · Sharpshooter (seken ışın)
  - Shotgun: Core Eject · Pump Charge (3. pompada patlama) · Sawed-On (geri dönen testere)
  - Nailgun: Attractor (mıknatıs) · Overheat (ısıtılmış çivi → yanma) · Sawblade (seken testere)
  - Railcannon: Electric · Screwdriver (delip sürekli hasar) · Malicious (patlama)
  - Rocket Launcher: Freezeframe (roketleri dondur) · S.R.S. Cannon (gülle) · Firestarter (alev)
  - Kollar: Feedbacker (parry) · Knuckleblaster (güçlü yumruk, basılı tut: şok dalgası) · Whiplash
  - Dükkân fiyatları: Marksman 1.500, Sharpshooter 3.000 · Shotgun 2.000 (+2.000/3.000) · Nailgun
    3.500 (+2.500/3.000) · Railcannon 5.500 (+3.500/4.500) · Rocket 6.500 (+3.500/4.000) ·
    Knuckleblaster 3.000 · Whiplash 2.500 P. Varyant için önce temel silah alınmalı.
- PARRY: uzun kol (mermiler ~7 m, parlayan saldırılar ~6.5 m + düşman yarıçapı; kol ekranda ileri
  uzanır), yumruktan sonra 0,18 sn tampon penceresi; birden çok parlayan düşman varsa nişangâhın
  baktığı seçilir; geri yollanan mermi nişan alınan düşmana yönelir;
  parlayan yakın saldırıyı bozar; çekirdek/roket/gülleyi fırlatır; bozuk parayı yumruklama; yakın
  mesafede shotgun parry; can tamamen dolar, hitstop ve ekran nabzı. Knuckleblaster mermi savuşturmaz.
- Düşmanlar (eklem hiyerarşili 3D model, prosedürel animasyon, renkli tipler): Filth (yeşil, atlayış
  saldırısı), Stray (turuncu, savuşturulabilir küre), Schism (mor, mermi dizisi ve bıçak),
  **Malicious Face** (havada süzülen taş kafa: küre yağmuru, kilitlenen ışın — dash ile kaçılır;
  gözler zayıf nokta; ölünce düşüp patlar), boss Swordsmachine (sarı zırh, 2 faz), boss
  **Cerberus** (canlanan taş heykel: büyük küre, zıplanarak aşılan sarsıntı dalgası, parry ile
  bozulan parlayan hücum, duvara çarpınca sersemler). Vuruş tepkisi, sersemleme/saldırı bölme, kafa
  takibi; ölüm biçimleri: parçalanma, kafa kopması (kan fıskiyesi) ve cesedin yığılması.
- Kanla iyileşme, sert hasar, stamina, hasarsızlık kareleri
- Stil ölçeri DESTRUCTIVE → ULTRAKILL, bonus listesi, silah tazeliği, çoklu öldürme, ARSENAL
- Bölüm sonu sıralaması: süre, öldürme, stil (D–S), gizliler, meydan okuma, toplam sıra ve P-rank
- Ses: JS içinde DSP ile üretilen örnekler (filtre, doygunluk, yankı), mekânsal konum ve mesafe
  filtresi; stil rütbesine göre gitar/lead katmanı açan prosedürel müzik
- Retro görünüm: düşük çözünürlük, renk sıkıştırma + dither, PSX köşe titremesi (ayarlanabilir)

## Geliştirme

```sh
cd apps/ultrakill-3d
npm install          # three, esbuild, playwright-core (yalnız geliştirme)
npm run build        # → dist/ultrakill-3d.html
CHROME=/yol/chrome npm test                 # masaüstü duman testi (36 kontrol)
CHROME=/yol/chrome node tests/tutorial.mjs  # tutorial parkuru, parry eğitmeni, intro/ölüm (11 kontrol)
CHROME=/yol/chrome node tests/mobile.mjs    # dokunmatik emülasyon testi (22 kontrol)
CHROME=/yol/chrome node tests/levels.mjs    # 5 bölüm, dükkân/P, yeni düşmanlar, nişan, parry (22 kontrol)
CHROME=/yol/chrome node tests/tour.mjs      # görsel tur ekran görüntüleri
npm run apk                                 # → dist/ultrakill-3d.apk (Python 3 + JDK 11+, Android SDK gerekmez)
CHROME=/yol/chrome npm run test:apk         # APK içeriği: yerel köken, köprü, yazı tipleri (11 kontrol)
```

APK derleyicisi (`android/build_apk.py`) araçları Maven Central'dan indirip SHA-256 ile doğrular:
apktool-lib'in aapt2'si ve çerçeve kaynakları, API 16 derleme saplamaları, `dx` ve `apksig` (v2 imza).
İmza anahtarı `UK3D_KEYSTORE` / `UK3D_KEYSTORE_PASS` / `UK3D_KEY_ALIAS` ile verilir; verilmezse
`~/.config/uk3d/debug.p12` oluşturulur. Anahtarı depoya koyma. Kabuk kodu `android/java/`, köprü
betiği `android/assets-src/native-shim.js`, simge üreticisi `android/make_icons.mjs`.

Kaynak `src/` altında ES modülleridir; `build.mjs` hepsini esbuild ile tek HTML'e gömer.

| Dosya | Görev |
|---|---|
| `main.js` | Oyun döngüsü, durum makinesi, arenalar, hasar/parry/patlama, ölüm, ışık havuzu |
| `player.js` | V1 hareketi (dash, kayma, slam, duvar sıçraması), can/stamina |
| `weapons.js` | 5 silah × 3 varyant, kollar, kanca, bozuk para, görünür silah modelleri |
| `enemies.js` | Düşman modelleri, yapay zekâ, parry pencereleri, ölüm biçimleri |
| `projectiles.js` | Düşman mermileri, roket/gülle/çivi/testere/mıknatıs, bozuk paralar |
| `level.js` | Bölüm altyapısı: geometri, kapılar, tetikleyiciler, gizliler, dükkân terminali, tema |
| `levels/` | Bölüm kaydı (`index.js`), 0-1 … 0-5 düzenleri, ortak oda/çukur yardımcıları |
| `shop.js` | Dükkân kataloğu, fiyatlar ve satın alma ipuçları |
| `style.js` · `hud.js` · `ui.js` · `typer.js` | Stil ölçeri · oyun içi arayüz ve ölüm ekranı · menüler/intro/sonuç · daktilo metni |
| `touch.js` · `input.js` | Dokunmatik kontroller ve düzen düzenleyici · klavye/fare/pointer lock |
| `audio.js` · `music.js` | DSP ses bankası · prosedürel müzik |
| `physics.js` · `render.js` · `textures.js` · `fx.js` | AABB fizik · renderer/post · dokular · efektler |
| `android/` | Android WebView kabuğu, yerel köprü, simgeler, çevrimdışı yazı tipleri (OFL), APK derleyicisi |

## Lisans / atıf

Oyun kodu alpbahOS deposunun parçasıdır. Paket, MIT lisanslı three.js içerir
(Copyright © 2010-2026 three.js authors). APK, SIL Open Font License 1.1 lisanslı Anton, Chakra Petch
ve VT323 yazı tiplerini içerir (lisans metinleri `android/assets-src/fonts/`). ULTRAKILL adı ve oyun tasarımı sahiplerine aittir;
bu proje ticari olmayan bir hayran çalışmasıdır.
