# Claude devir belgesi 020: ULTRAKILL oyununun Unity'ye taşınması (apps/ultrakill-unity)

**Görev ID / durum:** Backlog dışı kullanıcı isteği: "unity açık aynı oyunu unity de yapmaya calıs".

- Bu oturumda bilgisayar kontrol araçları (computer use) yoktu; kullanıcının açık Unity Editör'ü uzaktan kullanılamadı.
- Bunun yerine depoya, Unity Hub ile açılıp Play'e basılarak oynanan bağımsız bir Unity projesi eklendi.
- Kod derleme denetiminden geçti. **Unity Editör'de çalıştırılmadı.**

**Çalışılan host ve branch:** Claude Code bulut konteyneri (Linux), dal `claude/3d-ultrakill-game-dev-qzqj42`, önceki commit `d8c7894`.

- Kernel, rootfs, paket manifesti, `alp` motoru, build/mount ve Hyper-V tarafına dokunulmadı.
- Web oyunu (`apps/ultrakill-3d`) değişmedi.

## Değişen dosyalar

Tümü yeni:

- `apps/ultrakill-unity/`
  - `README.md`, `.gitignore`
  - `Packages/manifest.json`: yalnız yerleşik Unity modülleri; URP ya da paket bağımlılığı yok.
  - `ProjectSettings/ProjectVersion.txt`: 2021.3.33f1.
  - `Assets/ULTRAKILL/Scripts/*.cs`: 12 dosya, `ULTRAKILL.asmdef`.
  - `Assets/ULTRAKILL/Editor/UKMenu.cs`, `ULTRAKILL.Editor.asmdef`.
- `docs/handoffs/claude/020-ultrakill-unity.md` (bu belge) ve `docs/WORKLOG.md` sonundaki kayıt.

## Gerçekleştirilen davranış

### Mimari

- Sahne dosyası, prefab ya da ikili varlık yoktur.
- `UKGame`, `RuntimeInitializeOnLoadMethod(AfterSceneLoad)` ile sahnede kendisi yoksa kendini kurar. Bu yüzden herhangi bir sahnede Play'e basmak yeter.
- `UKGame` sahneyi devralır:
  - mevcut ışıkları kapatır, kendi güneşini kurar,
  - düz ortam ışığı ve kızıl sis,
  - `Camera.main` (yoksa yeni kamera) ve AudioListener.
- Geometri kodla kutulardan kurulur: dünya ölçekli UV'li kutu ağları ve BoxCollider.
- Dokular kodla üretilir: taş, karo, metal, kaya, et, gürültü.
- Malzemeler ilkel küpün varsayılan malzemesinden türetilir; yerleşik hatta ve URP'de çalışır. Efektler `Sprites/Default` ile çizilir.
- Sesler, web sürümündeki DSP yaklaşımıyla C# içinde `AudioClip.Create` ile üretilir. 41 ses var: silahlar, parry, çığlık, boss ölümü, rütbe yükselmesi vb.
- Görünür silah modeli yerleşik hatta ayrı bir kamerada (katman 1) çizilir, böylece duvara girmez.
- Arayüz IMGUI ile çizilir (1080p sanal çözünürlük).

### Oyun

- **Hareket (UKPlayer):** web sürümüyle aynı sabitler.
  - koşu, zıplama, 3 duvar sıçraması,
  - atılma (hasarsızlık, 3 stamina), kayma,
  - yere çakma ve çakış sıçrayışı, atılma zıplaması.
  - Kamera: salınım, iniş çökmesi, eğim, sarsıntı, FOV vuruşu, darbe itmesi.
- **Silahlar (UKWeapons):**
  - REVOLVER; sağ tık basılı tutulunca PIERCER, delici atış.
  - SHOTGUN: 12 saçma; sağ tık basılı tutulunca CORE EJECT, patlayan çekirdek.
  - NAILGUN.
  - FEEDBACKER yumruğu ve parry animasyonu.
  - Kutulardan kurulmuş görünür modeller, namlu alevi ve ışığı, geri tepme, sallanma.
- **Düşmanlar (UKEnemies):** eklem hiyerarşili kutu iskelet, prosedürel animasyon.
  - FILTH: parlayan atlayış ve yakın saldırı.
  - STRAY: savuşturulabilir küre.
  - DRONE: uçar, iki küre atar, ölünce patlar.
  - SWORDSMACHINE: boss, 3 vuruşluk kombo. Son vuruş parlar ve parry'lenir; pompalı saçma, atılma, öfke fazı.
  - Ölümde parçalanma ve kan. Boss'ta ağır çekimle parça parça kopma sekansı.
- **Savaş kuralları (UKGame):**
  - kanla iyileşme, kalıcı (gri) hasar,
  - hasar yönü ve kamera darbesi,
  - parry: mermiler, parlayan saldırılar, çekirdek hızlandırma. Vuruş donması, tam can, özel efekt; ekranda "PARRY!" yazısı yok.
  - yumruk, patlama (oyuncuya hasar ve itme),
  - nişan yardımı (ayarlanabilir), ağır çekim.
- **Stil (UKStyle):** web tablosunun aynısı. D → ULTRAKILL rütbeleri, tazelik, bonuslar, çoklu öldürme, ARSENAL.
- **Bölüm 0-1 "ATEŞİN İÇİNE" (UKLevel):**
  - üsten bacadan düşerek iniş,
  - atılma boşluğu (lavlı çukur → kontrol noktasına dönüş),
  - ARENA 1 (2 dalga), lav koridoru, ARENA 2 (2 dalga),
  - SWORDSMACHINE odası.
  - Toplam 21 düşman.
  - Kilitlenen kapılar, ipuçları, kontrol noktaları.
  - Boss ölünce kapak açılır. Kapaktan düşünce sonsuz bacada düşerken sonuç ekranı gelir: süre, öldürme ve stil dereceleri; sonuç D–S ya da P. En iyi derece PlayerPrefs'te saklanır.
- **Arayüz (UKHud):**
  - Oyun içi HUD normal görünümdedir: can (gri hasar), stamina, silah ve tazelik, stil ölçeri, boss çubuğu, nişangâh ve PIERCER şarjı, isabet işareti, ipucu/mesaj, ekranda akan kan lekeleri, hasar yönü, düşük can nabzı, hız çizgileri.
  - Terminal/ASCII görünüm yalnız ana menüde (ASCII logo, zorluk, ayarlar, kontroller) ve intro'dadır (web'deki V1 uyanış metni, atlanabilir).
  - Duraklatma: devam, son kontrol noktası, baştan başlat, ayarlar, kontroller, ana menü.
  - Ölüm ekranında çenesi ayrı piksel kafatası iki kez çığlık atar.
- **Editör menüsü (UKMenu):**
  - `ULTRAKILL → Sahneyi Oluştur ve Oyna` (Ctrl+Shift+U): sahneyi kaydeder, Build Settings'e ekler, Play'e basar.
  - `Oyna` ve `Ayarları Sıfırla`.

## Çalıştırılan doğrulama ve sonuç

- **Çalışma zamanı betikleri:** `dotnet build` (SDK 8.0, hedef .NET Framework 4.8, C# 9), NuGet `UnityEngine.Modules` 2021.3.33 başvuru derlemelerine karşı → 12/12 dosya derlendi, **0 hata, 0 uyarı**. Tanımlı sembol: `ENABLE_LEGACY_INPUT_MANAGER`.
- **Editör betiği:** `unity3d.unityeditor` 2018.1.6-f1 başvurusu ve çalışma zamanı derlemesine karşı → **0 hata, 0 uyarı**.
- **Tutarlılık denetimi:** Kodda çağrılan tüm ses adlarının bankada tanımlı olduğu ve piksel kafatası satır genişlikleri betikle doğrulandı.
- **Elle kod incelemesinde bulunup düzeltilen hatalar:**
  - Gövde kapsülü kafa küresini sardığı için kafadan vuruş hiç sayılmıyordu; `UKHitbox.PreferHead` eklendi.
  - Havada patlayan şeyin yanık izi boşlukta asılı kalıyordu.
  - Kan parçacıkları oyuncu kapsülüne çarpıyordu.
  - Yeni kurulan çarpıştırıcılar aynı karedeki ışın sorgularında görünmüyordu; `Physics.SyncTransforms` eklendi.
  - Domain reload kapalıyken yok edilmiş önbellek nesneleri kalabiliyordu.

**Çalıştırılmadı:**

- Unity Editör'de açma, derleme ve Play: oynanış, görünüm, ses, performans ve IMGUI yerleşimi.
- Yeni Input System kod yolu (`UK_INPUTSYSTEM`); paket DLL'i olmadığı için derleme denetimine de girmedi.
- URP projesinde çalışma.
- Oyuncu derlemesi (build): `Sprites/Default` ve Standard `_EMISSION` varyantlarının derlemede kalması denenmedi.

## Bilinen sorun ve açık karar

- Kapsam, web sürümündeki 0-1'in sadeleştirilmiş, tek bölümlük bir karşılığıdır. Unity sürümünde şunlar yok: diğer bölümler, Siber Öğütücü, dükkân, alternatif silahlar, bozuk para, V2, mobil dokunmatik.
- İlk açılışta (hiç ProjectSettings olmadan) Unity varsayılan ayarları üretir. Proje yalnız yeni Input System'e ayarlanırsa girdi çalışmaz; menüde ve Console'da uyarı çıkar. Çözüm README'de: Active Input Handling = Both.
- `ProjectVersion.txt` 2021.3.33f1 der. Kullanıcıda başka sürüm varsa Hub yükseltme sorar.
- `.meta` dosyaları depoda yok; Unity ilk açılışta üretir. Commit edilip edilmeyeceği kullanıcıya kalmış.

## Entegrasyon için gereken

Yok. Bağımsız bir uygulama klasörüdür; alpbahOS imajına, paket manifestine ve `alp`'e bağlanmadı.

## Sonraki eylem

- Kullanıcı projeyi Unity Hub'dan açıp Play'e basmalı ve Console'daki hata/uyarıları bildirmeli.
- İlk gerçek çalıştırmadan gelecek geri bildirimle görünüm ve denge ayarı yapılmalı.
- İstenirse web sürümündeki diğer bölüm ve düşmanlar taşınabilir.
