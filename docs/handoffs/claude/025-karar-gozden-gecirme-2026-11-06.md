# alpbahOS — 6 Kasım 2026 karar gözden geçirmesi (50 soru)

Kullanıcı isteği (6 Kasım 2026): "Repodaki tüm her şeyi değiştireceğim, Codex'i tamamen kaldır, bütün kararları da değiştireceğim; tool ile her şeyi sor, 50 soru."

Bu dosya soruları ve kullanıcının ham cevaplarını tutar. Cevaplar her turdan sonra eklenir; uygulama (Codex temizliği, yeni DECISIONS.md) bu cevaplara dayanır.

## Soru planı

| # | Konu | Eski karar |
|---|---|---|
| 1 | Codex temizliğinin derinliği | — |
| 2 | AGENTS.md ne olacak | Ortak ajan dosyası |
| 3 | Uzak `codex/*` dalları (4 dal, main'e birleşmemiş) | — |
| 4 | Eski Codex klonu `~/alpbahOS/alpbahOS` (commit'lenmemiş 30 Eylül işi) | — |
| 5 | Makinedeki Codex CLI ve `~/.codex` | — |
| 6 | Yeni rol/sahiplik modeli | P11, BACKLOG sahip sütunu |
| 7 | DECISIONS.md biçimi | — |
| 8 | Teslim yolu (dal/PR/push) | Kural 13 |
| 9 | Codex döneminden kalan M04 betik/testleri | — |
| 10 | Windows/Hyper-V'ye ait canlı belge ve PowerShell betikleri | D16 → D36 |
| 11 | `origin` remote (alperenyardim30-hash) ve açık PR #5 | — |
| 12 | Belgelerin dili | Türkçe |
| 13 | Ürün adı | D01 |
| 14 | Hedef kitle | D03 |
| 15 | Marka renkleri/logo | D05 |
| 16 | Atatürk teması | D09 |
| 17 | Masaüstü yerleşimi | D19 |
| 18 | Glass/Liquid görünüm | D10, P04 |
| 19 | Animasyonlar | D25 |
| 20 | Kısayollar | D08 |
| 21 | Terminal/kabuk | D06, P03 |
| 22 | Dil, klavye, saat dilimi | D20, P12 |
| 23 | Bulut kullanımı (CI, ISO dağıtımı) | D18 |
| 24 | Ayarlar erişimi | D28 |
| 25 | Paket motoru | D07, D11, D31, P13 |
| 26 | Paket komut adları | D11 |
| 27 | Grafik mağaza | D11, PKG-02 |
| 28 | Flatpak/Flathub | D31 |
| 29 | Güncelleme modeli | D30, P07 |
| 30 | Hazır uygulamalar | D21, P09 |
| 31 | Varsayılan tarayıcı | P09 |
| 32 | Sürücü kapsamı (NVIDIA) | D21 |
| 33 | 64-bit / Steam | D32, D35 |
| 34 | Wine | D22, D35 |
| 35 | Office/Word hedefi | D22, D23 |
| 36 | X11 uyumluluğu | Açık karar |
| 37 | Kilit ekranı | Açık karar |
| 38 | Mesa renderer | Açık karar |
| 39 | RAM / donanım hedefi | D13, P08 |
| 40 | BIOS + UEFI | D27 |
| 41 | İlk sürüm kapsamı | D12 |
| 42 | Kurucu kapsamı | D26, P10 |
| 43 | Secure Boot / disk şifreleme | Q10 (sonraya) |
| 44 | Proje kod lisansı | Belirlenmedi |
| 45 | Test ortamı | D16, D36 |
| 46 | LFS sürümü | D33 |
| 47 | 79 paket sahiplik defteri | D34 |
| 48 | Sapmalar ve ilk-kullanımda-güven hash'leri | D39, D40, D52, D53, D54, D56 |
| 49 | Test süresi / gece çalışması / günlük süre | D15, D42 |
| 50 | Repo görünürlüğü ve yayın | D18, M12 |

## Ham cevaplar

(Her turdan sonra eklenir.)

### Tur 1
1. Temizlik derinliği: **Canlı belge+kod.** Eski handoff, WORKLOG ve doğrulama logları tarihli geçmiş olarak kalır.
2. AGENTS.md: **CLAUDE.md'ye birleştir**, AGENTS.md silinir.
3. Uzak `codex/*` dalları: **Arşiv etiketi koy, sonra sil.**
4. Eski klon `~/alpbahOS/alpbahOS`: **İncele, işe yarayanı al** (sonra arşivle ve sil).

### Tur 2
5. Codex CLI ve `~/.codex`: **Dokunma, yalnız repo.**
6. Roller: **Claude tek ajan.** Sahiplik tabloları, entegratör ve "iki ajan" kuralları kalkar; kullanıcı karar/onay verir.
7. DECISIONS.md: **Sıfırdan yeni dosya, eskisi `docs/archive/DECISIONS-v1.md`.**
8. Teslim: **Main'e doğrudan** (fast-forward push, PR yok).

### Tur 3
9. Codex dönemi betikleri (scripts/ kökü, tests/test_m04_*): **scripts/legacy/ ve tests/legacy/ altına taşı.**
10. Windows/Hyper-V kalıntıları: **Arşive taşı** (HYPERV_PLAN.md → docs/archive/, PowerShell → scripts/legacy/); canlı belgeler Fedora/QEMU ile yeniden yazılır.
11. `origin` remote ve PR #5: **Dokunma.**
12. Belge dili: **İngilizce** (canlı belgeler İngilizceye çevrilir).

### Tur 4
13. Ürün adı: **alpbahOS kalsın.**
14. Hedef kitle: **"Okul egitum ve windowsdan gecenler"** (Other) → okul/eğitim + Windows'tan geçenler.
15. Marka: **Aynen kalsın** (dağ/terminal logosu, lacivert + cyan + turuncu).
16. Atatürk teması: **Seçilebilir tema.** Varsayılan marka/logo duvar kâğıdı; Atatürk teması Ayarlar'dan seçilir.

### Tur 5
17. Yerleşim: **Windows tipi görev çubuğu** (altta tek panel + Başlat menüsü); üst panel + dock mockup'ı bırakılır.
18. Görünüm: **Solid varsayılan + Glass seçenek; Liquid glass ilk sürümden çıkar.**
19. Animasyon: **Mevcut kalsın** (akıcı, hızlı, kişiselleştirilebilir).
20. Kısayollar: **Windows tipi kalsın.**

### Tur 6
21. Terminal: **"Bilmiyorum anlamiyorum"** (Other) → teknik seçim asistana bırakıldı: zaten derlenmiş ve chroot'ta doğrulanmış **Konsole + Zsh + öneriler + renklendirme kalır.**
22. Dil/klavye/saat: **Mevcut kalsın** (Türkçe, Türkçe Q, Europe/Istanbul).
23. Bulut: **Derleme yerel; yayın ISO'ları GitHub Releases'e yüklenir.** Küçük CI testleri bulutta kalır.
24. Ayarlar: **KDE System Settings + ilk açılışta alpbah Hoş geldin uygulaması.**

### Tur 7
25. Paket motoru: **alp kalsın.**
26. Komutlar: **alp install/remove/update + Türkçe yardım/hata mesajları; `apt install` yazılırsa alp'e yönlendirir.**
27. Mağaza: **Discover + alp.**
28. Flathub: **Varsayılan açık.**

### Tur 8
29. Güncelleme: **Mevcut kalsın** (stable; kullanıcı kendisi başlatır, bildirim yok).
30. Hazır uygulamalar (çoklu): **LibreOffice, VLC, Wine.** KDE Edu okul paketi seçilmedi.
31. Tarayıcı: **Firefox.**
32. NVIDIA: **Açık kaynak sürücüler hazır; NVIDIA kapalı sürücüsü ayrı paket (tek komut/tık).**

### Tur 9
33. 32-bit/Steam: **32-bit ekle (multilib).** D32/D35 "yalnız 64-bit" kararı tersine döner; Steam ve eski Wine hedeflenir. Derleme işi ve disk kullanımı artar.
34. Wine: **Bottles/Flatpak Wine** (sistem Wine'ı yerine).
35. Office: **LibreOffice yeter;** MS Office'i Wine'da çalıştırma hedefi kalkar.
36. X11: **Xwayland ekle.**

### Tur 10
37. Kilit ekranı: **Geri getir** (KScreenLocker).
38. Mesa: **Gerçek GPU sürücüleri + llvmpipe** (LLVM derlenir).
39. RAM: **4 GB kalsın** (boşta ≤1 GB hedefi).
40. BIOS/UEFI: **İkisi de kalsın.**

### Tur 11
41. İlk sürüm: **Canlı USB + kurucu** (ilk sürüm diske kurulumu da içerir).
42. Kurucu: **Hepsi kalsın** (grafik + internetsiz + Windows yanına kurulum).
43. Secure Boot / şifreleme: **"Cok uzun surermi"** (Other, soru) → süre bilgisiyle tur 12'de yeniden soruldu.
44. Lisans: **GPL-3.0.**

### Tur 12
43 (tekrar, süre bilgisiyle). Güvenlik: **Disk şifreleme (LUKS) şimdi, kurucuda seçenek; Secure Boot sonra** (kullanıcı BIOS'tan kapatır).
45. Test ortamı: **QEMU + sürüm öncesi gerçek PC'de USB testi.**
46. LFS sürümü: **Multilib ile birlikte en yeni LFS'e geç** (tek seferlik tam yeniden derleme; sürüm o gün doğrulanıp sabitlenecek).
47. Dosya sahiplik kaydı: **Yeniden derlemede her temel paket alp ile kurulur;** D34 borcu böyle kapanır.

### Tur 13
48. Geçici eksikler ve ilk-kullanımda-güven hash'leri: **Yeniden derlemede kapat** (eksik özellikler açılır, sabitlenen hash'ler yeniden kontrol edilir).
49. Çalışma ritmi: **Uzun derleme serbest** (arka planda saatlerce, gece dahil; sonuç özetlenir). D42 "1 saatten uzun test yok" kalkar.
50. Görünürlük: **İlk alfa ISO hazır olunca depo herkese açılır;** o ana kadar özel. Her yayın kullanıcı onayıyla.

Tüm 50 soru cevaplandı (soru 43 bir kez yeniden soruldu).
