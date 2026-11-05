# Karar kaydı — 2026-11-05 (kullanıcı: "kendin karar ver")

Bu kararlar asistan tarafından verildi. Geri alınabilir teknik seçimlerdir; dışarıya dönük işler kapsam dışıdır.

## 1. Konsole
- Karar: **EKLENECEK** (proje hedefi "Konsole/Zsh" terminali içeriyor; planda yoktu).
- Durum: henüz derlenmedi. Önce kaynak (KDE release tarball + sha256), bağımlılıklar (KF6 çerçeveleri, KPty, kparts vb.) ve `order.txt` satırı eklenecek. Zsh ayrı satır olarak değerlendirilecek.
- Kabul kriteri: `konsole` ikilisi chroot içinde çalışır; Plasma oturumunda açılır.

## 2. Sapmalar — kabul (geçici, kayıtlı)
Aşağıdakiler şu an için KABUL EDİLDİ ve her biri sonradan kapatılacak:
- Sonnet: yazım denetimi arka ucu yok (`SONNET_NO_BACKENDS=ON`). Kapatma: hunspell eklenip Sonnet yeniden derlenecek.
- kwalletd kapalı (`BUILD_KWALLETD=OFF`, libsecret yok). ksecretd ve KWallet kütüphanesi var. Kapatma: libsecret eklenmesi.
- kinfocenter "About System" KCM'si ve OpenGL yardımcısı kapalı (Qt Vulkan yok). Kapatma: Vulkan-Headers/Loader + Qt yeniden derleme.
- plasma-desktop X11 input KCM'leri kapalı (`BUILD_KCM_MOUSE_X11`, `BUILD_KCM_TOUCHPAD_X11`; xorg-libinput yok).
- ffmpeg: nasm/yasm yok → `--disable-x86asm`; planda olmayan codec'ler (aom, ass, fdk-aac, mp3lame, opus, vpx, x264, x265) yok.
- Diğer kayıtlı sapmalar `DEVIATIONS.md` içinde (lm-sensors, PyCairo, lcms2, libva, libei eklemeleri; sassc SASS_LIBSASS_PATH; gdk-pixbuf tests=false; NetworkManager nmtui=false).

Kabul kapsamı: test ve geliştirme imajı için. Release öncesi her madde yeniden değerlendirilecek.

## 3. M12 push / sürüm yayını — YAPILMAYACAK (onay bekliyor)
- Asistan GitHub'a push etmez ve sürüm yayınlamaz. "Kendin karar ver" bu dışarıya dönük adımı onaylamak olarak yorumlanmadı.
- Yerel hazırlık (CHANGELOG/release notu taslağı, sürüm etiketi önerisi) yapılabilir; yayın için açık onay istenecek.

## Kalan iş (karar değil, uygulama)
- Konsole derleme (yukarıdaki kabul kriteri).
- M07–M10 uygulama doğrulaması (Konsole sonrası), uzun süreli kararlılık.
- M09 kabulü, M11 kurucu.
- 12 kayıtlı LFS test hatasının yeniden çalıştırılması.

## Durum güncellemesi (2026-11-05)
- Konsole: EKLENDİ ve derlendi (25.08.3), Plasma Wayland oturumunda açıldı (host_shot3.png). Zsh ayrı karar.
- Sapmalar: yukarıdaki kabul kapsamında; release öncesi yeniden değerlendirme sürüyor.
- M12 push/sürüm: yapılmadı; açık onay bekliyor.
