# asistan devir belgesi 020: M07/M08 QEMU oturumu, kısayol engeli ve sonraki karar

```text
Görev ID / durum: DESKTOP-01 (asistan tarafındaki çalışma doğrulaması), UI-02 (kısayollar), SHELL-01 (Zsh/Konsole), UI-03 (Atatürk). Durum: KISMİ. M07 çalışma zamanı ve kararlılık açık; M08 kısayollar açık (11/18 etkin değil).
Çalışılan host ve dal: Fedora 44, QEMU/KVM (D36 test ortamı). Commit'ler yoursel/main'e fast-forward ile gitti: 8fed971 (kanıt + betikler), 96999a4 (M08 duvar kâğıdı/Konsole profili), d3a7647 (M07 statik kontrol), 2a0215b (kısayol canlı doğrulama), 124ee5d (kullanıcı kararları D40–D42), 14552d1 (kısayol teşhisi).
Değişen dosyalar: docs/verification/m07-m08-qemu-evidence-2026-11-05.md; docs/verification/evidence-2026-11-05/* (kırpılmış QEMU ekran görüntüleri, DEVIATIONS.md, DECISIONS-2026-11-05.md, shortcut-live-verify çıktısı); profiles/shell/konsole/alpbahOS.profile (Command=/bin/zsh eklendi); docs/DECISIONS.md (D37–D42); AGENT.md (5 Kasım bölümü); scripts/lfs-blfs/ (BLFS derleme betikleri — bkz. sahiplik notu).
Gerçekleştirilen davranış: BLFS 12.4/KDE Plasma 6.4.4 derlemesi DONE (336+ kayıt). Plasma Wayland oturumu QEMU'da (virtio-gpu + virgl, GTK gl=on) açıldı; Atatürk duvar kâğıdı masaüstünde görüldü; Konsole alpbahOS profiliyle ve Zsh (`alpbahos%`) ile açıldı; kwin_wayland ve plasmashell ~5 dk ayakta kaldı, yeni core dump yok.
Çalıştırılan doğrulama ve sonuç:
- verify_shortcuts_live.py (3 çalıştırma, hepsi RC=1): 7 geçti, 11 "etkin değil", 1 kapsam dışı, 1 kayıtsız (Dolphin). KWin'in kendi kısayolları (Meta+Up/Down, Meta+Tab) dahil etkin değil.
- org.kde.kglobalaccel D-Bus adı kwin_wayland tarafından tutuluyor; ayrı kglobalacceld bu adı alamıyor ("Failed to register name"). Kök neden tam kanıtlanmadı.
- M07 Kickoff/klavye/ses: yalnız statik kontrol (dosya var): Kickoff ve klavye QML plasmoid'leri, ses applet'i org.kde.plasma.volume.so, Kirigami QML modülü kurulu. Çalışma zamanı paneli doğrulanmadı.
- LFS Chapter 8 testleri (12 kayıtlı hata): durduruldu. Kullanıcı kararı: 1 saatten uzun testler yapılmaz (D42).
Log / ekran görüntüsü: docs/verification/evidence-2026-11-05/ (host_shot1/3/4 yerine kırpılmış m08_qemu_wallpaper.png, m08_qemu_check.png, shortcut-live-verify-2026-11-05.txt). Ham tam ekran görüntüleri (kişisel masaüstü içeriği) repoya girmedi.
Bilinen sorun ve açık karar: (1) Kısayollar: KWin kglobalaccel sahipliği ve kglobalshortcutsrc okunma yolu incelenmeli; bu bir VM testi gerektirir. (2) M07 çalışma zamanı kontrolleri ve kararlılık (uzun süre) yapılmadı. (3) Atatürk görseli 732x987 portre; 1080p duvar kâğıdı için düşük çözünürlük riski (UI-03 kaynak notu). (4) Sapmalar kullanıcı tarafından kabul edildi (D40); M12 yayın için ayrı onay gerekir.
Entegrasyon için gereken: Codex (LFS/BLFS sahibi) scripts/lfs-blfs/ dizinini ve BLFS sürüm/sapma kayıtlarını incelemeli; bu betikler Codex alanına aittir ve burada yalnız kanıt amaçlı eklendi. Entegratör BACKLOG tablosunda UI-02/SHELL-01/UI-03 durumunu bu belgeye göre güncellemeli.
Sonraki eylem: Kullanıcıdan karar bekleniyor: kısayol kök nedeni için yeni VM oturumu (kglobalaccel/KWin incelemesi) onaylanacak mı? Onay gelmeden yeni VM testi yapılmaz. Diğer seçenek: M07 çalışma zamanı kontrolleri (Kickoff, klavye, ses) tek oturumda.
```

## 1. Oturum sınırı (AGENT_STANDING_RULES §2.7)

Bu oturum bir milestone için planlanan süreyi aştı (M07/M08 birden fazla VM turu). Durum yukarıdaki gibi yazıldı ve kullanıcıdan karar istendi; kapsam daraltıldı: yeni VM testi yalnız onaydan sonra.

## 2. Sahiplik notu

`scripts/lfs-blfs/` (sıra dosyası, paket tablosu, derleme komutları, `run_blfs.sh`, `gen_blfs_chroot.py`, `post_blfs_test_config.sh`, imaj betikleri) LFS/BLFS derlemesidir ve AGENTS.md'ye göre **Codex alanına** aittir. Bu dosyalar asistan tarafından, kanıt amacıyla, yerel çalışma alanından taşındı. Entegratör bunları kendi tarif ağacıyla (`recipes/`) karşılaştırıp ayırmalı ya da kabul etmelidir. Paket depolarındaki tarball, ISO, VHDX ve loglar Git'e eklenmedi.

## 3. Kullanıcı kararları (DECISIONS.md)

- D37 Konsole 25.08.3 eklendi (GPG doğrulandı).
- D38 Zsh 5.9 eklendi (GPG doğrulandı; ncurses adları için yerel yeniden adlandırma).
- D39/D40 sapmalar test ve geliştirme imajı için kabul edildi.
- D41 kglobalaccel yeniden yükleme onaylandı (uygulandı; kök neden çözülmedi).
- D42 LFS testleri 1 saatle sınırlı.
