# ULTRAKILL — Unity sürümü (hayran yapımı)

Bu klasör, `apps/ultrakill-3d` web oyununun Unity'ye taşınmış hâlidir.

- Proje sahne, prefab, doku, malzeme ya da ses dosyası içermez. Her şey çalışma anında C# ile kurulur: geometri, dokular, düşman modelleri ve DSP ile üretilen sesler.
- Bu yüzden Unity'de açıp **Play**'e basmak yeterlidir.

> Hayran yapımıdır ve ticari değildir. ULTRAKILL; Arsi "Hakita" Patala ve New Blood Interactive'e aittir.

## Açma ve oynama

1. Unity Hub → **Add** → **Add project from disk** → bu klasörü (`apps/ultrakill-unity`) seçin.
   - `ProjectSettings/ProjectVersion.txt` içinde 2021.3.33f1 yazar.
   - Yüklü başka bir sürümle (2021.3+, 2022.3 LTS ya da Unity 6) açabilirsiniz; Hub yükseltmeyi sorarsa onaylayın.
2. Proje açılıp derlendikten sonra iki yoldan biriyle başlatın:
   - **En kolayı:** Herhangi bir sahnede (boş sahnede bile) **Play**'e basın. Sahnede `UKGame` yoksa oyun kendiliğinden kurulur.
   - **Menü:** Üst menüden **ULTRAKILL → Sahneyi Oluştur ve Oyna** (`Ctrl+Shift+U`). `Assets/ULTRAKILL/ULTRAKILL.unity` sahnesini oluşturur, Build Settings'e ekler ve Play'e basar.
3. Oyun penceresine tıklayın; fare kilitlenir.
   - `Esc` duraklatır; menüdeki ayarlar oradan da açılır.

### Önerilen ayarlar

- **Render hattı:** Yerleşik (Built-in). Proje yalnız Unity modüllerini kullanır; URP/HDRP gerekmez. URP'de de çalışır, ama ayrı görünür-model kamerası yalnız yerleşik hatta kurulur.
- **Girdi:** Kod eski Input Manager'ı kullanır. Proje yalnız yeni Input System'e ayarlıysa iki yol var:
  - `Project Settings → Player → Active Input Handling` = **Both** yapın.
  - Ya da `com.unity.inputsystem` paketini kurun. `ULTRAKILL.asmdef` paketi görürse `UK_INPUTSYSTEM` tanımlanır ve kod yeni sistemi kullanır.

  Hiçbir girdi sistemi etkin değilse menüde ve Console'da kırmızı bir uyarı çıkar.

## Kontroller

| Tuş | Eylem |
| --- | --- |
| `W A S D` / fare | hareket / bakış |
| `Boşluk` | zıpla; havada duvara doğru basınca **duvar sıçraması** (yere değmeden 3 kez) |
| `Shift` | **atıl**: hasarsız, 3 stamina. Atılırken zıplamak uzun sıçrayış yapar |
| `C` / `Ctrl` | yerde **kay**; havada **yere çak**. Çarpar çarpmaz zıplamak: **çakış sıçrayışı** |
| Sol tık / sağ tık | ateş / alternatif atış |
| `1` `2` `3`, tekerlek | REVOLVER (sağ tık basılı: PIERCER) / SHOTGUN (sağ tık basılı: CORE EJECT) / NAILGUN |
| `F` | FEEDBACKER yumruğu. Mermiyi ya da **parlayan** saldırıyı geri çevirir (**PARRY**): canı doldurur |
| `Esc` | duraklat |

## İçerik

- **Menü ve intro:** Terminal/ASCII görünüm yalnız bunlardadır: ASCII ULTRAKILL logosu, zorluk seçimi, ayarlar ve V1'in uyanış terminali. Oyun içi HUD normal görünümdedir.
- **Bölüm 0-1 "ATEŞİN İÇİNE":**
  - Üsten bacadan aşağı düşerek iniş.
  - Atılma boşluğu.
  - **ARENA 1:** Filth ve Stray dalgaları.
  - Platformlu lav koridoru.
  - **ARENA 2:** Drone, Stray ve Filth.
  - Boss **SWORDSMACHINE**: 3 vuruşluk kombo (son vuruş parlar ve PARRY'lenir), pompalı, atılma saldırısı ve öfke fazı.
  - Boss ölünce ortadaki kapak açılır. Aşağı atlayınca **düşerken sonuç ekranı** gelir: SÜRE / ÖLDÜRME / STİL ve D–S–P dereceleri.
- **V1 hareketi:** Web sürümüyle aynı sabitler: koşu 13,5 m/sn, atılma 44 m/sn, kayma, yere çakma, duvar sıçraması, atılma zıplaması, çakış sıçrayışı.
- **Stil ölçeri:** D → ULTRAKILL rütbeleri, bonus listesi, silah tazeliği (FRESH/USED/STALE/DULL), DOUBLE/TRIPLE/MULTIKILL, ARSENAL.
- **Savaş kuralları:**
  - yakında dökülen kan canı doldurur,
  - kalıcı (gri) hasar,
  - PARRY'de vuruş donması ve tam can,
  - kafadan vuruş, havada vurma (AIRSHOT),
  - kontrol noktası, ölünce çığlık atan piksel kafatası.
- **Efektler:** Namlu alevi ve ışığı, izler, kıvılcım, parçalanma (gib), kan lekeleri (duvar/zemin izi), ekranda akan kan, hasar yönü, hız çizgileri, boss'un parça parça kopan ölüm sekansı.

## Dosyalar

```
Assets/ULTRAKILL/Scripts/   (ULTRAKILL.asmdef)
  UKGame.cs        sahneyi devralır, durum makinesi, hasar/parry/patlama/nişan yardımı/zaman
  UKPlayer.cs      V1 hareket denetleyicisi ve kamera
  UKWeapons.cs     silahlar, görünür modeller, Feedbacker yumruğu
  UKProjectile.cs  küreler, çiviler, çekirdek bombası, boss saçmaları
  UKEnemies.cs     iskelet, FILTH, STRAY, DRONE, SWORDSMACHINE
  UKLevel.cs       bölüm 0-1 geometrisi, arenalar, kapılar, lav, ipuçları
  UKStyle.cs       stil ölçeri
  UKHud.cs         IMGUI arayüzü (HUD, menü, intro, duraklatma, ölüm, sonuç)
  UKFx.cs          malzemeler, kodla dokular, parçacık/iz/halka/ışık efektleri
  UKAudio.cs       DSP ile üretilen ses bankası
  UKInput.cs       eski/yeni girdi sistemi katmanı
  UKHitbox.cs      gövde/kafa isabet bölgeleri
Assets/ULTRAKILL/Editor/    (ULTRAKILL.Editor.asmdef)
  UKMenu.cs        "ULTRAKILL" editör menüsü
```

## Doğrulama durumu

- Tüm C# dosyaları Unity 2021.3.33 başvuru derlemelerine karşı (`UnityEngine.Modules` NuGet paketi, .NET Framework 4.8, C# 9) **hatasız ve uyarısız derlendi**. Editör betiği UnityEditor başvurusuyla ayrıca derlendi.
- **Unity Editör'de çalıştırılmadı.** Bu ortamda Unity yok; oynanış, görünüm, ses ve performans gerçek Editör'de denenmedi.
- Yeni Input System kod yolu derleme denetimine girmedi (paket DLL'i yok).
