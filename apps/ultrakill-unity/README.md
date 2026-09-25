# ULTRAKILL — Unity sürümü (hayran yapımı)

Bu klasör, `apps/ultrakill-3d` web oyununun Unity'ye taşınmış **tam** hâlidir: web sürümündeki bütün bölümler, silahlar, varyantlar, kollar, düşmanlar, dükkân, ilerleme ve müzik.

- Proje sahne, prefab, doku, malzeme ya da ses dosyası içermez. Her şey çalışma anında C# ile kurulur: geometri, dokular, düşman modelleri, DSP ile üretilen sesler ve gerçek zamanlı sentezlenen müzik.
- Bu yüzden Unity'de açıp **Play**'e basmak yeterlidir.

> Hayran yapımıdır ve ticari değildir. ULTRAKILL; Arsi "Hakita" Patala ve New Blood Interactive'e aittir.

## Kurulum

### A) Var olan projeye paket olarak (önerilen)

1. `dist/ULTRAKILL.unitypackage` dosyasını Unity'de açık projenize sürükleyin (ya da **Assets → Import Package → Custom Package**).
2. `Assets/ULTRAKILL/ULTRAKILL.unity` sahnesini açıp **Play**'e basın.
   - Oyun yalnız `ULTRAKILL` adlı sahnede ya da kaydedilmemiş boş sahnede kendiliğinden kurulur; projedeki başka oyunların sahnelerine dokunmaz.
3. Projede derleme hatası veren **başka** betikler varsa (ör. başka bir oyunun klasörü) Unity hiçbir betiği çalıştırmaz. Önce onları düzeltin ya da o klasörün adının sonuna `~` ekleyin (Unity `~` ile biten klasörleri yok sayar).

### B) Bu klasörü proje olarak

1. Unity Hub → **Add** → **Add project from disk** → `apps/ultrakill-unity`.
   - `ProjectSettings/ProjectVersion.txt` 2021.3.33f1 yazar; 2022.3 LTS ya da Unity 6 ile de açılır (Hub yükseltmeyi sorarsa onaylayın).
2. **ULTRAKILL → Sahneyi Oluştur ve Oyna** (`Ctrl+Shift+U`) ya da boş sahnede **Play**.

### Ayarlar

- **Render hattı:** Yerleşik (Built-in) ve URP ile çalışır. URP'de nokta ışıkları fiziksel sönüme göre güçlendirilir, görünür model kameraya doğru küçültülür (duvara girmez).
- **Girdi:** Eski Input Manager ya da yeni Input System. Proje yalnız yeni sisteme ayarlıysa `com.unity.inputsystem` paketi kuruluyken `ULTRAKILL.asmdef` bunu görür ve yeni sistemi kullanır. Hiçbiri etkin değilse menüde kırmızı uyarı çıkar (`Project Settings → Player → Active Input Handling = Both`).

## Kontroller

| Tuş | Eylem |
| --- | --- |
| `W A S D` / fare | hareket / bakış |
| `Boşluk` | zıpla; havada duvara doğru: **duvar sıçraması** (yere değmeden 3 kez) |
| `Shift` | **atıl** (hasarsız, 3 stamina); atılırken zıpla: uzun sıçrayış |
| `C` / `Ctrl` | yerde **kay**; havada **yere çak** → çarpınca zıpla: **çakış sıçrayışı** |
| Sol / sağ tık | ateş / alternatif atış (şarj, para, pompa, mıknatıs, dondurma…) |
| `1`–`5`, tekerlek, `Q` | silahlar; aynı tuşa tekrar: **varyant**; `Q` son silah |
| `F` | yumruk; mermiyi ya da **parlayan** saldırıyı geri çevirir (**PARRY**, canı doldurur). Knuckleblaster'da basılı tut: şok dalgası |
| `G` / `E` | Feedbacker ⇄ Knuckleblaster / Whiplash kancası |
| `B` | dükkân (yeşil terminalin önünde) |
| `Esc` | duraklat |

## İçerik

- **Bölümler** (web sürümünden birebir çevrildi; ilki bitince sıradaki açılır):
  - PRELUDE: `0-1 ATEŞİN İÇİNE` (silahsız iniş, hareket eğitimi, Revolver sunağı, parry eğitmeni, 3 arena, boss Swordsmachine), `0-2 KIYMA MAKİNESİ` (öğütücü çukurları), `0-3 ÇİFTE BELA` (Malicious Face, iki Swordsmachine), `0-4 TEK MAKİNELİK ORDU` (6 dalgalı kolezyum), `0-5 CERBERUS` (uyanan iki heykel).
  - KATMAN 1 ARAF: `1-1 GÜNDOĞUMUNUN KALBİ` (Drone), `1-2 YANAN DÜNYA` (Streetcleaner), `1-3 KUTSAL KALINTILAR SALONU` (Hideous Mass), `1-4 AY IŞIĞI` (boss V2 → Knuckleblaster ve oynanabilir V2).
  - `SİBER ÖĞÜTÜCÜ`: sonsuz dalga modu, dalgadan önce yükselip alçalan 8×8 neon sütunlar.
  - Her bölümde: üsten kapaktan düşerek iniş, kilitlenen arenalar ve dalgalar, checkpoint'ler, gizli küreler (+1000 P), ipuçları, lav ve çukurlar, bölüm teması (sis, gökyüzü, ışık), kuyuda düşerken sonuç ekranı (SÜRE / ÖLDÜRME / STİL, D–S–P, meydan okuma, P ödülü).
- **Silahlar (5 × 3 varyant):** REVOLVER (Piercer / Marksman bozuk para + ricoshot / Sharpshooter sekme), SHOTGUN (Core Eject / Pump Charge / Sawed-On), NAILGUN (Attractor mıknatıs / Overheat / Sawblade), RAILCANNON (Electric / Screwdriver / Malicious), ROCKET LAUNCHER (Freezeframe / S.R.S. Cannon / Firestarter). Alternatif silahlar: SLAB REVOLVER, JACKHAMMER. Kollar: FEEDBACKER, KNUCKLEBLASTER; WHIPLASH kancası.
- **Düşmanlar:** Filth, Stray, Schism, Swordsmachine, Malicious Face, Cerberus, Drone, Streetcleaner, Hideous Mass, V2 ve parry eğitmeni.
- **Dükkân ve P:** Stil puanı P olarak birikir; checkpoint'te, dükkânda ve bölüm sonunda kasaya girer, ölünce kasaya girmemiş P kaybolur. Revolver ücretsizdir; gerisi dükkânda satın alınır. İlerleme `PlayerPrefs` içinde saklanır (ayarlardan sıfırlanabilir; test için "tüm silahlar" seçeneği).
- **Savaş:** kanla iyileşme, kalıcı (gri) hasar, PARRY (mermi, parlayan saldırı, PROJECTILE BOOST, COIN PUNCH, SHOTGUN PARRY), parry ve para yardımı, nişan yardımı, patlamalar, vuruş donması, stil ölçeri ve tazelik.
- **Müzik:** web sürümündeki prosedürel breakcore/endüstriyel müzik: sakin, savaş ve boss katmanları; stil rütbesi yükseldikçe gitar ve lead açılır; duraklatma/dükkânda boğuklaşır.
- **Menü:** terminal görünümlü menü ve intro, bölüm seçimi, zorluk, karakter (V1 / V2), ayarlar, kontroller.

## Dosyalar

```
Assets/ULTRAKILL/Scripts/   (ULTRAKILL.asmdef)
  UKGame.cs        durum makinesi, bölüm akışı, P kasası, dükkân, sonuç, savaş kuralları
  UKLevel.cs       bölüm kurucu (kutular, kapılar, arenalar, sunak, dükkân, ışık, gökyüzü), sonuç düşüşü
  UKLevels.cs      10 bölümün düzeni (web levels/*.js'ten çevrildi) + Siber Öğütücü
  UKProgress.cs    kalıcı ilerleme, dükkân kataloğu, bölüm kaydı ve sıralama
  UKPlayer.cs      V1 (ve V2) hareket denetleyicisi ve kamera
  UKWeapons.cs     5 silah × 3 varyant, alternatif silahlar, kollar, kanca, görünür modeller
  UKProjectile.cs  mermiler, bozuk paralar, şok dalgaları
  UKEnemies.cs     iskelet, Filth, Stray, eğitmen, Schism, Swordsmachine
  UKEnemies2.cs    Malicious Face, Cerberus, Drone, Streetcleaner, Hideous Mass, V2
  UKStyle.cs       stil ölçeri
  UKHud.cs         IMGUI arayüzü (HUD, menü, bölüm seçimi, dükkân, duraklatma, ölüm, sonuç)
  UKMusic.cs       gerçek zamanlı müzik sentezi
  UKFx.cs          malzemeler, kodla dokular, efektler
  UKAudio.cs       DSP ile üretilen ses bankası
  UKInput.cs       eski/yeni girdi sistemi katmanı
  UKHitbox.cs      gövde/kafa isabet bölgeleri
Assets/ULTRAKILL/Editor/    UKMenu.cs ("ULTRAKILL" editör menüsü)
tools/make_unitypackage.py  .meta dosyaları, sahne ve dist/ULTRAKILL.unitypackage üretir
```

## Doğrulama durumu

- Tüm C# dosyaları Unity 2021.3.33 başvuru derlemelerine karşı (.NET Framework 4.8, C# 9) üç yapılandırmada **hatasız ve uyarısız derlendi**: eski Input Manager, yeni Input System (API saplamasıyla) ve editör betiği.
- Bölüm çevirisi web sürümüyle karşılaştırıldı: her bölümde kutu ve düşman sayıları birebir aynı.
- **Unity Editör'de çalıştırılmadı.** Bu ortamda Unity yok; oynanış, görünüm, ses/müzik ve performans gerçek Editör'de denenmedi.
