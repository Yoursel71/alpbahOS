# M07 / M08 ilk dilim — QEMU kanıtı (5 Kasım 2026)

Ortam: Fedora + QEMU/KVM (D36 test ortamı). Bu belge GitHub `main`'deki Hyper-V Gen2 kanıt yollarının **yerine geçmez**; ortam farkı açıkça kayıtlıdır.

## Kanıtlanan
- **BLFS 12.4 / KDE Plasma 6.4.4 derlemesi:** `blfs.ok` 338 kayıt, çalıştırıcı `DONE`. Eksik dört sıra (017 certifi, 018 urllib3, 020 MIME-Base32 — PyPI ile elle kurulmuştu; 191 noto-sans — kaynak yok).
- **Plasma Wayland oturumu (QEMU, virtio-gpu + virgl, GTK gl=on):** SDDM greeter'dan giriş; logind seat0 oturumu; `kwin_wayland`, `plasmashell`, `ksmserver`, `kded6`, Xwayland ayakta. Ekran görüntüsü: `host_shot1.png`.
- **Kararlılık (kısa):** giriş sonrası ~5 dakika boyunca `kwin_wayland`/`plasmashell` ayakta, yeni core dump yok. Ekran görüntüsü: `host_shot2.png` (kayıt: DEVIATIONS).
- **Konsole 25.08.3:** derlendi (GPG imzası doğrulandı), Plasma Wayland oturumunda açıldı: `host_shot3.png`.
- **Zsh 5.9:** derlendi (GPG imzası doğrulandı; ncurses `boolcodes`/`numcodes` adları için yerel yeniden adlandırma), Konsole içinde `alpbahos%` istemi: `host_shot4.png`.
- **LFS Chapter 8 test tekrarı (M04):** kayıtlı 12 test hatası yeniden çalıştırılıyor (`lfs-test-rerun-summary-snapshot.txt`, anlık görüntü). Bitmedi.

## Kanıtlanmadı / açık
- **M07 kalan maddeler (GitHub main):** Kickoff/Kirigami menüsü, klavye düzeni, ses/PipeWire applet modülleri, KWin render-node uyarısı.
  - *Statik kontrol (rootfs, 5 Kasım):* Kickoff QML plasmoid'i (`/usr/share/plasma/plasmoids/org.kde.plasma.kickoff`), klavye düzeni QML plasmoid'i (`org.kde.plasma.keyboardlayout`), ses applet'i (`/usr/lib/plugins/plasma/applets/org.kde.plasma.volume.so`) ve Kirigami QML modülü kurulu.
  - *Çalışma zamanı:* paneldeki bu öğeler ekranda doğrulanmadı; KWin render-node uyarısı da yalnızca çalışma sırasında görülür ve kontrol edilmedi. Test sınırı nedeniyle yeni VM oturumu açılmadı.
- **Uzun süreli kararlılık:** ~5 dk gözlem. Saatlerce koşu ve yeniden başlatma kanıtı yok.
- **M08 ilk dilim (kısmi, ekranda doğrulandı):** Atatürk duvar kâğıdı masaüstünde görünüyor (`m08_qemu_wallpaper.png`; görsel portre ve düşük çözünürlüklü, 1080p'de bulanıklık riski var). Konsole `alpbahOS` profiliyle açılıyor, başlık `~ : zsh — Konsole`, koyu renk şeması uygulanmış (`m08_qemu_check.png`). Profilde `Command=/bin/zsh` eksikti; eklendi. Windows kısayolları henüz uygulanmadı.
- **M08 kısayollar (canlı doğrulama, 5 Kasım):** `profiles/shortcuts/verify_shortcuts_live.py` bir kez çalıştırıldı (RC=1). Sonuç: 7 geçti, 11 etkin değil, 1 kapsam dışı, 1 kayıtsız. Yani `/etc/xdg/kglobalshortcutsrc` (üretilmiş, 41 satır) kglobalaccel tarafından henüz uygulanmadı; oturum yeniden başlatma veya kglobalaccel yeniden yükleme gerekebilir. Ham çıktı: `evidence-2026-11-05/shortcut-live-verify-2026-11-05.txt`. M08 kısayol maddesi **açık**.
- **M09** (canlı ISO kabulü), **M10** (alfa), **M11** (Calamares kurucu), **M12** (beta, sürüm) açık.
- **Sapmalar** (kabul bekliyor, geçici): Sonnet arka uç yok (`SONNET_NO_BACKENDS`), kwalletd kapalı (libsecret yok), About System KCM ve OpenGL yardımcısı kapalı (Qt Vulkan yok), plasma-desktop X11 input KCM'leri kapalı, ffmpeg x86asm'sız ve bazı codec'ler olmadan, sassc/gdk-pixbuf/NetworkManager yerel yamaları.

## Önemli bulgular (düzeltilen)
- NetworkManager (064) önceden "OK" işaretliydi ama derlenmemişti; `&&` zinciri `set -e`'yi atlatıyordu. Blok sonu hata kontrolü eklendi, paket yeniden derlendi.
- LFS/BLFS sistemde eksik PAM dosyaları (`system-login`, `login`) girişi tamamen engelliyordu; eklendi (`post_blfs_test_config.sh`).
- `kwin_wayland` DRM arka ucunda `initThemeHints()` çöküşü: KDE tema yolu. `QT_QPA_PLATFORMTHEME=generic` ile çözüldü (test imajı).
- `plasmashell` EGL çöküşü (`drisw_init_screen`): virtio-gpu DRM loader uyuşmazlığı. Virgl'li GPU (`virtio-vga-gl`) ile çözüldü.

## Sınırlar
- Tüm testler QEMU test imajında yapıldı; gerçek donanım ve Hyper-V Gen2 yolu bu oturumda kullanılmadı.
- Test şifresi ve test yazı tipleri yalnızca test imajında; release imajına girmemelidir (`post_blfs_test_config.sh` ortam değişkeninden okur).

Ayrıntılı sapma listesi: `DEVIATIONS.md`. Karar kaydı: `DECISIONS-2026-11-05.md` ve `docs/DECISIONS.md` (D37–D39).

## M08 kısayol teşhisi (5 Kasım 2026, ek)
- `org.kde.kglobalaccel` D-Bus adı `kwin_wayland` tarafından tutuluyor (busctl). Ayrı `kglobalacceld` daemon'u bu adı alamadı (`Failed to register name`); yani daemon eksik değil, kısayol sahipliği KWin'de.
- Doğrulayıcı yeniden çalıştırıldı, sonuç aynı: 7 geçti, 11 etkin değil (KWin'in kendi kısayolları dahil: Meta+Up/Down, Meta+Tab). Ayrıca `org.kde.krunner`, `dolphin`, `systemsettings` kısayolları için uygulama dosyaları/bileşenleri bu imajda kayıtsız veya kurulu değil.
- Sonuç: kısayol kaydı KWin tarafında etkin değil. Çözüm için KWin'in kglobalaccel entegrasyonu ve kglobalshortcutsrc okunma yolu ayrıca incelenmeli; bu oturumda kesinleşmedi. M08 kısayol maddesi **açık**.
