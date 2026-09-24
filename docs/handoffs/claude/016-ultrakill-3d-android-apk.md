# Claude devir belgesi 016: ULTRAKILL 3D Android APK (`apps/ultrakill-3d/android`)

**Görev ID / durum:** Backlog dışı kullanıcı isteği ("Native android apk yapar mısın?"). Tamamlandı; derlendi ve statik olarak doğrulandı. Gerçek cihazda **çalıştırılmadı**.

**Çalışılan host ve branch:** Claude Code bulut konteyneri (Linux), dal `claude/3d-ultrakill-game-dev-qzqj42`, önceki commit `687b44e`. Kernel, rootfs, paket manifesti, `alp` motoru ve Hyper-V tarafına dokunulmadı.

**Değişen dosyalar:** Yalnız `apps/ultrakill-3d/**`, bu belge ve `docs/WORKLOG.md` sonundaki kayıt.

- Yeni:
  - `android/` klasöründe manifest, `MainActivity.java` ve derleme saplaması.
  - Simgeler ve simge üreticisi.
  - Yerel köprü betiği.
  - OFL yazı tipleri ve lisansları.
  - `build_apk.py` ve `tools/Sign.java`.
  - `tests/apk-web.mjs` ve `dist/ultrakill-3d.apk`.
- Güncellenen:
  - `package.json`: `apk` ve `test:apk` betikleri.
  - `.gitignore`.
  - README: Android bölümü.
  - `src/hud.js`: dokunmatik ipuçlarında `[E]`→KANCA, `[G]`→KOL eşlemesi ve "fareyle bak" yerine "sağda sürükleyerek bak".

## Gerçekleştirilen davranış

"Native" kelimesi burada oyunun Kotlin/OpenGL ile yeniden yazılması anlamına gelmiyor. Yapılan şey, aynı oyunu çalıştıran yerel bir Android uygulaması (WebView kabuğu).

- Tam ekran (immersive sticky), yatay (`sensorLandscape`) ve ekran açık kalır.
- Oyun APK içindeki `assets/www`'den, `https://appassets.androidplatform.net/` kökenine eşlenerek sunulur. Başka her istek engellenir.
- Ağ izni yok; tamamen çevrimdışı. Google Fonts yerine gömülü OFL yazı tipleri (latin + latin-ext) kullanılır.
- Köprü (`UKNative`):
  - titreşim yerel `Vibrator`'a gider,
  - Fullscreen API sessizce kabul edilir ve tam ekran butonu gizlenir,
  - GERİ tuşu: oyunda duraklat/devam, introyu geç, buton düzenleyiciyi kapat, sonuç ekranından menüye dön; menüde iki kez basınca çıkar,
  - arka plana geçişte oyun duraklar ve AudioContext askıya alınır.
- Paket bilgileri:
  - `org.alpbahos.uk3d`, sürüm 1.0 (versionCode 1).
  - minSdk 24, targetSdk 34.
  - APK Signature Scheme v2 imzası.
  - Boyut ~495 KB.

Android SDK kullanılmadı: `dl.google.com` bu oturumun ağ politikasında engelli (403). Araçlar Maven Central'dan alındı ve `build_apk.py` içinde SHA-256 ile sabitlendi:

- `org.apktool:apktool-lib:3.0.3`: aapt2 linux ikilisi ve API 36 çerçeve kaynakları.
- `com.google.android:android:4.1.1.4`: API 16 derleme saplamaları. API 17+ çağrıları yansıma ile yapılır; `@JavascriptInterface` için yalnız derlemede kullanılan saplama var.
- `com.google.android.tools:dx:1.7`: sınıf dosyası sürümü 50'ye indirilir; kod Java 7+ özelliği kullanmaz.
- `com.android.tools.build:apksig:2.3.0`: v1 kodu JDK 21 ile çalışmadığı için yalnız v2. minSdk 24 için yeterli.

## Çalıştırılan doğrulama ve sonuç

- `python3 android/build_apk.py`: APK üretildi.
  - apksig doğrulaması: `doğrulandı=true v2=true`.
  - `aapt2 dump badging`: paket, minSdk 24, targetSdk 34, VIBRATE izni, etiket, simge ve başlatıcı aktivite doğru.
  - Sıkıştırılmamış tüm girdiler 4 bayta hizalı; `resources.arsc` sıkıştırılmamış.
- `classes.dex` baksmali 2.5.2 ile açıldı:
  - 5 sınıf var.
  - Yalnız standart SDK çağrıları kullanılıyor.
  - `Bridge.vibrate` ve `Bridge.back` public ve `@JavascriptInterface` ile işaretli.
- `node tests/apk-web.mjs`: **10/10 geçti** (844×390 dokunmatik emülasyon). Kapsam:
  - APK içeriği aynı köken ve istek engelleme ile sunuldu.
  - Köprü taklidiyle yerel yazı tipleri yüklendi (Türkçe karakterler dahil); dış ağ isteği yok.
  - GERİ akışları, titreşim yönlendirmesi, arka plan duraklatma ve ses askıya alma çalıştı.
  - Buton düzenleyici kapanıyor; tam ekran butonu gizli; sayfa hatası yok.
- Web testleri (hud.js değişikliği sonrası):
  - `tests/smoke.mjs` 36/36.
  - `tests/tutorial.mjs` 11/11.
  - `tests/mobile.mjs` 19/19.

Çalıştırılmadı:

- Gerçek Android cihaz veya emülatörde kurulum ve çalıştırma. Emülatör/SDK indirilemedi.
- Bu nedenle Java tarafı (WebView ayarları, istek yakalama, immersive mod, GERİ tuşu, titreşim, yaşam döngüsü) gerçek ART/WebView üzerinde denenmedi.
- Performans ölçümü yapılmadı.

## Log / artifact

`dist/ultrakill-3d.apk` depoya eklendi; SHA-256 ve imza sertifikası özeti WORKLOG kaydındadır. İmza anahtarı yalnız bu konteynerde (`~/.config/uk3d/debug.p12`) oluşturuldu ve depoya konmadı.

## Bilinen sorun ve açık karar

- Konteyner geçici olduğu için imza anahtarı kaybolacak. Başka oturumda derlenen APK farklı imzalı olur; güncellemeden önce telefondaki uygulama kaldırılmalıdır.
- Kalıcı güncelleme için kullanıcının kendi anahtarını `UK3D_KEYSTORE` / `UK3D_KEYSTORE_PASS` / `UK3D_KEY_ALIAS` ile vermesi gerekir.
- Eski Android System WebView sürümlerinde WebGL2 olmayabilir. Gerekirse Play Store'dan WebView/Chrome güncellenmeli.
- Çentikli ekranlarda varsayılan kesik modu kullanılıyor; oyun çentik tarafında siyah bant bırakabilir.
- Sol kenardan geri hareketi (gesture navigation) oyunu duraklatabilir.
- Resmî olmayan hayran yapımıdır; mağazada yayımlanması ayrıca kullanıcı kararı gerektirir.

## Entegrasyon için gereken

Yok.

## Sonraki eylem

Kullanıcının APK'yı gerçek telefonda kurup denemesi ve şunları bildirmesi:

- açılış,
- dokunmatik kontroller,
- ses ve titreşim,
- GERİ tuşu,
- FPS.
