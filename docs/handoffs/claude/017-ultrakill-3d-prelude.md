# Claude devir belgesi 017: ULTRAKILL 3D PRELUDE (0-2 → 0-5), dükkân, nişan yardımı, uzun parry, sade mobil arayüz

**Görev ID / durum:** Backlog dışı kullanıcı isteği. İstenenler:

- telefonda ateş ederken düşmana kayan nişan yardımı,
- yalnız Revolver verilmesi, diğer silahların oyun içi dükkândan alınması,
- oyunun ilk bölümünün tamamı (kullanıcı seçimi: PRELUDE'un kalanı, 0-2 → 0-5),
- daha uzun parry kolu,
- telefonu yormayan arayüz.

Tamamlandı; web testleri ve APK içerik testi geçti. Gerçek cihazda **çalıştırılmadı**.

**Çalışılan host ve branch:** Claude Code bulut konteyneri (Linux), dal `claude/3d-ultrakill-game-dev-qzqj42`, önceki commit `9719932`. Kernel, rootfs, paket manifesti, `alp` motoru ve Hyper-V tarafına dokunulmadı.

**Değişen dosyalar:** Yalnız `apps/ultrakill-3d/**`, bu belge ve `docs/WORKLOG.md` sonundaki kayıt.

- Yeni dosyalar:
  - `src/levels/index.js` (bölüm kaydı), `src/levels/common.js`, `src/levels/l01.js` … `src/levels/l05.js`.
  - `src/shop.js`.
  - `tests/levels.mjs`.
- `src/level.js`: bölüm altyapısına dönüştü. Eski 0-1 düzeni `levels/l01.js`'ye taşındı.
- Güncellenen kaynaklar: `main.js`, `enemies.js`, `weapons.js`, `ui.js`, `hud.js`, `touch.js`, `input.js`, `player.js`, `physics.js`, `settings.js`, `styles.css`.
- Güncellenen testler: `tests/smoke.mjs`, `tests/mobile.mjs`, `tests/apk-web.mjs`.
- Güncellenen Android dosyaları: `android/assets-src/native-shim.js` (GERİ dükkânı kapatır) ve `android/build_apk.py` (sürüm 1.1 / kod 2).
- Yeniden üretildi: `dist/ultrakill-3d.html`, `dist/ultrakill-3d.apk`. README güncellendi.

## Gerçekleştirilen davranış

### Çok bölümlü yapı

- Bölümler kök bir grupta kurulur. Bölüm değişince sahneden ve fizik dünyasından tamamen kalkar.
- Her bölümün kendi teması var: sis, gökyüzü ve ortam ışığı.
- Menüde bölüm kartları var. Bölümler sırayla açılır; ilerleme ve en iyi sıra kaydedilir.
- Sonuç ekranında "SONRAKİ BÖLÜM" var. Sıralama eşikleri ve meydan okuma bölüme özgüdür.
- 0-1'in adı "ATEŞİN İÇİNE" oldu. Katman adı "PRELUDE: İLK KAN".

### Bölümler

- **0-2 KIYMA MAKİNESİ**: dönen öğütücülü çukurlar, iki arena, dükkân, 2 gizli küre.
- **0-3 ÇİFTE BELA**:
  - Malicious Face tanıtımı, lav nehri ve tapınak.
  - Boss: iki Swordsmachine. Tek boss çubuğunda toplam can gösterilir.
- **0-4 TEK MAKİNELİK ORDU**: kolezyumda altı dalgalı tek arena.
- **0-5 CERBERUS**:
  - Kaidelerinde önceden yerleştirilmiş, uyuyan iki heykel.
  - Biri yarı cana inince diğeri uyanır. Biri ölünce diğeri öfkelenir.
  - Sonunda Cehennemin kapısı ve PRELUDE'un sonu.

### Yeni düşmanlar

**Malicious Face:**

- Havada süzülür.
- 7'li küre yağmuru atar; küreler savuşturulabilir.
- Kilitlenen ışın atar: kırmızı → beyaz, sonra ateş. Dash ile kaçılır.
- Gözleri zayıf noktadır.
- Ölünce düşer ve yere çarpınca patlar.

**Cerberus (boss):**

- Büyük küre atar.
- Sarsıntı dalgası: yerdeki oyuncuyu vurur, zıplayınca geçer.
- Parlayan hücum: parry ile bozulur, duvara çarparsa sersemler.
- Yakın pençe saldırısı yapar.
- Uyuyan hâli hasar almaz.

### Dükkân ve P ekonomisi

- Başlangıçta yalnız Revolver (Piercer) var. Tüm silahlar, varyantlar, Knuckleblaster ve Whiplash dükkândan alınır.
- Fiyatlar `src/shop.js`'de. Varyant için önce temel silah gerekir.
- Terminal kullanımı: masaüstünde B, dokunmatikte terminal yakınında beliren DÜKKÂN butonu.
- Sahiplik kalıcıdır. Aynı silah tuşu yalnız sahip olunan varyantlar arasında döner.
- P kuralları:
  - Stil puanı anında P olur.
  - Checkpoint'te, dükkânı açınca ve bölüm sonunda kasaya girer.
  - Ölünce yatırılmamış P kaybolur.
  - Gizli küre +1000 P.
  - Bölüm sonunda sıra ödülü ve meydan okuma ödülü.
- Eski "tüm silahlarla başla" seçeneği Ayarlar → OYUN'a "test modu" olarak taşındı.

### Nişan yardımı (dokunmatik)

- Ayar değerleri: KAPALI, HAFİF, GÜÇLÜ. Varsayılan GÜÇLÜ; eski `true` kaydı GÜÇLÜ'ye taşınır.
- GÜÇLÜ modda ateş ya da ALT basılıyken bakış yakındaki görünür düşmana doğru kayar (~0,32 rad koni).
- Nişangâh düşmanın üstündeyken bakış yavaşlar.
- Mermi bükme açısı güçlüde 0,1 rad.

### Parry

- Menziller:
  - mermi 5,2 → 7 m,
  - parlayan saldırı 5 → 6,5 m + düşman yarıçapı,
  - yumruk 3,2 → 4,2 m (Knuckleblaster 4,6 m).
- Tampon pencere 0,12 → 0,18 sn.
- Birden çok parlayan düşman varsa nişangâhın baktığı seçilir.
- Kol modeli daha uzun ön kolla ekranda ~1,2 birim ileri uzanır ve tepe noktasında kısa süre kalır.

### Mobil arayüz

- Menü:
  - bölüm kartları ve hep görünen BAŞLA,
  - dokunmatik ayarlar en üstte,
  - fare hassasiyeti gizli.
- Dokunmatikte logo glitch animasyonu, tarama çizgileri ve blur kapalı.
- Telefonda kare sınırı: menü 30, duraklatma/dükkân/sonuç 12 kare/sn.
- Sonuç ekranı:
  - iki sütuna sığar,
  - animasyon kısalır,
  - dokununca atlanır.

### Diğer

- İpucu kutusu masaüstünde HUD ile çakışmayacak yere taşındı.
- Başlık kartı görünürken ipucu kuyruğa alınır.

## Çalıştırılan doğrulama ve sonuç

Headless Chromium 1194, SwiftShader yazılım GL.

- `node tests/smoke.mjs` → **36/36**. Rastgelelik kaynaklı üç kırılgan kontrol sağlamlaştırıldı. Değişiklikten sonra üst üste 3 çalıştırma 36/36.
- `node tests/tutorial.mjs` → **11/11**.
- `node tests/mobile.mjs` → **22/22** (3 yeni kontrol):
  - DÜKKÂN butonu yalnız terminal önünde çıkar,
  - dokunarak satın alma ve kapatma,
  - bölüm kartı ve BAŞLA.
- `node tests/levels.mjs` → **22/22** (yeni). Kapsam:
  - 5 bölümde iniş, tüm arenalar, sıkışan düşman olmaması, çıkış → sonuç ve P, kilit açma,
  - P kuralları, dükkân önkoşulu, satın alma ve varyant döngüsü,
  - Malicious Face küre/ışın/dash/düşüş,
  - çift Swordsmachine boss çubuğu,
  - Cerberus: uyku, uyanma, sarsıntı (yerde/havada), hücum parry'si, ikizin uyanması ve öfkesi,
  - nişan mıknatısı (güçlü/kapalı), 6,2 m'den küre parry'si,
  - bölüm geçişinde sahne ve katı sayısının sabit kalması.
- `python3 android/build_apk.py` →
  - v2 imza doğrulandı,
  - `org.alpbahos.uk3d` 1.1 (kod 2),
  - önceki sürümle aynı imza sertifikası (üstüne güncelleme olarak kurulabilir).
- `node tests/apk-web.mjs` → **11/11** (yeni kontrol: GERİ dükkânı kapatır).
- Görsel inceleme: 0-2/0-3/0-4/0-5 arenaları, Malicious Face ve Cerberus yakın çekim, mobil menü, dükkân ve sonuç ekranı, yumruk kolu.

**Çalıştırılmadı:**

- Gerçek telefon ve masaüstü GPU'sunda oynama.
- Nişan yardımının gerçek parmakla hissi.
- Ses dinleme.
- Gerçek Android cihazda APK kurulumu.
- Bölümlerin baştan sona insan oyuncuyla oynanması. Arenalar testte düşmanlar zorla öldürülerek geçildi.
- Denge: P fiyatları, yeni düşman hasarları ve sıralama eşikleri tahminidir.

## Bilinen sorun ve açık karar

- Gerçek oyundan farklı olarak temel silahlar da dükkândan alınır. Bu, kullanıcının açık isteğidir.
- Gerçek ULTRAKILL'deki Act I (1-1 → 3-2) yapılmadı. Kullanıcı bu tur için PRELUDE'u seçti.
- Malicious Face ışını düşmanlara hasar vermez; yalnız oyuncuya.

## Entegrasyon için gereken

Yok.

## Sonraki eylem

Kullanıcının telefonda oynayıp şunlar hakkında geri bildirim vermesi:

- nişan yardımının gücü,
- P dengesi,
- 0-2 → 0-5 zorluğu.

İstenirse Act I'e (1-1 → 1-4, V2) geçilebilir.
