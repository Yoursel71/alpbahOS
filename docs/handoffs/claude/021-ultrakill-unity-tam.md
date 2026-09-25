# Claude devir belgesi 021: ULTRAKILL Unity sürümü — tam içerik

**Görev ID / durum:** Backlog dışı kullanıcı isteği: "fixle ve aşırı kaliteli yap oyun complete olsun" (Unity 6.6 konsol ekran görüntüsüyle).

- Ekran görüntüsündeki `AshenGate/Scripts/AshenGateGame.cs(53,130): CS0103 'SetWeapon'` hatası bu depodaki bir dosyada değil; kullanıcının projesindeki başka bir oyuna (AshenGate) ait. Dosyaya erişim yoktu. Kullanıcıya: klasör adının sonuna `~` eklemesi ya da dosyayı göndermesi önerildi. Bu hata varken Unity hiçbir betiği çalıştırmaz.
- ULTRAKILL Unity sürümü web sürümünün tamamına genişletildi. Kod derleme denetiminden geçti. **Unity Editör'de çalıştırılmadı.**

**Çalışılan host ve branch:** Claude Code bulut konteyneri (Linux), dal `claude/3d-ultrakill-game-dev-qzqj42`; önceki commit'ler `46a8e7e` (ilk port) ve `20309ba` (Unity 6/URP uyumu, `.unitypackage`).

- Dosya sınırı: `apps/ultrakill-unity/**`, bu belge ve `docs/WORKLOG.md`. Web oyunu, kernel, rootfs, paket manifesti, `alp`, build/mount ve Hyper-V tarafına dokunulmadı.

## Değişen dosyalar

- `apps/ultrakill-unity/Assets/ULTRAKILL/Scripts/`
  - Yeni: `UKLevels.cs` (10 bölüm), `UKProgress.cs` (ilerleme, dükkân, bölüm kaydı), `UKMusic.cs` (müzik), `UKEnemies2.cs` (6 düşman).
  - Baştan yazıldı: `UKGame.cs`, `UKLevel.cs`, `UKHud.cs`, `UKWeapons.cs`, `UKProjectile.cs`, `UKEnemies.cs`, `UKFx.cs`.
  - Güncellendi: `UKAudio.cs` (21 yeni ses + döngüler), `UKStyle.cs` (5 silahın tazeliği, bonus renkleri), `UKPlayer.cs` (V2 karakteri), `UKInput.cs` (`B` tuşu).
- `apps/ultrakill-unity/README.md`, `dist/ULTRAKILL.unitypackage` (yeniden üretildi), yeni `.meta` dosyaları.

## Gerçekleştirilen davranış

- **Bölümler:** `0-1`…`0-5`, `1-1`…`1-4`, Siber Öğütücü. `levels/*.js` dosyaları bir çeviriciyle (dizgi/yorum korumalı) C#'a çevrildi; web koordinatları korunur, `UKLevel` z eksenini çevirir (web −z = Unity +z). Her bölümde kutu ve düşman sayıları web ile eşit.
- **Bölüm kurucusu:** kutular malzeme ve 24 m hücre başına birleştirilmiş ağlar (dünya-UV, büyük kutular ışık seçimi için parçalanır), tek statik gövdede çarpışma. Oyuncuya özel parmaklıklar "Ignore Raycast" katmanında; mermi/nişan ışınları `UKFx.RayMask` ile onları atlar.
  - Ayrıca: kapılar, tetikleyiciler, arenalar (kilit, dalga, boss, sonsuz, önceden doğma), gizli küreler, silah sunakları (dönen silah modeli), dükkân terminali (TextMesh ekran), üs kapağından iniş, çıkış deliği / portal.
  - Görsel: tema (sis, üç renkli ortam, güneş, köşe renkli gökyüzü), 12 ışıklık havuz, sonuç ekranı için ayrı düşüş tüneli.
- **Oyun akışı:** menü → (ilk kez) intro → bölüm; duraklatma, dükkân, ölüm, sonuç.
  - P kasası: checkpoint, dükkân ve bölüm sonunda yatar; ölünce kasaya girmemiş P kaybolur.
  - Sonuç: sıra, meydan okuma ve P ödülü; bir sonraki bölümün kilidi açılır.
  - Siber Öğütücü dalga kaydı; V2 yenilince Knuckleblaster ve oynanabilir V2 (85 can, %12 hız).
- **Savaş kuralları:** web `tryParry` / `meleePunch` / `explode` birebir. Knuckleblaster mermi savuşturamaz; parry yardımı ağır çekimi, parry güdümü, PROJECTILE BOOST, COIN PUNCH, SHOTGUN PARRY.
- **Arayüz:**
  - Menü: bölüm seçimi (kilit, en iyi sıra, açıklama, meydan okuma) ve karakter seçimi.
  - Ayarlar: müzik, parry/para yardımı, test için tüm silahlar, iki adımlı ilerleme sıfırlama.
  - Dükkân: 7 sekme; satın al, KULLAN/ÇIKAR.
  - HUD: 5 silah yuvası, varyant noktaları, silaha özgü şarj göstergesi, kol/kanca, P, gizli küre, boss çubuğu, dükkân uyarısı.
  - Sonuç ekranında SONRAKİ / TEKRAR / ANA MENÜ düğmeleri.
- **Müzik:** `OnAudioFilterRead` ile gerçek zamanlı. Davul örnekleri DSP ile üretilir. Katmanlar: bas, dağıtılmış gitar, koro pad'i, alt bas, ekolu lead ve basit yankı. Müzik menü/sakin/savaş/boss modlarında çalar, stil rütbesine göre katman açar, duraklatmada boğuklaşır.

## Çalıştırılan doğrulama ve sonuç

- Üç yapılandırmada `dotnet build` (Unity 2021.3.33 başvuru derlemeleri, net48, C# 9), hepsi **0 hata, 0 uyarı**:
  - `ENABLE_LEGACY_INPUT_MANAGER`;
  - Input System API saplamasıyla `ENABLE_INPUT_SYSTEM;UK_INPUTSYSTEM`;
  - `UnityEditor` başvurusuyla editör betiği.
- Bölüm çevirisi karşılaştırması: 9 hikâye bölümünde `L.box` ve düşman tanımı sayıları web ile birebir.
- Ses adı denetimi: kullanılan tüm sesler bankada var (eksik `glitch` eklendi).
- `python3 tools/make_unitypackage.py`: 23 varlık.

**Çalıştırılmadı:** Unity Editör'de açma/Play, oynanış, görünüm, ses ve müzik dinleme, performans, URP'de gerçek görüntü, gerçek Input System paketi, oyuncu derlemesi.

## Bilinen sorun ve açık karar

- Kullanıcının projesindeki AshenGate derleme hatası düzelmeden Unity hiçbir betiği çalıştırmaz. Bu dosya bu depoda yok.
- Işık/ortam parlaklığı three.js değerlerinden tahminle çevrildi; gerçek Editör'de ayar gerekebilir.
- Web'deki ASCII menü arka planı ve mobil dokunmatik kontroller Unity sürümünde yok.

## Entegrasyon için gereken

- Yok: ULTRAKILL Unity sürümü alpbahOS imajına bağlı değildir.

## Sonraki eylem

- Kullanıcı Unity'de paketi içe aktarıp `ULTRAKILL.unity` sahnesinde Play'e basmalı ve Console'daki ilk hatayı ya da görüntü sorununu bildirmeli.
