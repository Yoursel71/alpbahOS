# Claude devir belgesi 019: ULTRAKILL 3D oyun hissi turu — üsten iniş, düşerken sonuç, parry/efekt/ses, kan, çığlık atan kafatası, boss parçalanma, nişan yardımı, Cerberus nerfi, Sawblade

**Görev ID / durum:** Backlog dışı kullanıcı isteği. İstenenler:

- oyuna girerken üsten düşerek başlama ve bölüm sonunda düşerken sonuç ekranı,
- silah efektleri,
- "çok küre atan" düşmanın nerflenmesi (kullanıcı cevabı: PRELUDE sonundaki iki boss → Cerberus),
- boss ölünce özel parçalanma,
- daha iyi düşman vuruşları,
- daha iyi nişan yardımı,
- vuruş/dash gibi eylemlere ses ve efekt,
- gerçekçi kan efekti,
- ölüm ekranında çığlık atan kafatası (kullanıcı seçimi),
- Nailgun SAWBLADE (kırmızı varyant) görünümünün düzeltilmesi (kullanıcı seçimi),
- özel parry animasyonu ve efekt/ses; ekranda "PARRY!" yazan işaretin kaldırılması.

Tamamlandı; web testleri ve APK içerik testi geçti. Gerçek cihazda **çalıştırılmadı**.

**Çalışılan host ve branch:** Claude Code bulut konteyneri (Linux), dal `claude/3d-ultrakill-game-dev-qzqj42`, önceki commit `9b62341`. Kernel, rootfs, paket manifesti, `alp` motoru ve Hyper-V tarafına dokunulmadı.

**Değişen dosyalar:** Yalnız `apps/ultrakill-3d/**`, bu belge ve `docs/WORKLOG.md` sonundaki kayıt.

- Yeni dosyalar: `src/fall.js` (düşüş sahnesi), `tests/feel.mjs`.
- Güncellenen kaynaklar: `main.js`, `level.js` (üs, kapı hızı), `levels/cg.js`, `hud.js`, `arms.js`, `weapons.js`, `projectiles.js`, `enemies.js`, `player.js`, `fx.js`, `audio.js`, `styles.css`.
- Güncellenen test: `tests/araf.mjs` (parry yardımı artık yazı göstermez).
- Android: `android/build_apk.py` sürüm 1.3 / kod 4.
- Yeniden üretildi: `dist/ultrakill-3d.html`, `dist/ultrakill-3d.apk`. README güncellendi.

## Gerçekleştirilen davranış

### Başlangıç ve bitiş

- **Üs:** `Level.finalize` başlangıç noktası havadaysa oraya küçük bir metal oda kurar:
  - kırmızı uyarı şeritli kapak, pencere çıtaları, kırmızı lamba.
  - Oyuncu kapağın üstünde doğar. İki alarm bip'inden sonra (0,5 sn) kapak aşağı kayar; oyuncu bölüme düşer (~2 sn'de iniş).
  - Siber Öğütücü'de üs yoktur (`noBase`). Checkpoint'ten doğuşta üs kullanılmaz.
- **Düşerken sonuç:** Bölüm bitince ayrı, ışıksız bir "kuyu" sahnesi çizilir:
  - bölüm temasının renginde kayan çizgili tünel, yukarı akan rüzgâr çizgileri, dipte parlayan ışık,
  - aşağı bakan, dönen ve sallanan kamera.
  - Sonuç paneli yarı saydam arka planla bunun üstündedir. Telefonda bu sırada 30 kare/sn çizilir.

### Parry

- Ekrandaki "PARRY!" yardım işareti (halka + yazı) kaldırıldı. Parry yardımının ağır çekimi, pencere genişliği ve güdümü aynen duruyor.
- Özel animasyon:
  - yumruk ekranın ortasına fırlar, titreyerek parlar ve yavaşça çekilir,
  - önünden mavi-beyaz şok halkası büyür, yıldız parlaması görünür,
  - ekran beyaz ışınlarla patlar (CSS), görüş alanı kısa süre daralır.
- Ses: yeni katmanlı parry (keskin metal tık + gövde darbesi + alt bas + çınlama) ve gecikmeli, yükselen parıltı kuyruğu (`parryRing`).
- Parry sonrası can `maxHp`'ye dolar (V2 karakterinde 85).

### Hasar ve ölüm

- Ekrana kan:
  - Ayrı bir tuvalde saldırı yönündeki kenara düzensiz kan lekeleri ve sıçrantı damlaları düşer.
  - Bazıları aşağı akar, 2–3 sn'de söner.
  - Sayı hasara göre ölçeklenir.
- Saldırının geldiği yönü gösteren kırmızı yay ve kamerayı darbeden uzağa iten yuvarlanma/eğilme.
- Ölüm ekranı:
  - "ÖLDÜN" ile birlikte çenesi ayrı piksel kafatası belirir.
  - Çene açılıp titrer, gözler parlar, kafatası sarsılır.
  - Formantlı, bozuk bir çığlık sesi (`skullScream`) ve titreşim eşlik eder.

### Efektler ve sesler

- **Silahlar:**
  - namlu alevi konisi (dar uç namluda),
  - geri tepmede kamera sıçraması (nişanı bozmaz),
  - isabette daha fazla kıvılcım, parlama, toz ve moloz parçaları.
- **Düşman isabeti:** parlama (kafada sarı) ve kuru isabet tıkı (`hitTick`).
- **Hareket:** dash'te ekran kenarında hız çizgileri, mavi kenar ve hava yarma sesi (`dashWhoosh`); sert inişte toz halkası ve daha tok ses.
- **Düşman yakın saldırıları (NPC vuruşları):**
  - Her saldırıda önlerinde süpürülen parlak kavis ve hava sesi (`meleeWhoosh`).
  - Vuran darbe daha tok ses çıkarır, kısa donma yapar, ekranı sarsar ve oyuncuyu iter.
- **Boss parçalanması** (Swordsmachine, Cerberus, Hideous Mass, V2; zorla/çukurla ölümler hariç):
  - ağır çekim ve beyaz parlama,
  - boss ~1,7 sn titreyip kırmızı yanıp söner, parçaları kan fıskiyesiyle tek tek kopar,
  - sonunda büyük patlama, kan ve iç organ yağmuru.
  - Yeni ses: `bossDeath`.

### Cerberus nerfi (PRELUDE sonundaki iki boss)

- Küre seçilme şansı %40 → %25.
- İki Cerberus arasında 3,2 sn ortak küre beklemesi.
- Küre hazırlığı biraz daha uzun; sonraki bekleme 1,5–2,5 → 2,2–3,2 sn.
- Küre hızı 24 → 19, hasar 25 → 18, öngörü azaltıldı.
- Öfke: hız ×1,3 → ×1,2, bekleme çarpanı 0,65 → 0,8.

### Nailgun SAWBLADE

- Kırmızı varyantta dört namlu ve üst tambur gizlenir. Yerine alçak yan plakalı, kırmızı çıtalı bir testere yuvası ve üstünden taşan, dönen dişli testere görünür.
- Atınca testere kısa süre kaybolup yuvaya geri kayar.
- Testere mermisi uçuş yönüne bakan, kendi ekseninde dönen dişli disktir (tek şablondan kopyalanır).

### Nişan yardımı (dokunmatik)

- Hedef seçimi yapışkandır: mevcut hedef %35 avantajlı ve 1,6× geniş konide tutulur.
- Nişan noktası küçük düşmanlarda üst gövdedir (kafaya doğru %35).
- Yakınlıkta yavaşlama yumuşak geçişlidir: güçlü ×0,42, hafif ×0,65.
- Koşan düşmanın açısal hareketi bakışa eklenir: güçlü %85, hafif %50.
- Güçlüde ateş/ALT basılıyken hız sınırlı, uzaktayken hızlanan çekim; hafifte yalnız çok yakınken küçük düzeltme.
- Mermi yardım hedefine bükülür.
- Hedef, ekranda köşeli kırmızı çerçeveyle gösterilir.

## Çalıştırılan doğrulama ve sonuç

Headless Chromium 1194, SwiftShader yazılım GL.

- `node tests/feel.mjs` → **12/12** (yeni). Kapsam:
  - üsten iniş ve Siber Öğütücü istisnası,
  - düşerken sonuç ve menüde bitişi,
  - parry animasyonu, halkası, FOV ve patlaması; yazının olmaması,
  - kan, yön göstergesi ve kamera darbesi,
  - kafatası çığlığı,
  - boss parçalanma sekansı,
  - Cerberus küre hasarı/hızı ve ikiz beklemesi,
  - Sawblade modeli ve mermisi,
  - nişan yardımında takip, işaret ve yavaşlama,
  - namlu konisi, kamera tepmesi, düşman kavisi, yeni seslerin bankada olması.
- `tests/araf.mjs` 22/22, `tests/smoke.mjs` 36/36, `tests/tutorial.mjs` 11/11, `tests/mobile.mjs` 22/22, `tests/levels.mjs` 22/22.
- `python3 android/build_apk.py` →
  - `org.alpbahos.uk3d` 1.3 (kod 4), 543 KB, aynı imza anahtarı.
  - SHA-256 `77887de4fc06e89d658bf26bfaa17de22844e25d33eac9f2c493bb0a990cb84f`.
- `node tests/apk-web.mjs` → **11/11**.
- Görsel inceleme (ekran görüntüleri):
  - parry sekansı, Sawblade modeli,
  - masaüstü ve 844×390 hasar kanı ile ölüm kafatası,
  - namlu alevi, düşman kavisi, boss parçalanması,
  - üs içi, kapak açılışı, düşüş, düşerken sonuç ekranı.

**Çalıştırılmadı:**

- Gerçek telefon/GPU'da oynama; yeni efektlerin gerçek cihazdaki kare hızı etkisi.
- Seslerin kulakla dinlenmesi (parry, çığlık, dash, isabet tıkı, boss ölümü); yalnız üretildikleri doğrulandı.
- Nişan yardımının gerçek parmakla hissi.
- Gerçek Android cihazda APK kurulumu.

## Bilinen sorun ve açık karar

- Boss parçalanması 99+ hasarlı zorla öldürmelerde (test yardımcıları, çukur) atlanır; o durumda eski anlık parçalanma olur.
- Kan tuvali 384×216 çözünürlükte çizilir (performans için); büyük ekranda yumuşak görünür.
- Ölüm çığlığı ve boss ölüm sesi kodla üretilir; orijinal oyunun sesleri değildir.

## Entegrasyon için gereken

Yok.

## Sonraki eylem

Kullanıcının telefonda şunları denemesi ve geri bildirim vermesi:

- nişan yardımının yeni hissi,
- kan yoğunluğu,
- ses seviyeleri,
- üsten iniş süresi.
