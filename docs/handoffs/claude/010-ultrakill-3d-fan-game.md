# Claude devir belgesi 010 — ULTRAKILL 3D hayran oyunu (`apps/ultrakill-3d`)

Görev ID / durum: Backlog dışı, kullanıcı talebi ("3D ULTRAKILL oyunu: menü, intro, ilk bölümün hepsi, 3D düşmanlar, animasyonlar, parry, sıralama" + "mobil butonlar ve yürüme joystick'i"). Tamamlandı; oynanabilir ilk sürüm.

Çalışılan host ve branch: Claude Code bulut oturumu (Linux konteyner), dal `claude/3d-ultrakill-game-dev-qzqj42`. Windows host, Hyper-V VM'leri, `/mnt/lfs`, paket manifesti ve `alp` motoru kullanılmadı ve değiştirilmedi.

Değişen dosyalar: yalnız `apps/ultrakill-3d/**` (yeni), bu devir belgesi ve `docs/WORKLOG.md` sonuna bir kayıt.

## Gerçekleştirilen davranış

- Tarayıcıda çalışan 3D oyun (Three.js 0.186, esbuild ile tek HTML: `apps/ultrakill-3d/dist/ultrakill-3d.html`, ~740 KB, çevrimdışı açılır).
- Açılış ekranı, ana menü (bölüm/zorluk/ayarlar/kontroller/hakkında), terminal introsu, bölüm başlık kartı, duraklatma, ölüm ekranı, bölüm sonu sıralaması (süre/öldürme/stil D–S, gizliler, meydan okuma, P-rank) ve yerel en iyi skor.
- 0-1 "İLK KAN": 4 kilitlenen arena (dalgalı), 3 koridor, boşluk/lav tehlikeleri, kayarak geçilen engel, 3 checkpoint, 3 gizli küre, boss sonrası çıkış deliği.
- V1 hareketi: koşu, zıplama, duvar sıçraması (3), dash + i-frame + 3 stamina, kayma, yere çakma, çakış sıçrayışı, dash-zıplaması.
- Silahlar: Revolver (Piercer / Marksman + bozuk para RICOSHOT zinciri), Shotgun (Core Eject / Pump Charge), Railcannon; Feedbacker yumruk ve PARRY (mermi geri yollama + yakın saldırı bozma, can dolumu, hitstop).
- Düşmanlar (eklem hiyerarşili 3D model + prosedürel animasyon + yapay zekâ): Filth, Stray, Schism, boss Swordsmachine (2 faz).
- Stil ölçeri DESTRUCTIVE→ULTRAKILL, bonuslar, silah tazeliği; kanla iyileşme, sert hasar.
- Sentezlenmiş ses ve katmanlı prosedürel müzik; retro görüntü (düşük çözünürlük, dither, PSX titremesi).
- Dokunmatik kontroller: kayan sol joystick, sağda sürükleyerek bakış (çoklu dokunuş), ATEŞ/ALT/ZIPLA/ATIL/KAY-ÇAK/YUMRUK butonları, silah 1-2-3, istatistik, tam ekran, duraklat; mobilde hafif nişan yardımı ve ayarlar.

## Çalıştırılan doğrulama ve sonuç

Ortam: bulut konteyner, Node 22.22.2, playwright-core 1.63.0, headless Chromium 1194 (SwiftShader yazılım GL).

- `node build.mjs` → `dist/ultrakill-3d.html` üretildi.
- `node tests/smoke.mjs` → **30/30 geçti** (menü, intro, düşüş/iniş, arena tetikleme, yürüme/dash/zıplama/kayma/slam, üç silahın isabeti, mermi parry, arena temizleme ve kapı, stil rütbesi/tazelik, checkpoint, gizli küre, ölüm ve geri dönüş, Stray küresi, Schism yakın saldırı parry'si, boss saldırı durumları, öfke fazı ve ölümü, çıkış → sıralama ekranı, duraklatma, sayfa hatası yok).
- `node tests/mobile.mjs` → **15/15 geçti** (844×390 dokunmatik emülasyon; CDP touch olaylarıyla joystick yürüyüşü, yürürken ikinci parmakla bakış, tüm butonlar, taklit fare olaylarının istemsiz ateş etmemesi).
- `node tests/tour.mjs` → bölge ve model ekran görüntüleri incelendi.

Çalıştırılmadı: gerçek GPU'lu masaüstünde ve gerçek telefonda insan oyun testi; ses çıktısı kulakla dinlenmedi (yalnız hata vermeden çalıştığı doğrulandı); alpbahOS imajı içinde tarayıcıyla çalıştırma (masaüstü/BLFS henüz yok). Zorluk dengesi ve sıralama eşikleri tahminidir.

Log / artifact: test ekran görüntüleri `apps/ultrakill-3d/tests/out/` altına yazılır (git'e eklenmez).

## Bilinen sorun ve açık karar

- Resmî olmayan hayran yapımıdır; ad/tasarım sahiplerine aittir, oyun içinde ve README'de belirtilmiştir. Ticari dağıtım veya alpbahOS varsayılan uygulama listesine alınması ayrıca kullanıcı kararı gerektirir.
- Pointer lock izin verilmeyen çerçevelerde otomatik olarak serbest fare moduna düşer.
- Sıralama eşikleri (süre S ≤ 4:00, stil S ≥ 6500) gerçek oyun ölçümüyle ayarlanmalıdır.

## Entegrasyon için gereken

Yok. Oyun bağımsızdır; alpbahOS'a ileride bir `.desktop` girdisi/uygulama profili eklenecekse masaüstü (BLFS + tarayıcı) hazır olduktan sonra ayrıca ele alınmalı.

Sonraki eylem: Kullanıcının gerçek cihazda (masaüstü + telefon) oynayıp denge/his geri bildirimi vermesi.
