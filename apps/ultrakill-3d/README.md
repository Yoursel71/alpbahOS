# ULTRAKILL 3D — hayran yapımı (0-1 "İLK KAN")

ULTRAKILL'in ilk bölümüne saygı duruşu olarak yapılmış, tarayıcıda çalışan 3D bir hayran oyunu.
Tüm 3D modeller, dokular, sesler ve müzik çalışma anında kodla üretilir; orijinal oyundan hiçbir
varlık kullanılmaz. **Resmî değildir**; ULTRAKILL, Arsi "Hakita" Patala / New Blood Interactive'in
oyunudur.

## Nasıl oynanır

`dist/ultrakill-3d.html` tek dosyadır: çift tıklayıp Chromium/Firefox tabanlı bir tarayıcıda aç
(sunucu gerekmez, internet gerekmez; yalnız yazı tipleri çevrimiçiyse Google Fonts'tan gelir,
değilse yedek yazı tiplerine düşer). WebGL2 gerekir.

### Klavye + fare

| Tuş | Eylem |
|---|---|
| W A S D | Hareket |
| BOŞLUK | Zıpla · havada duvara doğru: duvar sıçraması (yere değmeden 3 kez) |
| SHIFT | Atıl (dash) — kısa süre hasar almazsın, 3 stamina |
| C | Yerde kay · havada yere çak (slam); çakıştan hemen sonra zıpla = yüksek sıçrayış |
| SHIFT → BOŞLUK | Atılma zıplaması (uzun atlayış) |
| Sol / sağ tık | Ateş / alternatif ateş |
| F | Yumruk (Feedbacker) ve PARRY |
| 1 2 3 · Q · tekerlek | Silah seç (aynı tuş: varyant) · son silah · değiştir |
| TAB · R · ESC | İstatistik · ölünce checkpoint · duraklat |

Kayma/çakma tuşu bilinçli olarak `C`'dir: tarayıcıda Ctrl+W sekmeyi kapatabilir.

### Dokunmatik (mobil)

Dokunmatik cihazda kontroller otomatik açılır (Ayarlar → Dokunmatik: Otomatik/Açık/Kapalı).
Sol altta kayan **joystick** ile yürü, ekranın sağ tarafında **sürükleyerek** bak (ATEŞ basılıyken
de bakılabilir). Butonlar: ATEŞ, ALT (şarj/para/çekirdek/pompa), ZIPLA, ATIL, KAY (havada ÇAK),
YUMRUK; üstte 1-2-3 silah, ≡ istatistik, ⛶ tam ekran, II duraklat. Dokunmatik modda hafif bir
nişan yardımı vardır (Ayarlar'dan kapatılabilir). Telefonu yatay tut.

## İçerik

- Açılış, ana menü (bölüm, zorluk, ayarlar, kontroller, hakkında), terminal introsu, bölüm başlık kartı
- 0-1 "İLK KAN": düşüş odası, boşluklu koridor, sütunlu salon, kayarak geçilen engel, lav havuzu,
  Swordsmachine arenası ve çıkış deliği; kilitlenen arenalar, dalgalar, 3 checkpoint, 3 gizli küre
- Düşmanlar (eklem hiyerarşili 3D modeller, prosedürel animasyon): Filth, Stray (savuşturulabilir
  küre), Schism (yatay/dikey mermi dizisi, bıçak savurma), boss Swordsmachine (kılıç kombosu,
  bumerang kılıç, pompalı, atılma, yarı canda öfke fazı)
- Silahlar: Revolver (Piercer şarjlı delici atış / Marksman bozuk para + RICOSHOT zinciri),
  Shotgun (Core Eject bombası / Pump Charge, 3. pompada patlama), Railcannon
- PARRY: mermiyi geri yollar ya da parlayan yakın saldırıyı bozar, canı tamamen doldurur, hitstop
- Kanla iyileşme, sert hasar (hard damage), stamina, hasarsızlık kareleri
- Stil ölçeri DESTRUCTIVE → ULTRAKILL, bonus listesi, silah tazeliği (FRESH/USED/STALE/DULL)
- Bölüm sonu sıralaması: süre, öldürme, stil (D–S), gizliler, meydan okuma, toplam sıra ve P-rank
- Sentezlenmiş ses efektleri ve stil rütbesine göre katman açan prosedürel müzik
- Retro görünüm: düşük çözünürlük, renk sıkıştırma + dither, PSX köşe titremesi (ayarlanabilir)

## Geliştirme

```sh
cd apps/ultrakill-3d
npm install          # three, esbuild, playwright-core (yalnız geliştirme)
npm run build        # → dist/ultrakill-3d.html
CHROME=/yol/chrome npm test            # masaüstü duman testi (30 kontrol)
CHROME=/yol/chrome node tests/mobile.mjs  # dokunmatik emülasyon testi (15 kontrol)
CHROME=/yol/chrome node tests/tour.mjs    # görsel tur ekran görüntüleri
```

Kaynak `src/` altında ES modülleridir; `build.mjs` hepsini esbuild ile tek HTML'e gömer.

| Dosya | Görev |
|---|---|
| `main.js` | Oyun döngüsü, durum makinesi, arenalar, hasar/parry/patlama, ışık havuzu |
| `player.js` | V1 hareketi (dash, kayma, slam, duvar sıçraması), can/stamina |
| `weapons.js` | Silahlar, bozuk para sekmesi, görünür silah modelleri ve animasyonları |
| `enemies.js` | Düşman modelleri, yapay zekâ, parry pencereleri, parçalanma |
| `projectiles.js` | Düşman mermileri, boss kılıcı, çekirdek bombası, bozuk paralar |
| `level.js` | 0-1 geometrisi, kapılar, tetikleyiciler, gizliler, gökyüzü |
| `style.js` · `hud.js` · `ui.js` | Stil ölçeri · oyun içi arayüz · menüler/intro/sonuç |
| `touch.js` · `input.js` | Dokunmatik kontroller · klavye/fare/pointer lock |
| `audio.js` · `music.js` | Ses sentezi · prosedürel müzik |
| `physics.js` · `render.js` · `textures.js` · `fx.js` | AABB fizik · renderer/post · dokular · efektler |

## Lisans / atıf

Oyun kodu alpbahOS deposunun parçasıdır. Paket, MIT lisanslı three.js içerir
(Copyright © 2010-2026 three.js authors). ULTRAKILL adı ve oyun tasarımı sahiplerine aittir;
bu proje ticari olmayan bir hayran çalışmasıdır.
