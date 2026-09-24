# ULTRAKILL 3D — hayran yapımı (PRELUDE 0-1 → 0-5, ARAF 1-1 → 1-4, Siber Öğütücü)

ULTRAKILL'in PRELUDE ve 1. katman ARAF bölümlerine saygı duruşu olarak yapılmış, tarayıcıda çalışan
3D bir hayran oyunu.
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
**Siber Öğütücü** (sonsuz dalga) 0-1 bitince açılır. 1-4'te V2 yenilince **V2 oynanabilir karakter**
olur (menü → OYNA → KARAKTER).

Menü, açılış ekranı ve intro bir **terminal** gibi görünür: sahne ASCII karakterlerle çizilir
(Ayarlar → GÖRÜNTÜ: ASCII RENKLİ / ASCII FOSFOR / DÜZ 3D). Oyunun kendisi normal 3D'dir.

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
| F | Yumruk ve PARRY (Ayarlar → YARDIM: parry yardımı ağır çekim + işaret + güdümlü geri yollama) |
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
- **Nişan yardımı** (Ayarlar → Dokunmatik): KAPALI / HAFİF / GÜÇLÜ (varsayılan). Hedef seçimi
  yapışkandır (başka düşman belirgin daha iyi değilse değişmez); hedef köşeli kırmızı çerçeveyle
  gösterilir; nişangâh yakındayken bakış yavaşlar; koşan düşman kısmen takip edilir (güçlüde
  %85); güçlüde ateş/ALT basılıyken hız sınırlı yumuşak çekim; mermi hedefin üst gövdesine bükülür.
- Telefonda sade arayüz: menüde bölüm kartları ve hep görünen BAŞLA, ağır efektler kapalı; menü,
  duraklatma, dükkân ve sonuç ekranları daha az kare çizer (pil/ısı). Sonuç ekranına dokunmak
  animasyonu atlar.
- Ayarlar → **SÜRÜKLE-YERLEŞTİR**: her buton ve joystick sürüklenip yeniden yerleştirilebilir;
  konumlar ekran oranı olarak kaydedilir (farklı telefonlarda da çalışır). SIFIRLA varsayılana döner.
- Ayarlanabilir: bakış hassasiyeti, nişan yardımı, buton boyutu ve saydamlığı. Desteklenen
  cihazlarda titreşim geri bildirimi.

### Android APK

`dist/ultrakill-3d.apk` (~545 KB, sürüm 1.3) telefona kurulabilir. Uygulama aynı oyunu tam ekran, yatay ve
**tamamen çevrimdışı** çalıştıran bir WebView kabuğudur (yazı tipleri de içinde; ağ izni yok).
Gerekenler: Android 7.0+ ve güncel "Android System WebView" (WebGL2).

- Kurulum: APK'yı telefona indir, aç, "bilinmeyen kaynaklardan yükleme" iznini ver. Play Protect
  tanımadığı geliştirici uyarısı gösterebilir ("Yine de yükle").
- GERİ tuşu: oyunda duraklat/devam, introyu geç, dükkânı ve buton düzenleyiciyi kapat; ana menüde
  iki kez basınca çıkar.
- Uygulama arka plana gidince oyun duraklar ve ses susar. Titreşim yerel Vibrator ile çalışır.
- Yeniden derleme başka bir imza anahtarıyla yapıldıysa, güncellemeden önce eski uygulamayı kaldır.

## İçerik

- Bölüm başı: V1 bölümün üstünde havada asılı küçük **üste** doğar; alarm çalar, yerdeki kapak
  açılır ve bölüme düşer. Bölüm sonu: sonuç ekranı, V1 karanlık bir kuyuda **düşerken** açılır
  (bölüm temasının renginde tünel, rüzgâr çizgileri; Siber Öğütücü'de üs yoktur)
- Terminal görünümlü açılış (boot günlüğü), ana menü (`$ ./oyna` komutları, katmanlı bölüm listesi,
  karakter ve zorluk seçimi) ve harf harf yazılan intro; arka plan ASCII shader ile çizilir. Oyun
  içi arayüz (HUD) ekran yüksekliğine göre küçülür, ipucu kutusu nişangâhı kapatmaz
- Ölüm ekranı: ağır çekim + gri/kırmızı görüntü, karartma, harf harf yazılan terminal satırları,
  **çenesi açılıp çığlık atan piksel kafatası**, çarpan "ÖLDÜN" başlığı ve yeniden doğuş istemi;
  ölünce alınan silahlar kaybolmaz
- Hasar alınca: ekran kenarına kan sıçrar ve aşağı akar, saldırının geldiği yönde kırmızı yay
  belirir, kamera darbeyle itilir
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
- KATMAN 1: ARAF (mavi gökyüzü, çimen, beyaz kale taşı):
  - **1-1 GÜNDOĞUMUNUN KALBİ**: kale avlusu (ilk Drone'lar), kırık hendek köprüsü, kule salonu
  - **1-2 YANAN DÜNYA**: yanan köy meydanı (ilk Streetcleaner'lar), alevli kirişli sokak, yanık kilise
  - **1-3 KUTSAL KALINTILAR SALONU**: heykeller galerisi, altın kiriş → mini boss **Hideous Mass**
  - **1-4 AY IŞIĞI**: ay ışığında düello meydanı → boss **V2**; kazanınca Knuckleblaster bedava ve
    V2 oynanabilir
- **SİBER ÖĞÜTÜCÜ** (farklı harita): 8×8 neon sütunlu ızgara; her dalgadan önce sütunlar yeni
  desene göre yükselir/alçalır, dalga bütçesi büyür (dalga 16'dan sonra V2 bile gelir). Dalga arası
  +40 can. Ölünce koşu biter; ulaşılan dalga ve en iyi dalga kaydedilir, dalga başına P
- Karakterler: **V1** (100 can, 3 stamina) · **V2** (85 can, %12 daha hızlı, %40 hızlı stamina,
  kırmızı Feedbacker)
- Silahlar (her biri 3 varyant, aynı tuşa tekrar basınca değişir):
  - Revolver: Piercer (şarjlı delici) · Marksman (bozuk para, RICOSHOT) · Sharpshooter (seken ışın)
  - Shotgun: Core Eject · Pump Charge (3. pompada patlama) · Sawed-On (geri dönen testere)
  - Nailgun: Attractor (mıknatıs) · Overheat (ısıtılmış çivi → yanma) · Sawblade (seken testere;
    namlular yerine dönen dişli testereli fırlatıcı, mermi dönen dişli disk)
  - Railcannon: Electric · Screwdriver (delip sürekli hasar) · Malicious (patlama)
  - Rocket Launcher: Freezeframe (roketleri dondur) · S.R.S. Cannon (gülle) · Firestarter (alev)
  - Kollar: Feedbacker (parry) · Knuckleblaster (güçlü yumruk, basılı tut: şok dalgası) · Whiplash
  - Alternatif silahlar (dükkânda KULLAN/ÇIKAR; varyantlar aynı kalır): **Slab Revolver** (4.000 P,
    yavaş ama %70 güçlü) · **Jackhammer** (5.000 P, Shotgun gerekir: kısa menzilli dev piston
    darbesi, havada yere ateşle → yüksek zıplama, pompa şarjı gücü artırır)
  - Para yardımı (Ayarlar → YARDIM): atış yakındaki paraya yönelir, para tepe noktasında asılı kalır,
    nişangâh sarıya döner
  - Dükkân fiyatları: Marksman 1.500, Sharpshooter 3.000 · Shotgun 2.000 (+2.000/3.000) · Nailgun
    3.500 (+2.500/3.000) · Railcannon 5.500 (+3.500/4.500) · Rocket 6.500 (+3.500/4.000) ·
    Knuckleblaster 3.000 · Whiplash 2.500 P. Varyant için önce temel silah alınmalı.
- PARRY görseli: yumruk ekranın ortasına fırlayıp titrer, önünden şok halkası büyür, ekran beyaz
  ışınlarla patlar, görüş kısa süre daralır; katmanlı metal çınlama + derin darbe sesi. Parry
  yardımı ağır çekimi korur ama ekrana "PARRY!" yazısı çıkarmaz
- PARRY: uzun kol (mermiler ~7 m, parlayan saldırılar ~6.5 m + düşman yarıçapı; kol ekranda ileri
  uzanır), yumruktan sonra 0,18 sn tampon penceresi; birden çok parlayan düşman varsa nişangâhın
  baktığı seçilir; geri yollanan mermi nişan alınan düşmana yönelir;
  parlayan yakın saldırıyı bozar; çekirdek/roket/gülleyi fırlatır; bozuk parayı yumruklama; yakın
  mesafede shotgun parry; can tamamen dolar, hitstop ve ekran nabzı. Knuckleblaster mermi savuşturmaz.
- Efektler: namlu alevi konisi ve kamera tepmesi, isabette kıvılcım/moloz/toz ve parlama, düşman
  isabetinde tık sesi, dash'te hız çizgileri ve hava sesi, sert inişte toz halkası; düşmanların
  yakın saldırıları önlerinde parlayan bir kavis bırakır, vuran darbe oyuncuyu iter ve kısa donma
  yapar. Boss'lar ölünce ağır çekimde titreyip parça parça kopar, sonunda patlar
- Görünür kollar: parmaklı Feedbacker / Knuckleblaster / Whiplash elleri; yumruk (geri çek → vur),
  başparmakla para fırlatma, kanca atma, duvar sıçramasında avuç, yere çakma, atılma savrulması,
  kayarken kıvılcımlı bacak; silahlar yay tabanlı geri tepme/iniş/çekme hareketi ve uzun boşta
  kalınca inceleme animasyonu yapar
- ARAF düşmanları: **Drone** (havada dolanır, iki mavi küre; ölünce sana dalar — yumrukla geri
  yolla), **Streetcleaner** (alev makinesi, nişan alınca kaçar, sırt tankı vurulunca patlar),
  **Hideous Mass** (mini boss: patlayan havan küreleri, savuşturulabilir zıpkın, kuyruk dalgası),
  **V2** (boss: çevrende döner/kayar, işaretli revolver atışı, çivi yağmuru, pompalı, parry ile
  bozulan Knuckleblaster hücumu, yarı canda öfke)
- Düşmanlar (eklem hiyerarşili 3D model, prosedürel animasyon, renkli tipler): Filth (yeşil, atlayış
  saldırısı), Stray (turuncu, savuşturulabilir küre), Schism (mor, mermi dizisi ve bıçak),
  **Malicious Face** (havada süzülen taş kafa: küre yağmuru, kilitlenen ışın — dash ile kaçılır;
  gözler zayıf nokta; ölünce düşüp patlar), boss Swordsmachine (sarı zırh, 2 faz), boss
  **Cerberus** (canlanan taş heykel: büyük küre — ikizler arasında ortak bekleme süresiyle seyrek, zıplanarak aşılan sarsıntı dalgası, parry ile
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
CHROME=/yol/chrome node tests/araf.mjs      # ARAF 1-1…1-4, Drone/Streetcleaner/Hideous Mass/V2, Siber Öğütücü,
                                            # V2 karakter, Slab/Jackhammer, parry/para yardımı, kollar, ASCII (22 kontrol)
CHROME=/yol/chrome node tests/feel.mjs      # üsten iniş, düşerken sonuç, parry efekti, kafatası, kan, boss parçalanma,
                                            # Cerberus nerfi, Sawblade, nişan yardımı, efektler (12 kontrol)
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
| `player.js` | V1/V2 hareketi (dash, kayma, slam, duvar sıçraması), can/stamina |
| `weapons.js` | 5 silah × 3 varyant + Slab/Jackhammer, kollar, kanca, bozuk para, silah modelleri, yardım |
| `arms.js` | Parmaklı görünür kollar, eylem animasyonları, kayma bacağı, yay (spring) |
| `enemies.js` · `enemies2.js` | PRELUDE düşmanları · ARAF düşmanları (Drone, Streetcleaner, Hideous Mass, V2) |
| `projectiles.js` | Düşman mermileri, roket/gülle/çivi/testere/mıknatıs, bozuk paralar |
| `level.js` | Bölüm altyapısı: geometri, kapılar, tetikleyiciler, gizliler, dükkân terminali, tema |
| `levels/` | Bölüm kaydı (`index.js`), 0-1 … 0-5, 1-1 … 1-4, Siber Öğütücü (`cg.js`), ortak yardımcılar |
| `shop.js` | Dükkân kataloğu, fiyatlar ve satın alma ipuçları |
| `style.js` · `hud.js` · `ui.js` · `typer.js` | Stil ölçeri · oyun içi arayüz ve ölüm ekranı · menüler/intro/sonuç · daktilo metni |
| `styles.css` · `theme-terminal.css` | Genel arayüz · yalnız açılış/menü/intro için terminal teması |
| `touch.js` · `input.js` | Dokunmatik kontroller ve düzen düzenleyici · klavye/fare/pointer lock |
| `audio.js` · `music.js` | DSP ses bankası · prosedürel müzik |
| `physics.js` · `render.js` · `textures.js` · `fx.js` | AABB fizik · renderer/post (ASCII shader dahil) · dokular · efektler |
| `fall.js` | Bölüm sonu düşüş sahnesi (sonuç ekranının arkası) |
| `android/` | Android WebView kabuğu, yerel köprü, simgeler, çevrimdışı yazı tipleri (OFL), APK derleyicisi |

## Lisans / atıf

Oyun kodu alpbahOS deposunun parçasıdır. Paket, MIT lisanslı three.js içerir
(Copyright © 2010-2026 three.js authors). APK, SIL Open Font License 1.1 lisanslı Anton, Chakra Petch
ve VT323 yazı tiplerini içerir (lisans metinleri `android/assets-src/fonts/`). ULTRAKILL adı ve oyun tasarımı sahiplerine aittir;
bu proje ticari olmayan bir hayran çalışmasıdır.
