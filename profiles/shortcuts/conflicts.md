# Kısayol çakışma listesi — UI-02 / M08

Durum (26 Eylül 2026): **eylem kimlikleri ve upstream varsayılanları KDE Plasma 6.4.4 kaynak kodundan doğrulandı; gerçek Plasma oturumunda hiçbir kısayol test edilmedi.** Tek kaynak [`shortcuts.json`](shortcuts.json); sistem dosyası [`generated/kglobalshortcutsrc`](generated/kglobalshortcutsrc) ondan [`generate_kglobalshortcutsrc.py`](generate_kglobalshortcutsrc.py) ile üretilir. Kaynak plan: [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §6, [docs/HYPERV_PLAN.md](../../docs/HYPERV_PLAN.md).

## 1. Profil içi tutarlılık (otomatik)

Üretici her çalışmada profili doğrular ve hata varsa dosya yazmaz: bilinmeyen tuş adı, aynı eylemin iki kez tanımlanması, aynı tuşun iki eyleme bağlanması, satırın vaat ettiği tuşun bağlamada olmaması ve upstream'den gerekçesiz kaldırılan tuş hatadır. `tests/test_m08_desktop_profile.py` bu kuralları ve MASTER_PLAN §6 tablosunun tamamının profilde olduğunu denetler (Windows'ta 19/19 geçti). Bu, gerçek `kglobalaccel` kaydının yerine geçmez.

## 2. Plasma 6.4.4 upstream varsayılanlarıyla çakışmalar (kaynak koddan)

Kaynaklar `v6.4.4` etiketindeki dosyalardır (GitHub KDE aynası). Dolphin Plasma değil KDE Gear bileşenidir; `v25.08.1` referans alındı ve hedef imajda henüz derlenmedi.

| Kısayol | Upstream 6.4.4 durumu | alpbahOS kararı | Kaynak |
|---|---|---|---|
| Alt+Tab / Alt+Shift+Tab | `Walk Through Windows` = **Meta+Tab, Alt+Tab**; ters yön Meta+Shift+Tab, Alt+Shift+Tab | Alt+Tab korunur; Meta+Tab ve Meta+Shift+Tab pencere geçişinden **çıkarılır** | kwin `src/tabbox/tabbox.cpp` |
| Win+D | `Show Desktop` = Meta+D (aç/kapa) | Değişmez | kwin `src/useractions.cpp` |
| Win+E | Dolphin `_launch` = Meta+E | Değişmez (Dolphin kurulu değil) | dolphin `src/org.kde.dolphin.desktop` |
| Win+L | `ksmserver/Lock Session` = Meta+L, Screensaver; eski Ctrl+Alt+L 6.4.4'te yok | Değişmez; **KScreenLocker derlenmediği için çalışmaz** (SCREENLOCK-01) | kscreenlocker `ksldapp.cpp`, `settings/kscreensaversettings.cpp` |
| Win+R | KRunner = Alt+Space, Alt+F2, Search; **Spectacle `RecordRegion` = Meta+Shift+R, Meta+R** | Meta+R KRunner'a eklenir, Spectacle'dan çıkarılır (Meta+Shift+R kalır) | plasma-workspace `krunner/org.kde.krunner.desktop.cmake`; spectacle `desktop/org.kde.spectacle.desktop.cmake` |
| Win (tek başına) | plasmashell `activate application launcher` = Meta, Alt+F1 | Değişmez. Plasma 6'da tek başına Meta normal global kısayoldur | plasma-workspace `shell/shellcorona.cpp` |
| Win+I | System Settings = Tools | Meta+I eklenir; upstream'de başka Meta+I yok (KWin yalnız Meta+Ctrl+I invert) | systemsettings `app/systemsettings.desktop`; kwin `src/plugins/invert/invert.cpp` |
| Win+Sol / Sağ | `Window Quick Tile Left/Right` = Meta+Left/Right | Değişmez | kwin `src/useractions.cpp` |
| Win+Yukarı | `Window Maximize` = Meta+PgUp; **Meta+Up = `Window Quick Tile Top`** | Meta+Up büyütmeye verilir, üste döşeme kısayolsuz kalır. Büyütme aç/kapa çalışır (büyütülmüşse geri yükler) | kwin `src/useractions.cpp` (`MaximizeOp`) |
| Win+Aşağı | `Window Minimize` = Meta+PgDown; **Meta+Down = `Window Quick Tile Bottom`** | Meta+Down küçültmeye verilir, alta döşeme kısayolsuz kalır | kwin `src/useractions.cpp` |
| Win+Tab | `Overview` = Meta+W; **Meta+Tab pencere geçişinde** | Meta+Tab Overview'a verilir, Meta+W da kalır | kwin `src/plugins/overview/overvieweffect.cpp` |
| Alt+F4 | `Window Close` = Alt+F4 | Değişmez | kwin `src/useractions.cpp` |
| Ctrl+Shift+Esc | System Monitor = Meta+Esc; KWin `Kill Window` = Meta+Ctrl+Esc (farklı tuş) | Ctrl+Shift+Esc eklenir | plasma-systemmonitor `org.kde.plasma-systemmonitor.desktop` |
| Win+Shift+S | Spectacle `_launch` = **Print, Meta+Shift+S** (uygulamayı varsayılan modda açar); bölge yakalama = Meta+Shift+Print | Meta+Shift+S doğrudan `RectangularRegionScreenShot`'a taşınır; Print uygulamayı açmaya devam eder | spectacle `desktop/org.kde.spectacle.desktop.cmake` |
| Ctrl+C/V/X/Z | Sistem kısayolu değil | Uygulama katmanı; terminal istisnası `profiles/shell/README.md` | — |

KWin eklentilerinin tamamı (`src/plugins/*.cpp`, 161 dosya) Meta içeren varsayılanlar için tarandı; profil tuşlarıyla başka çakışma bulunmadı (Meta+W/G, Meta+T, Meta+Ctrl+T, Meta+=/−/0, Meta+F5/F6, Meta+Ctrl+I/U, Meta+Shift+F11/F12, Meta+Shift+Esc, Meta+* profil dışı kalır). Plasma bileşenlerinin tamamı değil yalnız ilgili dosyalar okundu; kurulu sistemdeki gerçek durum `verify_shortcuts_live.py` ile ölçülecek.

### 2.1 Upstream'e göre davranış farkları (bilerek kabul edilen)

- Windows'ta Win+Aşağı büyütülmüş pencereyi önce geri yükler, ikinci basışta küçültür. KWin'de bu sıralı davranış yerleşik değil; bu profilde Win+Aşağı doğrudan küçültür, geri yükleme Win+Yukarı (aç/kapa) iledir.
- Üste/alta hızlı döşeme (Meta+Up/Down) kısayolsuz kalır; System Settings'ten yeniden atanabilir.
- Win+Shift+Tab hiçbir eyleme bağlı değildir (Windows'ta da karşılığı yok).

## 3. VM/Windows host seviyesinde yakalama riski

Proje Hyper-V üzerinde geliştiriliyor; test VM'leri Windows hostta çalışıyor:

- **Hyper-V Basic Session** (`vmconnect.exe`): `Win+L`, `Win+D`, `Win+Tab` gibi kombinasyonların çoğu **host Windows tarafından yakalanır**, VM'e ulaşmaz — `Win+L` host oturumunu kilitler.
- **Enhanced Session Mode** (RDP): daha fazla kombinasyon geçebilir ama garanti değildir; `Win+L` neredeyse her zaman host tarafından yakalanır.
- **Sonuç:** Win kısayollarının *kayıt* doğrulaması (`verify_shortcuts_live.py`, D-Bus üzerinden salt okunur) Hyper-V'den bağımsızdır ve SSH ile yapılabilir. Tuşa basınca eylemin *tetiklendiği* ise VMConnect üzerinden güvenilir sınanamaz; çıplak donanım, VNC/SPICE benzeri Win tuşunu host'a kaptırmayan erişim ya da BETA-01 gerekir. Sonuçlar bu iki düzeyde ayrı kaydedilir (MASTER_PLAN §6).

## 4. Açık kararlar

1. Win+Aşağı: Windows'taki "önce geri yükle, sonra küçült" sırası gerekli mi? Gerekirse küçük bir KWin betiği gerekir (hazır bileşen değil; ayrı onay).
2. Ayarlar'daki "Varsayılanlar" düğmesi upstream KDE varsayılanına döner, alpbahOS profiline değil (varsayılanı eylemi kaydeden uygulama bildirir). alpbahOS profiline dönüş şimdilik kullanıcının `~/.config/kglobalshortcutsrc` içindeki ilgili girdiyi silmesidir; kullanıcıya dönük bir "alpbahOS kısayollarına dön" eylemi gerekip gerekmediği açık (MASTER_PLAN §6 "varsayılana dönebilir").
3. Win+L, SCREENLOCK-01 (KScreenLocker'ın Wayland oturumuna geri getirilmesi) kararına bağlı.

## Sonraki adım

Gen2 Plasma oturumunda (admin, seat0) `verify_shortcuts_live.py --dump` çalıştırılıp çıktısı `docs/verification/` altına kaydedilecek; ardından tuşlar elle denenecek. Adımlar: [docs/handoffs/claude/015-m08-lookandfeel-wallpaper-shortcuts.md](../../docs/handoffs/claude/015-m08-lookandfeel-wallpaper-shortcuts.md).
