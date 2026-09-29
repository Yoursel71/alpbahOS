# Claude devir belgesi 020: M08 gerçek Plasma oturumunda — iki hata bulundu ve düzeltildi

```text
Görev ID / durum: UI-01 + UI-02 (M08). İlk canlı Plasma 6.4.4 testi yapıldı; iki M08 hatası kök nedeniyle bulundu, düzeltildi ve aynı VM'de yeniden doğrulandı. Kalan sorunlar imaj tarafında (aşağıda, Codex).
Çalışılan host ve branch/commit: thewo (Fedora 44, QEMU/KVM) üzerinde Claude'un kendi overlay'leri; dal claude/m08-live-fixes, taban main dda62fb.
Değişen dosyalar: aşağıda.
Gerçekleştirilen davranış: alpbahOS kısayolları artık oturum başında kullanıcı dosyasına işleniyor ve çalışıyor; panel/Kickoff AlpbahDark renklerinde; sistem yazı tipi Inter.
Çalıştırılan doğrulama ve sonuç: tests/test_m08_desktop_profile.py 45/45 (Windows). Gen2 VM'de önce/sonra kara kutu testi (QMP ekran görüntüsü + tuş), üç açılış; salt okunur disk ve konuk günlüğü incelemesi.
Log / ekran görüntüsü / artifact: docs/verification/m08-gen2-2026-09-29/ (m08-gen2-canli-test.log, oncesi.jpg, sonrasi.jpg).
Bilinen sorun ve açık karar: aşağıda "İmaj bulguları" ve "Açık".
Entegrasyon için gereken: rootfs'e profil kurulumu (Codex): install-desktop-profile.sh aynı komutla; yeni hedefler aşağıda.
Sonraki eylem: Codex imaj bulgularını kapatınca GL'li oturumda Meta+Tab (Overview), Spectacle ve sistem izleyicisi kısayolları.
```

## Ortam ve yöntem

Kullanıcı 28 Eylül'de ana makineye SSH erişimi verdi. Codex'in 28 Eylül M08 test imajı (`alpbahOS-m08-font-test.vhdx`) 28 Eylül akşamı `vm-runs` dizini silinirken açık dosya tanıtıcısından kurtarıldı. Bütün denemeler bu kopyanın üstündeki Claude overlay'lerinde yapıldı; Codex'in dosyalarına, `/mnt/lfs`'e ve imajdaki hesaplara dokunulmadı. VM ağsız çalıştı, GL'siz `virtio-vga` kullanıldı (KWin QPainter). GL'li başsız ekranda QEMU ekran görüntüsü alamadı ("no surface"). Doğrulama kara kutu biçimindeydi: QMP ile ekran görüntüsü ve tuş gönderildi, konuk içinde komut çalıştırılmadı. Ardından overlay salt okunur bağlandı ve konuk systemd günlüğü host'ta `journalctl -D` ile okundu.

## Bulunan hatalar

| # | Hata | Kanıt | Kök neden (KDE v6.4.4 kaynağı) | Düzeltme |
|---|---|---|---|---|
| 1 | Upstream varsayılanı olan kısayollar çalışıyor; alpbahOS'un eklediği ya da değiştirdiği her kısayol çalışmıyor (Meta+Up çeyreğe döşedi, Meta+Down döşedi, Meta+Shift+S'deki "s" Dolphin'e yazıldı) | `oncesi.jpg`; kullanıcı `kglobalshortcutsrc`'de upstream değerler | `kglobalacceld` `src/globalshortcutsregistry.cpp:275`: `KConfig::SimpleConfig`; `/etc/xdg/kglobalshortcutsrc` hiç okunmaz. PR #1'deki tasarım varsayımı yanlıştı | Profil `/usr/share/alpbahos/kglobalshortcutsrc` verisi olarak kurulur. `/etc/xdg/plasma-workspace/env/alpbahos-oturum.sh` betiği KWin'den önce `alpbah-oturum-hazirla`'yı çağırır (`startplasma-wayland.cpp:56` → `runEnvironmentScripts`) ve araç profili `~/.config/kglobalshortcutsrc`'ye işler |
| 2 | Panel açık Breeze renginde, renk şeması uygulanmıyor | `kdedefaults/kdeglobals`'ta `ColorScheme` satırı yok; renk grupları yok | `lookandfeelmanager.cpp:430` `colorSchemeFile()`: `alpbah-dark` → `AlpbahDark`, dosya adı `…AlpbahDark.colors` ile bitmeli; bulunamayınca varsayılan da yazılmaz | Şema `AlpbahDark.colors` / `ColorScheme=AlpbahDark`. Mevcut kullanıcılar için araç, alpbahOS paketi etkin ama kdedefaults'ta AlpbahDark yoksa `kdedefaults/package`'ı siler. startplasma varsayılanları yeniden yazar (Defaults kipi panel düzenine dokunmaz) |
| 3 | Yazılar tırnaklı bir yedek fontta | `oncesi.jpg` | kdeglobals'ta font yok, KDE varsayılanı Noto Sans imajda yok | `/etc/xdg/kdeglobals` `tokens.json`'daki fontları verir: Inter, JetBrains Mono (imajda `/usr/share/fonts/alpbahos`). Look-and-feel `defaults` kullanılmadı: 6.4.4 font bayrağını yanlış grupta arıyor (`lookandfeelmanager.cpp:141`) |
| 4 | İlk düzeltme sürümü durum dosyasını yazamadı | `~/.local` root'a ait (aşağıda) | — | Durum ve günlük `~/.config/alpbahos/` altında; yazma hatasında araç çökmez |

`alpbah-oturum-hazirla` kullanıcının ayarını korur:
- Bileşen satırının etkin tuşu varsayılana eşitse profil değeri yazılır.
- Servis satırı yoksa yazılır, varsa kullanıcınındır.
- Aracın yazdığı değer profil değişince güncellenir, ama kullanıcı sonradan değiştirdiyse (KDE varsayılanına dönüş dahil) dokunulmaz.
- Aynı profil bir kez uygulanır; KWin çalışıyorsa kısayol adımı atlanır.

Yeni testler bu kuralların her birini ve betiğin stdout'a hiçbir şey yazmadığını denetliyor (startplasma betik çıktısını ortam olarak okur).

## Sonra: aynı admin durumunun üstüne kurulum (mevcut kullanıcı göçü)

Ayrıntılı tablo ve araç günlükleri `m08-gen2-canli-test.log` dosyasında.
- **Geçti:** panel, dock ve Kickoff koyu; font Inter. Meta, Meta+E, Meta+Up (büyüt/geri yükle), Meta+Down (küçült), Meta+I (Sistem Ayarları) ve Alt+Tab.
- **Meta+R:** kısayol KRunner'ı başlattı, KRunner çöktü. Plasma'nın kendi Alt+F2'si de açamadı, yani sorun bağlamada değil.
- **Sınanamadı:**
  - Meta+Tab: Overview OpenGL ister, oturum QPainter'dı.
  - Meta+Shift+S ve Ctrl+Shift+Esc: Spectacle ve sistem izleyicisi imajda yok.
  - Meta+L: kscreenlocker yok.
- **2. ve 3. açılış:** araç "bu profil zaten uygulanmış; kullanıcı dosyasına dokunulmadı" dedi, kısayollar kalıcı kaldı.
- **Denenmedi:** ilk kez oturum açan yeni kullanıcı. Aynı kod yolu birim testiyle denetlendi (`test_first_login_gets_whole_profile`), ama imajda yeni hesap açılmadı.

## İmaj bulguları (Codex alanı, dokunulmadı)

1. `/home/admin/.local` ve `.local/share` **root:root** (28 Eylül 07:59). İçlerinde yalnız admin'e ait `konsole/` var; büyük olasılıkla Konsole profili root olarak kopyalanırken ara dizinler root'a kaldı. Kullanıcı `~/.local/share`'e yazamaz: Çöp, kactivitymanagerd (Kickoff Favoriler boş göründü), son kullanılanlar. Kopyalayan adım repo betiklerinde bulunamadı (ana makinedeki ağaçta commit'lenmemiş olabilir).
2. `KDEPlasmaPlatformTheme6` eklentisi yok (`/opt/qt6/plugins/platformthemes`: yalnız gtk3 ve xdgdesktopportal). Qt Widgets uygulamaları (Dolphin, Konsole çerçevesi) kdeglobals renklerini almıyor ve açık kalıyor. Kirigami uygulamaları (Sistem Ayarları) ise koyu.
3. Breeze pencere dekorasyonu yok (`Could not locate decoration plugin "org.kde.breeze"`, aurorae de yok). Başlıklar uygulamanın kendi açık çizimi.
4. KRunner `qrc:/krunner/RunCommand.qml` hatasıyla 255 çıkış kodu veriyor.
5. Spectacle ve plasma-systemmonitor kurulu değil. OpenGL yok (`kwin_scene_opengl: couldn't find dev node for drm device`); Overview yalnız GL'li oturumda sınanabilir.

## Değişen dosyalar

- **Yeni:**
  - `profiles/desktop/bin/alpbah-oturum-hazirla`
  - `profiles/desktop/xdg/plasma-workspace/env/alpbahos-oturum.sh`
  - `docs/verification/m08-gen2-2026-09-29/*`
  - bu belge
- **Yeniden adlandırılan:** `profiles/desktop/colorscheme/alpbah-dark.colors` → `AlpbahDark.colors`
- **Değişen:**
  - `profiles/desktop/{install-desktop-profile.sh, xdg/kdeglobals, lookandfeel/.../contents/defaults, README.md}`
  - `profiles/shortcuts/{shortcuts.json, generate_kglobalshortcutsrc.py, generated/kglobalshortcutsrc, help.md, conflicts.md}`
  - `tests/test_m08_desktop_profile.py`
  - `docs/BACKLOG.md`, `docs/WORKLOG.md`, `CURRENT.md` (M08 satırı)

Kurulum hedefleri değişti. Artık `/etc/xdg/kglobalshortcutsrc` kurulmuyor; eski imajlarda kalan kopya zararsız, çünkü okunmuyor. Yeni hedefler:
- `/usr/share/alpbahos/kglobalshortcutsrc`
- `/usr/share/color-schemes/AlpbahDark.colors`
- `/usr/bin/alpbah-oturum-hazirla`
- `/etc/xdg/plasma-workspace/env/alpbahos-oturum.sh`

Komut 019 §4 madde 3'teki ile aynı: `profiles/desktop/install-desktop-profile.sh --destdir <kök> --manifest <dosya>`. Hedef `python3` ister; rootfs'te `python3.13` var.

## Açık

- ~~`.colors` dosyasında `[Colors:Header]` ve `[Colors:Complementary]` yok.~~ İkinci turda eklendi (aşağıda).
- Meta+Tab/Overview, Meta+Shift+S, Ctrl+Shift+Esc ve Meta+L imaj bulguları kapanınca, GL'li bir oturumda.
- "alpbahOS kısayollarına dön": Ayarlar'daki "Varsayılanlar" KDE varsayılanına döner. Profili yeniden uygulatmak için `~/.config/alpbahos/oturum.json` silinip yeniden giriş yapılır (varsayılandaki satırlara profil yeniden yazılır). Kullanıcıya dönük bir düğme gerekip gerekmediği açık (conflicts.md §4.2).

## İkinci tur (aynı gün)

- **Renk şeması:**
  - `[Colors:Header]` eklendi. Değeri lacivert (tasarım belgesi "başlık çubuğu koyu lacivert"), `[WM] activeBackground` ile aynı.
  - `[Colors:Header][Inactive]` ve `[Colors:Complementary]` eklendi.
  - Her set için WCAG AA (4,5:1) testi yazıldı.
  - Kullanıcı `kdeglobals`'ına yazıldıkları salt okunur doğrulandı (startplasma şema karmasının değiştiğini görüp yeniden uyguladı). Sistem Ayarları'nda görünür fark yok; Header'ı kullanan bir yüzey bu imajda görülmedi.
- **Yazı tipi:**
  - `59-alpbahos-fonts.conf` eklendi: `sans-serif` ve `system-ui` → Inter, `monospace` → JetBrains Mono.
  - İmajın fontconfig'iyle (host `fc-pattern`, `FONTCONFIG_SYSROOT`) doğrulandı: Qt'nin varsayılan aldığı boş desen listesi artık "Inter" ile başlıyor, "Noto Sans" isteği Inter'e çözülüyor.
  - Test XML yorumundaki `--`'yi yakaladı; fontconfig dosyayı yok sayardı.
  - **Çözülmedi:** Sistem Ayarları'ndaki küçük açıklama yazıları hâlâ tırnaklı. Qt fontconfig'e bağlı (`libQt6Gui` 40 Fc simgesi), yani kaynak Kirigami'nin KDE platform teması eksikken kullandığı başka bir yol. Kök neden çözülmedi; platform teması eklentisi kurulunca (imaj bulgusu 2) yeniden bakılmalı.
- **Ölçek örnekleri (UI-03):**
  - `branding/ataturk-theme/tools/scale_samples.py` yazıldı. Plasma 6.4.4'ün görüntü seçimi (`packagefinder.cpp` `distance()`), varsayılan "Ölçekle ve kırp" doldurması (`main.xml` FillMode 2) ve fiziksel piksel hedefi (`main.qml` `sourceSize`) koddan birebir alındı.
  - 18 çözünürlük (1024x768–5120x1440) × mantıksal yüksekliği ≥720 kalan %100–200 ölçek faktörleri denetlendi.
  - Bulgu: 32:9 ekranda Plasma 3440x1440'ı seçip kırpıyor; yüz %150 ve üstünde panelin altına giriyor. Pakete 5120x1440 eklendi (136 KB; diğer görüntüler baytça aynı). Şimdi hepsi güvenli alanda.
  - Örnek sayfası: `docs/verification/m08-gen2-2026-09-29/duvar-kagidi-olcek.{jpg,txt}`.
  - QEMU'da farklı çözünürlükte açılış denendi: KWin `virtio-vga xres/yres`'e rağmen 1920x1080 seçti, kayıtlı ekran ayarı kaldırılınca da. Canlı ölçek örneği alınamadı.
- **Açık karar (kullanıcı):** 1536x864, 2560x1600, 2880x1800 ve 3840x2160'ta en yakın görüntü ×1,1–1,5 büyütülüyor. Seçenekler:
  - Olduğu gibi bırakmak.
  - 2560x1600/3840x2160 eklemek: net olur, ama 732x987 kaynak büyütülmediği için portre 4K'da küçük kalır.

## Üçüncü tur: SHELL-01 Konsole profili

- Gen2 ekran görüntüsünden ölçüm: Konsole terminal zemini `alpbah-dark` şemasının `Background` rengi (11,16,20), font eş aralıklı, kabuk `bash-5.3`. Bu kopya Codex'in `/home/admin/.local/share/konsole/` altına koyduğu dosyalardı. `~/.local`'ın root'a kalması (imaj bulgusu 1) büyük olasılıkla bu kopyalama adımından geliyor.
- Profil artık `install-desktop-profile.sh` ile sistem geneline kuruluyor: `/usr/share/konsole/alpbahOS.profile`, `/usr/share/konsole/alpbah-dark.colorscheme` ve `/etc/xdg/konsolerc` (`DefaultProfile=alpbahOS.profile`).
  - Kaynak: konsole v25.08.1 `ProfileManager.cpp` konsolerc'yi katmanlı okur, profil ve şemayı `GenericDataLocation/konsole/` altında arar.
  - **Codex için öneri:** ev dizinine kopyalama adımı kaldırılabilir.
- `ShellProfileTests` eklendi:
  - konsolerc → profil → şema zinciri,
  - şema ve font ↔ `tokens.json` eşleşmesi,
  - zshrc'de `CORRECT` açık, `CORRECT_ALL` kapalı,
  - `^C` bağlanmamış, öneri kabulü çalıştırmaya bağlanmamış,
  - syntax-highlighting bütün `bindkey`'lerden sonra yükleniyor,
  - zsh varsa `zsh -n` (yerelde zsh yok, atlandı).
- **Çalıştırılmadı:**
  - Sistem geneli Konsole kurulumu VM'de denenmedi (ana makineye bu turda bağlanılamadı).
  - Zsh ve eklentileri imajda yok; §4.3 maddeleri terminalde hâlâ test edilmedi.

## Dördüncü tur: PR #5 öz incelemesi (ana makineye erişim yok)

Bu makinede Tailscale kapalıydı, ana makineye bağlanılamadı. PR'daki kod baştan okundu, iki hata bulunup düzeltildi:

1. **Fontconfig dosyası yanlış dizine gidebiliyordu.** 019 §4 madde 3'teki alternatif `--sysconfdir /opt/kf6/etc` ile kurulum yapılırsa `59-alpbahos-fonts.conf` `/opt/kf6/etc/fonts/conf.d`'ye düşüyordu. XDG dosyaları oradan okunur, ama fontconfig yalnız kendi dizinini okur ve dosyayı sessizce yok sayardı. Yeni `--fontconfdir` seçeneği eklendi (varsayılan `/etc/fonts/conf.d`); regresyon testi var.
2. **`alpbah-oturum-hazirla` bir adım düşünce hepsini bırakıyordu.** Renk adımında UTF-8 olmayan bir `kdeglobals` `UnicodeDecodeError` fırlatıyor, araç çöküyor ve kısayol adımı hiç çalışmıyordu. Adımlar artık ayrı yakalanıyor; hata günlüğe yazılıyor, çıkış kodu 1. Test eski kodda bu hatayla kalıyor, yenisinde geçiyor.

İncelenen ama sorun çıkmayan: ilk girişte araç dosyayı `_k_friendly_name` olmadan yazıyor. Uygulama kaydolurken kglobalacceld bileşen adını güncelliyor (`kglobalacceld.cpp:354-356`).

Test: 55 geçti, 1 atlandı (`zsh -n`, yerelde zsh yok).

