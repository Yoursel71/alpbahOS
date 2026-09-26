# Claude devir belgesi 015: M08 ilk dilim — look-and-feel, Atatürk duvar kâğıdı, Windows kısayolları

```text
Görev ID / durum: M08 ilk dilim (UI-01/UI-02/UI-03 uygulaması). Dosyalar kurulabilir durumda ve statik testlerden geçti; Gen2 imajına KURULMADI, gerçek Plasma oturumunda doğrulanmadı.
Çalışılan host ve branch/commit: YRSLF dışında bir Windows 11 makinesi (Hyper-V/Builder/Gen2 erişimi yok), GitHub'dan yeni clone. Dal claude/m08-lookandfeel-shortcuts, taban main 3aead65. Bu belgeyle birlikte commit; PR ile main'e önerilir.
Değişen dosyalar: aşağıda "Değişen dosyalar".
Gerçekleştirilen davranış: aşağıda "Ne yapıldı".
Çalıştırılan doğrulama ve sonuç: aşağıda "Doğrulama". Gen2 kurulum, ekran görüntüsü ve canlı kısayol testi ÇALIŞTIRILMADI.
Log / ekran görüntüsü / artifact: Plasma ekran görüntüsü yok. Üretilen görüntüler repoda (hash'ler aşağıda).
Bilinen sorun ve açık karar: aşağıda.
Entegrasyon için gereken: aşağıda "Gen2 doğrulama adımları" ve "Codex için".
Sonraki eylem: Gen2 test VM'ine stage kurulumu + ekran görüntüsü + verify_shortcuts_live.py.
```

## Ortam sınırı

Bu oturum `docs/NEW_SESSION_HANDOFF.md` içindeki host'ta (YRSLF) değil, Hyper-V, Builder ve Gen2 SSH erişimi olmayan başka bir Windows makinesinde çalıştı. Bu yüzden VM'e, `/mnt/lfs`'e veya F: sürücüsüne dokunulmadı; M08 kabulünün "Gen2 imajında SSH + ekran görüntüsü" kısmı yapılamadı ve yapılmış sayılmamalı. Upstream davranışı, kurulu sistem yerine KDE'nin `v6.4.4` etiketli kaynak dosyalarından okundu.

## Ne yapıldı

**1. Kısayol profili — tek kaynak ve üretici.** `profiles/shortcuts/shortcuts.json` v1 şemasına geçti: her satırın kglobalaccel bileşeni/eylem kimliği, Plasma 6.4.4 upstream varsayılanı ve kaynak dosyası kayıtlı. `generate_kglobalshortcutsrc.py` bu dosyadan `/etc/xdg/kglobalshortcutsrc` üretir (`generated/kglobalshortcutsrc`); profil hatalıysa (bilinmeyen tuş, çift eylem, aynı tuş iki eylemde, gerekçesiz kaldırılan upstream tuşu) yazmaz. Kaynak kodda bulunan gerçek çakışmalar ve kararlar `profiles/shortcuts/conflicts.md` §2'de:
- Meta+Tab upstream'de **pencere geçişine** bağlı → Overview'a taşındı.
- Meta+Up/Down upstream'de **hızlı döşeme üst/alt** → büyüt (aç/kapa) / küçült.
- Meta+R upstream'de **Spectacle bölge kaydı** → KRunner'a eklendi, Spectacle'da Meta+Shift+R kaldı.
- Meta+Shift+S upstream'de **Spectacle'ı açar** → doğrudan bölge yakalamaya taşındı.
- Win+L zaten upstream Meta+L; ama KScreenLocker derlenmediği için çalışmaz (SCREENLOCK-01).

**2. Canlı doğrulayıcı.** `profiles/shortcuts/verify_shortcuts_live.py`: Plasma oturumunda `busctl --user` ile kglobalaccel'den (salt okunur) tüm kayıtları okur; her satırı GEÇTİ / KALDI (tuş yok ya da çakışıyor) / KAYITSIZ (bileşen oturumda yok) olarak raporlar, `--dump` ile ham kaydı kanıt olarak saklar. D-Bus imzaları kglobalaccel `v6.17.0` XML'inden alındı.

**3. Look-and-feel paketi `org.alpbahos.solid.desktop`.** Breeze Dark paketinin 6.4.4 biçimiyle: `alpbah-dark` renk şeması, `breeze-dark` ikonlar, Breeze dekorasyon/imleç, `[Wallpaper] Image=alpbahOS-Ataturk`. Düzen betiği: üst panel (alpbahOS sembollü Kickoff + etkin pencere adı + ortada saat + sistem tepsisi, 34 px, opak) ve alt ortada yüzen dock (Konsole, dosya yöneticisi, tarayıcı, Ayarlar). `/etc/xdg/kdeglobals` paketi varsayılan yapar; `/etc/xdg/kwinrc` Solid profilinde blur/kontrast efektini kapatır.

**4. Atatürk duvar kâğıdı paketi `alpbahOS-Ataturk`.** `branding/ataturk-theme/tools/build_wallpaper.py`, kayıtlı PD-Turkey fotoğraftan (SHA-256 sabit) 5 çözünürlük üretir. Fotoğraf kırpılmaz, büyütülmez, üzerine yazı/imza/söz eklenmez; lacivert tonlanır, kenarları token renkli zemine ve geometrik dağ silüetine yumuşatılır. Yüzün üst panel, dock bölgesi ve sol üst simge bölgesiyle çakışmadığı her boyutta denetlenir. Kilit ekranı aynı varsayılan duvar kâğıdını kullanır (libkworkspace `DefaultWallpaper`); ayrı yapılandırma yazılmadı.

**5. Sembol ikonu.** `branding/icons/build_icons.py` referans logodan kelime işaretini kırpıp `alpbahos` ikonunu (32–256 px, saydam zemin) üretir. Geçici raster; mockup §16–17 vektör kaynak ister.

**6. Kurulum betiği.** `profiles/desktop/install-desktop-profile.sh --destdir <kök>`: hedef kök zorunlu, `/` için `--allow-live-root` şart, farklı içerikli dosyanın üzerine `--force` olmadan yazmaz (önce tüm çakışmaları denetler, yarım kurulum bırakmaz), kurulan 20 dosyayı SHA-256 manifest'ine yazar.

## Değişen dosyalar

- Yeni: `profiles/shortcuts/generate_kglobalshortcutsrc.py`, `profiles/shortcuts/verify_shortcuts_live.py`, `profiles/shortcuts/generated/kglobalshortcutsrc`
- Yeni: `profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/` (metadata.json, contents/defaults, contents/layouts/org.kde.plasma.desktop-layout.js), `profiles/desktop/xdg/kdeglobals`, `profiles/desktop/xdg/kwinrc`, `profiles/desktop/install-desktop-profile.sh`
- Yeni: `branding/ataturk-theme/tools/build_wallpaper.py`, `branding/ataturk-theme/wallpaper/alpbahOS-Ataturk/` (metadata.json, ATTRIBUTION.md, 5 JPEG, screenshot.png), `branding/icons/build_icons.py`, `branding/icons/hicolor/*/apps/alpbahos.png`
- Yeni: `tests/test_m08_desktop_profile.py`, bu belge
- Güncellendi: `.gitattributes` (KDE yapılandırma dosyaları için LF), `profiles/shortcuts/shortcuts.json` (v0 → v1), `profiles/shortcuts/conflicts.md`, `profiles/shortcuts/help.md`, `profiles/desktop/README.md`, `branding/ataturk-theme/README.md`, `docs/WORKLOG.md`, `CURRENT.md` (M08 satırı), `docs/BACKLOG.md` (UI-01/02/03 durumları)

## Doğrulama

Ortam: Windows 11, Python 3.14.4, Pillow 12.2.0, Node v26.7.0, Git Bash. Linux'ta çalıştırılmadı.

| Komut | Sonuç |
|---|---|
| `python -m unittest tests.test_m08_desktop_profile -v` | 19 test, 19 geçti: profil geçerli, üretilmiş dosya güncel, MASTER_PLAN §6 kapsamı tam, çakışma/gerekçesiz kaldırma yakalanıyor, doğrulayıcı uygulanmış profilde GEÇTİ / upstream varsayılanlarında beklenen satırlarda KALDI / eksik bileşende KAYITSIZ veriyor, look-and-feel referansları (renk şeması, duvar kâğıdı Id, ikon) tutarlı, düzen JS sözdizimi `node --check` ile geçti, 5 duvar kâğıdı boyutu ve güvenli alan denetimi geçti, kurulum betiği temp köke kurdu / ikinci koşuda değişiklik yok / çakışmada durdu / `/` ve eksik `--destdir` reddedildi |
| `python profiles/shortcuts/generate_kglobalshortcutsrc.py --check` | güncel |
| `python branding/ataturk-theme/tools/build_wallpaper.py --check`, `python branding/icons/build_icons.py --check` | güncel (aynı Pillow sürümünde bayt bayt aynı; farklı Pillow/libjpeg sürümünde fark çıkabilir) |
| `python docs/handoffs/claude/tools/check_docs.py` | 0 bulgu |
| Tüm test paketi (`python -m unittest discover -s tests`) | 120 test: M08 dışı 2 fail + 2 error, ikisi de bu değişiklikten bağımsız ve bu Windows ortamına özgü: `test_m04_package_install_transaction` Linux'a özgü modülü import edemiyor; `test_m04_lfs_ch8_source_verifier` snapshot SHA-256'sı, sistem `core.autocrlf=true` ile CRLF'e çevrilmiş checkout yüzünden tutmuyor. Builder'da tekrarlanmadı. |

**Çalıştırılmadı:** Gen2'ye kurulum, Plasma'da look-and-feel/duvar kâğıdı/panel görüntüsü, `verify_shortcuts_live.py` canlı koşusu, tuşların elle denenmesi, 100/125/150/200% ölçek görüntüleri, kilit ekranı.

Üretilen dosya SHA-256 değerleri:

```text
1e3ebc304c68ab575aae394d01384be28745ac1f9cfa27b2304f22dbb6aba21a  profiles/shortcuts/generated/kglobalshortcutsrc
520d5035147bab4749031736d5af589dd1aeec720ee3770974471c275d81c88f  profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/defaults
da40804131f927217028a7f408bf3af32ede67f09a5875dd2cd50bbd027ad030  profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
7d427ca03a679c9b9aaa4fcea347bb5d19ed0f7c200fc4dac3decd027072a863  branding/ataturk-theme/wallpaper/alpbahOS-Ataturk/contents/images/1366x768.jpg
163ace88d674338928d751f7c2ed18eaea84f5c7a249682e57ca8d047e23c103  branding/ataturk-theme/wallpaper/alpbahOS-Ataturk/contents/images/1920x1080.jpg
dd9548e0fe4359a31453e04bded4e50f9556fef9592e1690d15ea944ac893b0f  branding/ataturk-theme/wallpaper/alpbahOS-Ataturk/contents/images/1920x1200.jpg
a7a1a38ef69893ab2e5e624fc2071e6e6a33a6816dd634fb72b6cf0ddce58e6b  branding/ataturk-theme/wallpaper/alpbahOS-Ataturk/contents/images/2560x1440.jpg
4068728a81f0b3f9a608dbe64550c403a60054c26d830601f3f05f7df151993d  branding/ataturk-theme/wallpaper/alpbahOS-Ataturk/contents/images/3440x1440.jpg
```

## Gen2 doğrulama adımları (YRSLF host'unda, test VM'de; `/mnt/lfs`'e değil)

Kurallar: test VM'de derleme yok; Builder `/tmp` altında iş bitince temizlik; `/mnt/lfs`'e kurulum entegratörün işi.

1. Dalı al (Builder'daki repo kopyası ya da Windows'taki çalışma ağacı): `git fetch origin && git checkout claude/m08-lookandfeel-shortcuts`.
2. Gerekli dizinleri yalnız Gen2 test VM'ine aktar ve kurulumu orada, çakışma denetimli betikle yap (test imajında `sa` şifresiz sudo):
   `tar -cf - profiles/desktop profiles/shortcuts branding/ataturk-theme/wallpaper branding/icons/hicolor | ssh alp-m2-gen2 'mkdir -p /tmp/m08-src && tar -C /tmp/m08-src -xf -'`
   `ssh alp-m2-gen2 'cd /tmp/m08-src && sudo bash profiles/desktop/install-desktop-profile.sh --destdir / --allow-live-root --manifest /var/tmp/m08.manifest'`
   Betik farklı içerikli `/etc/xdg/kdeglobals` veya `kwinrc` bulursa durur; içeriği inceleyip karar ver, körlemesine `--force` kullanma.
3. Guest'te admin oturumunun `XDG_DATA_DIRS` değerinde `/usr/share` olduğunu kontrol et (Plasma `/opt/kf6` önekli). Yoksa kurulumu `--datadir /opt/kf6/share` ile tekrarla.
4. Mevcut admin kullanıcısı eski düzen ve kısayolları taşıdığı için yeni varsayılanları görmez. Yedekle ve sıfırla (admin olarak): `~/.config/plasma-org.kde.plasma.desktop-appletsrc`, `~/.config/plasmashellrc`, `~/.config/kdedefaults/`, `~/.config/kglobalshortcutsrc` → `~/m08-backup/`. Sonra oturumu yeniden başlat (`sudo systemctl restart getty@tty1`; autostart işareti artık `XDG_RUNTIME_DIR` altında).
5. Ekran görüntüsü (Windows host): `scripts\vm-screenshot.ps1 -VmName alpbahOS-M2-SSH-Gen2 -Out F:\alpbahOS-build\artifacts\m08-lookandfeel-<tarih>.png`. Beklenen: Atatürk duvar kâğıdı, üstte panel, altta dock. Kickoff/ikon eksikleri M07 bağımlılıklarından gelir, ayrı kaydet.
6. Kısayol kaydı: `ssh alp-m2-gen2 'sudo -u admin env XDG_RUNTIME_DIR=/run/user/$(id -u admin) python3 /tmp/m08-src/profiles/shortcuts/verify_shortcuts_live.py --dump /var/tmp/m08-kga.json'`. Beklenen şu anki imajda: KWin/plasmashell/KRunner satırları GEÇTİ; lock-session, file-manager, settings, system-monitor, region-screenshot KAYITSIZ (bileşen yok). Çıktıyı ve dökümü `docs/verification/m08-...` altına kaydet.
7. Temizlik: guest'te `/tmp/m08-src` (manifest `/var/tmp/m08.manifest` kanıt olarak kalabilir).

## Bilinen sorun ve açık karar

1. Kickoff, `kirigami-addons` eksik olduğu için açılmıyor (M07); tek başına Win tuşu ve alpbahOS sembolü bu yüzden şimdilik çalışmaz.
2. Win+L KScreenLocker'a bağlı (SCREENLOCK-01, DECISIONS "KWin kilit ekranı" açık kararı). Kilit ekranı okunabilirlik paneli (branding README §4) yazılmadı.
3. Dolphin, Konsole, System Settings, Spectacle, System Monitor ve tarayıcı imajda yok; dock başlatıcıları ve ilgili kısayollar bunlar derlenene kadar boş/KAYITSIZ kalır.
4. Mevcut kullanıcılar `/etc/xdg` varsayılanlarını kendi `~/.config` dosyaları yüzünden görmez; profil yeni kullanıcı ve canlı ISO kullanıcısı için geçerlidir. Ayarlar'daki "Varsayılanlar" KDE varsayılanına döner (conflicts.md §4.2).
5. Win+Aşağı Windows'taki sıralı "geri yükle → küçült" davranışını taklit etmez (conflicts.md §4.1).
6. Mockup'tan bilinçli farklar: uygulama menüsü dock yerine üst paneldeki sembolde; App Center yok (PKG-02); Solid'de panel opak (profiles/desktop/README.md §5).
7. Duvar kâğıdında portre 4K'da küçük kalır (kaynak 732x987, büyütülmüyor). Kompozisyonun dağıtım lisansı proje lisansıyla birlikte belirlenecek.
8. Sembol ikonu geçici raster; vektör logo kaynağı yok.

## Codex için

- M07/M08 bağımlılıkları: `kirigami-addons`, `breeze-icons`, Türkçe karakterli font paketi, `konsole`, `dolphin`, `systemsettings`, `spectacle`, `plasma-systemmonitor`, tarayıcı; Breeze dekorasyonunun (`org.kde.breeze`) kurulu olduğunun teyidi.
- Gen2 doğrulaması geçtikten sonra `/mnt/lfs`'e kurulum: `install-desktop-profile.sh --destdir /mnt/lfs --manifest <yol>`; manifest D34 sahiplik defteri için saklanmalı. Betik mevcut `/etc/xdg/kdeglobals` veya `kwinrc` farklıysa durur; içerik birleştirme kararı entegratörde.
- M09 ISO: canlı kullanıcı yeni kullanıcı olduğu için varsayılanları doğrudan almalı; bu, ISO kabulünde ayrıca doğrulanmalı.
