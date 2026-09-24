# ULTRAKILL 3D — hayran yapımı (0-1 "İLK KAN")

ULTRAKILL'in ilk bölümüne saygı duruşu olarak yapılmış, tarayıcıda çalışan 3D bir hayran oyunu.
Tüm 3D modeller, dokular, sesler ve müzik çalışma anında kodla üretilir; orijinal oyundan hiçbir
varlık kullanılmaz. **Resmî değildir**; ULTRAKILL, Arsi "Hakita" Patala / New Blood Interactive'in
oyunudur.

## Nasıl oynanır

`dist/ultrakill-3d.html` tek dosyadır: çift tıklayıp Chromium/Firefox tabanlı bir tarayıcıda aç
(sunucu gerekmez, internet gerekmez; yalnız yazı tipleri çevrimiçiyse Google Fonts'tan gelir,
değilse yedek yazı tiplerine düşer). WebGL2 gerekir.

Bölüm gerçek oyundaki gibi **silahsız** başlar: önce tutorial kanadında hareket öğretilir,
silahlar ilerledikçe sunaklardan alınır. Menüdeki "Tüm silahlarla başla" seçeneği bunu atlar.

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
  Üstte 1-5 silah, ≡ istatistik, ⛶ tam ekran, II duraklat.
- Ayarlar → **SÜRÜKLE-YERLEŞTİR**: her buton ve joystick sürüklenip yeniden yerleştirilebilir;
  konumlar ekran oranı olarak kaydedilir (farklı telefonlarda da çalışır). SIFIRLA varsayılana döner.
- Ayarlanabilir: bakış hassasiyeti, nişan yardımı, buton boyutu ve saydamlığı. Desteklenen
  cihazlarda titreşim geri bildirimi.

## İçerik

- Açılış, ana menü (bölüm, zorluk, ayarlar, kontroller, hakkında), harf harf yazılan terminal
  introsu ve büyük sarsıntılı başlık yazıları, bölüm başlık kartı
- Ölüm ekranı: ağır çekim + gri/kırmızı görüntü, karartma, harf harf yazılan terminal satırları,
  çarpan "ÖLDÜN" başlığı ve yeniden doğuş istemi; ölünce alınan silahlar kaybolmaz
- 0-1 "İLK KAN":
  - Tutorial kanadı: iniş odası → atılma zıplamasıyla geçilen boşluk → kayarak geçilen alçak
    engel → duvar sıçramasıyla çıkılan kuyu → çakış sıçrayışıyla çıkılan çıkıntı → Revolver sunağı
  - Arenalar arası sunaklar: Whiplash, Nailgun, Shotgun; parry eğitmeni (yalnız savuşturmayla ölen,
    öldürünce kapı açılan mavi düşman); silah deposunda Railcannon, Rocket Launcher, Knuckleblaster
  - Kilitlenen arenalar, dalgalar, checkpoint'ler, 3 gizli küre, boss Swordsmachine ve çıkış deliği
- Silahlar (her biri 3 varyant, aynı tuşa tekrar basınca değişir):
  - Revolver: Piercer (şarjlı delici) · Marksman (bozuk para, RICOSHOT) · Sharpshooter (seken ışın)
  - Shotgun: Core Eject · Pump Charge (3. pompada patlama) · Sawed-On (geri dönen testere)
  - Nailgun: Attractor (mıknatıs) · Overheat (ısıtılmış çivi → yanma) · Sawblade (seken testere)
  - Railcannon: Electric · Screwdriver (delip sürekli hasar) · Malicious (patlama)
  - Rocket Launcher: Freezeframe (roketleri dondur) · S.R.S. Cannon (gülle) · Firestarter (alev)
  - Kollar: Feedbacker (parry) · Knuckleblaster (güçlü yumruk, basılı tut: şok dalgası) · Whiplash
- PARRY: yumruktan sonra kısa tampon penceresi; geri yollanan mermi nişan alınan düşmana yönelir;
  parlayan yakın saldırıyı bozar; çekirdek/roket/gülleyi fırlatır; bozuk parayı yumruklama; yakın
  mesafede shotgun parry; can tamamen dolar, hitstop ve ekran nabzı. Knuckleblaster mermi savuşturmaz.
- Düşmanlar (eklem hiyerarşili 3D model, prosedürel animasyon, renkli tipler): Filth (yeşil, atlayış
  saldırısı), Stray (turuncu, savuşturulabilir küre), Schism (mor, mermi dizisi ve bıçak), boss
  Swordsmachine (sarı zırh, 2 faz). Vuruş tepkisi, sersemleme/saldırı bölme, kafa takibi; ölüm
  biçimleri: parçalanma, kafa kopması (kan fıskiyesi) ve cesedin yığılması.
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
CHROME=/yol/chrome node tests/mobile.mjs    # dokunmatik emülasyon testi (19 kontrol)
CHROME=/yol/chrome node tests/tour.mjs      # görsel tur ekran görüntüleri
```

Kaynak `src/` altında ES modülleridir; `build.mjs` hepsini esbuild ile tek HTML'e gömer.

| Dosya | Görev |
|---|---|
| `main.js` | Oyun döngüsü, durum makinesi, arenalar, hasar/parry/patlama, ölüm, ışık havuzu |
| `player.js` | V1 hareketi (dash, kayma, slam, duvar sıçraması), can/stamina |
| `weapons.js` | 5 silah × 3 varyant, kollar, kanca, bozuk para, görünür silah modelleri |
| `enemies.js` | Düşman modelleri, yapay zekâ, parry pencereleri, ölüm biçimleri |
| `projectiles.js` | Düşman mermileri, roket/gülle/çivi/testere/mıknatıs, bozuk paralar |
| `level.js` | 0-1 geometrisi, tutorial kanadı, sunaklar, kapılar, tetikleyiciler, gizliler |
| `style.js` · `hud.js` · `ui.js` · `typer.js` | Stil ölçeri · oyun içi arayüz ve ölüm ekranı · menüler/intro/sonuç · daktilo metni |
| `touch.js` · `input.js` | Dokunmatik kontroller ve düzen düzenleyici · klavye/fare/pointer lock |
| `audio.js` · `music.js` | DSP ses bankası · prosedürel müzik |
| `physics.js` · `render.js` · `textures.js` · `fx.js` | AABB fizik · renderer/post · dokular · efektler |

## Lisans / atıf

Oyun kodu alpbahOS deposunun parçasıdır. Paket, MIT lisanslı three.js içerir
(Copyright © 2010-2026 three.js authors). ULTRAKILL adı ve oyun tasarımı sahiplerine aittir;
bu proje ticari olmayan bir hayran çalışmasıdır.
