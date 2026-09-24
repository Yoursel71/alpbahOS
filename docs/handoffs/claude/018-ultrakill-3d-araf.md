# Claude devir belgesi 018: ULTRAKILL 3D "en büyük güncelleme" — ARAF 1-1 → 1-4, Siber Öğütücü, yeni düşmanlar ve karakter, alternatif silahlar, kollar, yardımlar, terminal menü

**Görev ID / durum:** Backlog dışı kullanıcı isteği ("en büyük güncellemeyi getir"). İstenenler:

- daha iyi kollar ve V1 animasyonları,
- daha iyi arayüzler (GUI),
- biraz yardımlı (assisted) parry ve para (coin) sistemi,
- daha fazla bölüm ve farklı bir harita,
- yeni karakterler ve silahlar,
- mobil uyumluluk,
- terminal (CLI) görünümü. Kullanıcı düzeltmesi: **yalnız menü ve intro** ASCII/terminal olacak, oyunun kendisi normal 3D kalacak.

Tamamlandı; web testleri ve APK içerik testi geçti. Gerçek cihazda **çalıştırılmadı**.

**Çalışılan host ve branch:** Claude Code bulut konteyneri (Linux), dal `claude/3d-ultrakill-game-dev-qzqj42`. Önceki commit `0fc7e72`; ara commit `621243f` (terminal menü, yardımlar, kollar). Kernel, rootfs, paket manifesti, `alp` motoru ve Hyper-V tarafına dokunulmadı.

**Değişen dosyalar:** Yalnız `apps/ultrakill-3d/**`, bu belge ve `docs/WORKLOG.md` sonundaki kayıt.

- Yeni kaynaklar:
  - `src/arms.js`: parmaklı kollar, eylem animasyonları, yay.
  - `src/enemies2.js`: Drone, Streetcleaner, Hideous Mass, V2.
  - `src/theme-terminal.css`: yalnız açılış/menü/intro terminal teması.
  - `src/levels/l11.js` … `l14.js` ve `src/levels/cg.js` (Siber Öğütücü).
  - `tests/araf.mjs`.
- Güncellenen kaynaklar:
  - `main.js`, `render.js` (ASCII post shader), `weapons.js`, `player.js`, `projectiles.js`, `enemies.js` (yardımcı dışa aktarımı).
  - `level.js` (yeni malzemeler, `boxGeo` dışa aktarımı), `levels/index.js`, `levels/common.js`.
  - `hud.js`, `ui.js`, `settings.js`, `shop.js`, `textures.js`, `audio.js` (alev sesi), `styles.css`.
  - `build.mjs` (iki CSS dosyasını birleştirir).
- Güncellenen test: `tests/levels.mjs` (10 bölüm kartı, PRELUDE sonrası kilitler).
- Android: `android/build_apk.py` sürüm 1.2 / kod 3.
- Yeniden üretildi: `dist/ultrakill-3d.html`, `dist/ultrakill-3d.apk`. README güncellendi.

## Gerçekleştirilen davranış

### Terminal (CLI) görünümü — yalnız açılış, menü ve intro

- Açılış ekranı boot günlüğüdür. Menüde `$ ./oyna` biçiminde komut düğmeleri, pencere başlığı ve blok harfli ASCII logo vardır. Bölüm listesi, ayarlar ve intro terminal stilindedir.
- Menü/intro arkasındaki 3D sahne post shader ile ASCII karakterlerle çizilir.
  - Glif atlası, kenar vurgusu ve menüde düşman parlaklığı artışı kullanılır.
  - Ayarlar → GÖRÜNTÜ: ASCII RENKLİ / ASCII FOSFOR / DÜZ 3D.
- Oyun başlayınca ASCII kapanır. HUD, duraklatma, dükkân ve sonuç ekranları normal görünümündedir.

### Arayüz (GUI)

- Masaüstünde HUD ekran yüksekliğine göre küçülür (≤820 px %82, ≤620 px ~%65).
- İpucu kutusu üst ortaya taşındı; nişangâhı kapatmaz.
- Menüde katman başlıkları (PRELUDE / ARAF / SİBER ÖĞÜTÜCÜ), karakter seçimi ve sonsuz mod kartı var.
- Dükkânda "ALTERNATİF SİLAHLAR" grubu ve KULLAN/ÇIKAR düğmesi var.
- Siber Öğütücü için üstte DALGA sayacı ve ayrı "KOŞU BİTTİ" sonuç ekranı var.

### Kollar ve V1 animasyonları

- Feedbacker, Knuckleblaster ve Whiplash elleri parmaklıdır (4 parmak × 2 eklem + başparmak).
- Eylem pozları:
  - yumruk: geri çek → vur → tut,
  - para: başparmak yukarı el kalkar, başparmakla fırlatılır,
  - kanca: açık el ileri, kanca dönene kadar tutulur,
  - duvar sıçraması: avuç duvara,
  - yere çakma: yumruk hazır, inişte aşağı vuruş,
  - atılma: kol savrulur.
- Kayarken ekranda kıvılcımlı bir bacak görünür. Parry'de kol şeritleri beyaz parlar.
- Silahlar yay tabanlı geri tepme, iniş, zıplama ve çekme hareketi yapar. 9 sn boşta kalınca inceleme animasyonu oynar.
- Silahsızken sağ el aynalanmış parmaklı yumruktur.

### Yardımlı parry ve para (Ayarlar → YARDIM: KAPALI / HAFİF / GÜÇLÜ; telefonda varsayılan GÜÇLÜ)

- **Parry:**
  - Yaklaşan savuşturulabilir mermi ya da parlayan saldırıda kısa ağır çekim (0,34 sn, ×0,3), "PARRY!" halkası ve titreşim.
  - Tampon penceresi 0,18 / 0,26 / 0,34 sn.
  - Geniş hedef konisi. Güçlüde nişan yoksa en yakın görünür düşmana güdümlü geri yollama.
- **Para:**
  - Atış 0,24 rad (güçlü) / 0,1 rad (hafif) içindeki paraya yönelir.
  - Paranın isabet küresi büyür, para tepe noktasında asılı kalır.
  - Nişangâh sarıya döner.

### Yeni bölümler: KATMAN 1 — ARAF

Tema: mavi gökyüzü, çimen, beyaz kireçtaşı kale; yeni dokular çimen, kireçtaşı ve neon ızgara.

- **1-1 GÜNDOĞUMUNUN KALBİ**: bahçe ve dükkân, kale avlusu arenası (Drone tanıtımı), kırık hendek köprüsü, kule salonu, 2 gizli küre, altın kapı.
- **1-2 YANAN DÜNYA**: yanan köy meydanı (Streetcleaner tanıtımı), alevli kirişli sokak, dükkân nişi, yanık kilise (Swordsmachine + Streetcleaner'lar).
- **1-3 KUTSAL KALINTILAR SALONU**: heykeller galerisi, altın kiriş, mini boss Hideous Mass, çıkış kapağı.
- **1-4 AY IŞIĞI**: gece teması ve ay, düello meydanında boss V2. Kazanınca:
  - Knuckleblaster bedava ("V2'nin kolunu kopardın"),
  - V2 oynanabilir karakter olur.
- Her bölümün sıralama eşikleri ve meydan okuması var. Örnekler: 1-1'de bir Drone'u yumrukla geri yolla, 1-2'de 3 tank patlat.

### Farklı harita: SİBER ÖĞÜTÜCÜ (sonsuz mod)

- Neon ızgarada 8×8 hareketli sütun var. Her dalgadan önce sütunlar 7 desenden birine göre yükselir/alçalır; oyuncunun altındaki ve komşu sütunlar oynamaz.
- Dalga bütçesi büyür. Düşmanlar dalgaya göre açılır: dalga 11 Hideous Mass, 13 Cerberus, 16 V2.
- Dalga arasında +40 can ve P verilir.
- Ölünce (ya da checkpoint'e dönünce) koşu biter. Sonuç ekranı ulaşılan dalga, sıra ve P gösterir; en iyi dalga kaydedilir.
- 0-1 bitince açılır.

### Yeni düşmanlar ve karakterler

- **Drone**:
  - Havada dolanır, nişan alınca yana kaçar.
  - Göz parlayınca iki mavi küre atar.
  - Ölünce oyuncuya dalar. Yumrukla geri yollanınca patlar ve düşmanlara hasar verir.
- **Streetcleaner**:
  - Koşarak yaklaşır, yakından alev püskürtür (diğer düşmanları da yakar).
  - Nişan alınca yana kaçar.
  - Sırt tankı zayıf noktadır; vurulunca patlar.
- **Hideous Mass** (mini boss):
  - Yukarı fırlatılan, düştüğü yerde patlayan havan küreleri (parry ile geri yollanabilir).
  - Hızlı zıpkın, yakındaysa kuyruk dalgası.
  - Yarı canda öfkelenir.
- **V2** (boss):
  - Çevrede döner, kayar, zıplar.
  - Kırmızı nişan çizgili revolver atışı (kilitlenince kalınlaşır → atıl), çivi yağmuru ve yakında pompalı.
  - Parry ile bozulan parlayan Knuckleblaster hücumu.
  - Yarı canda öfkelenir.
- **Oynanabilir V2**: 85 can, %12 hız, %40 hızlı stamina, kırmızı Feedbacker ve turuncu stamina. Kilitliyken V1'e düşer.

### Yeni silahlar (dükkân → ALTERNATİF SİLAHLAR, KULLAN/ÇIKAR; varyantlar aynı kalır)

- **Slab Revolver** (4.000 P): 0,62 sn atış aralığı, 1,7 hasar (Piercer şarjı 3,4). Kalın gövdeli model.
- **Jackhammer** (5.000 P, Shotgun gerekir): shotgun'ın birincil atışının yerine geçer.
  - Önündeki koniye (7,5 m + pompa) dev piston darbesi.
  - Havada yere ateşleyince yüksek zıplama.
  - Pompa şarjı gücü ve menzili artırır.

## Çalıştırılan doğrulama ve sonuç

Headless Chromium 1194, SwiftShader yazılım GL.

- `node tests/araf.mjs` → **22/22** (yeni). Kapsam:
  - menü katmanları, CG kartı, V2 kilidi; ASCII'nin yalnız menüde açık olması,
  - 1-1 … 1-4 iniş, doğma noktalarının katı içinde olmaması, tüm arenalar, çıkış → sonuç ve P,
  - 1-4 sonrası V2 kilidi ve Knuckleblaster,
  - Drone küreleri ve dalış → yumrukla geri yollama → patlama,
  - Streetcleaner alev menzili, kaçma ve tank patlaması,
  - Hideous Mass havan / zıpkın / kuyruk dalgası / öfke,
  - V2 nişan çizgisi ve isabet, hücum parry'si,
  - Siber Öğütücü dalgaları, sütun desenleri, ölüm → sonuç ve rekor,
  - V2 karakter istatistikleri,
  - Slab ve Jackhammer (dükkân, KULLAN/ÇIKAR, hasar, menzil, zıplama),
  - parry yardımı ağır çekimi, para yardımı,
  - kol animasyonları.
- `node tests/smoke.mjs` → **36/36**, `tests/tutorial.mjs` → **11/11**, `tests/mobile.mjs` → **22/22**, `tests/levels.mjs` → **22/22**.
- `python3 android/build_apk.py` →
  - `org.alpbahos.uk3d` 1.2 (kod 3), 536 KB, v2 imza, önceki sürümlerle aynı anahtar.
  - SHA-256 `bbca1743ac9b7828e7a63c34b54f4f14de8291d49e3995a0affae68ebfa54e3c`.
- `node tests/apk-web.mjs` → **11/11**.
- Görsel inceleme (ekran görüntüleri):
  - kol pozları: yumruk, para, kanca, duvar, atılma, çakma, kayma bacağı,
  - 4 yeni düşman yakın çekim,
  - 1-1 … 1-4 ve Siber Öğütücü,
  - Slab / Jackhammer modelleri,
  - masaüstü HUD küçültmesi,
  - 844×390 dokunmatik menü (katmanlar, karakter), dükkân ve Siber Öğütücü.

**Çalıştırılmadı:**

- Gerçek telefon ve masaüstü GPU'sunda oynama; ASCII shader'ın gerçek GPU'daki hızı.
- Parry/para yardımının gerçek parmakla hissi.
- Ses dinleme (yeni alev döngüsü dahil).
- Gerçek Android cihazda APK kurulumu.
- Yeni bölümlerin baştan sona insan oyuncuyla oynanması. Arenalar testte düşmanlar zorla öldürülerek geçildi.
- Denge: yeni düşman hasarları, V2/Hideous Mass canı, Siber Öğütücü bütçesi, fiyatlar ve eşikler tahminidir.

## Bilinen sorun ve açık karar

- Gerçek ULTRAKILL'de Act I 1-1 → 3-2'dir; burada yalnız 1. katman (1-1 → 1-4) yapıldı.
- Karakter seçimi yalnız V1/V2; V2'nin kendine özgü silah seti yok (istatistik ve görünüm farkı).
- Sütunlar oyuncunun hemen altında oynamaz. Başka bir sütun yükselirken üstünden yürüyen düşman kısa süre itilebilir.
- Jackhammer darbesi mesafe/koni hesaplıdır, ışın izli değildir (duvar arkası LOS kontrolü var).
- Malicious Face ışını ve Streetcleaner alevi dışındaki düşman saldırıları diğer düşmanlara hasar vermez.

## Entegrasyon için gereken

Yok.

## Sonraki eylem

Kullanıcının telefonda oynayıp şunlar hakkında geri bildirim vermesi:

- yardımların gücü,
- ARAF zorluğu,
- V2 dövüşü,
- Siber Öğütücü dengesi,
- terminal menünün okunaklılığı.

İstenirse sonraki katman (2-x ŞEHVET) veya V2'ye özgü silahlar eklenebilir.
