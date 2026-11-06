# alpbahOS — Kararlar ve açık sorular

Tarih: 21 Eylül 2026. Durum: Kullanıcı cevapları işlendi; uygulamaya hazırlık planı 1.0.

`Kabul` kullanıcının açık tercihidir. `Teknik seçim` kullanıcının devrettiği kararlar kapsamında seçilmiş başlangıç yaklaşımıdır; testten geçmiş anlamına gelmez. `Açık` teknik deney veya ileride gerekli ayrıntıyı belirtir.

## Kullanıcının kesinleştirdiği kararlar

| ID | Durum | Karar | Dayanak |
|---|---|---|---|
| D01 | Kabul | Ürün adı tam olarak `alpbahOS`. | İsim seçimi |
| D02 | Kabul | 64-bit sistem; mevcut hedef x86_64. | Mimari isteği ve mevcut PC bağlamı |
| D03 | Kabul | Ana hedef Windows'tan geçenler için kolay kullanılan genel masaüstü. | Son kullanıcı yanıtı |
| D04 | Kabul | LFS tabanı kaynak koddan derlenecek; hazır açık kaynak masaüstü ve uygulamalar özelleştirilecek. | Son kullanıcı yanıtı |
| D05 | Kabul | Dağ/terminal logosu, koyu lacivert, cyan ve turuncu marka kimliği. | Seçilen logo ve tasarım konuşması |
| D06 | Kabul | Terminalde yazarken soluk görünen komut önerileri ve yazım düzeltme yardımı olacak. | Kali benzeri terminal isteği |
| D07 | Kabul | Paket işlemleri yeni kullanıcı için kolay olacak; apt/pkg benzeri komut deneyimi isteniyor. | Son kullanıcı yanıtı; altyapı seçilmedi |
| D08 | Kabul | Windows'a tanıdık kısayollar hedeflenecek; Alt+Tab ve Win+D açıkça istendi. | Son kullanıcı yanıtı |
| D09 | Kabul | Varsayılan masaüstü ve kilit ekranı Atatürk temalı olacak. | Takip sorusu yanıtı |
| D10 | Kabul | Güçlü cihazlar için liquid glass veya normal cam görünümü olacak. | Son kullanıcı yanıtı; teknik çözüm açık |
| D11 | Kabul (21 Eylül 2026'da revize edildi, bkz. D31) | `alp install`, `alp remove`, `alp update` komut ailesi; grafik mağaza hedefi ayrıca sürüyor. | Takip sorusu yanıtı; motor D31 ile seçildi |
| D12 | Kabul | İlk hedef VM masaüstü ve canlı USB; diske kurucu sonraki aşama. | Takip sorusu yanıtı |
| D13 | Kabul | Fazla RAM tüketimi istenmiyor; eski PC uyumluluğu öncelik. | Cevap 4/12 |
| D14 | Kabul | Paket yöneticisi ve büyük bileşenler hazır açık kaynak olacak. | Cevap 5/20 |
| D15 | Kabul | Günde 1–2 saat kullanıcı çalışma zamanı; deneyim ortalama. | Cevap 6/7 |
| D16 | Kabul | Hyper-V kullanılacak; proje için 300 GB yerel alan. | Cevap 8/9 |
| D17 | Kabul | Ek PC/sunucu yok; rootlu SSH erişimli Mi 9 yardımcı cihaz olarak mevcut. | Cevap 10 |
| D18 | Kabul | Bulut derleme/depolama yok; kaynak belgeleri için istenen özel Git deposu istisna. | Cevap 11/27 birlikte yorumlandı |
| D19 | Kabul | Mevcut mockup düzeni korunacak; premium minimalist solid görünüm. | Cevap 13/14 |
| D20 | Kabul | Varsayılan Türkçe arayüz ve Türkçe Q klavye. | Cevap 15 |
| D21 | Kabul | Tarayıcı, not defteri, PDF ve yaygın temel uygulamalar hazır gelsin; sürücü kapsamı geniş olsun. | Cevap 16 |
| D22 | Kabul — D35 ile daraltıldı (26 Eylül 2026) | Steam çalışsın, Wine hazır gelsin; Word uyumluluğu istendi. D35 gereği Steam istemcisi kapsam dışı; Wine ve Word hedefi yalnız 64-bit sistemde (WoW64) sürer. | Cevap 17; D35 |
| D23 | Kabul | Office hedef ailesi 2016/2019/2021; tam sürüm/kurulum tipi henüz belirtilmedi. | Office takip yanıtı |
| D24 | Kabul | Kullanıcı donanım hedefi, özel uygulama sırası ve iş bölümünü teknik değerlendirmeye bıraktı. | Cevap 12/18/26 |
| D25 | Kabul | Akıcı, hızlı, kişiselleştirilebilir animasyonlar. | Cevap 19 |
| D26 | Kabul | Projede grafik kurucu, internetsiz kurulum ve Windows yanında kurulum da olacak. | Cevap 22; önceki ilk-alfa sınırından sonraki aşama |
| D27 | Kabul | Legacy BIOS ve UEFI desteği. | Cevap 23 |
| D28 | Kabul | İlgili seçenekler Ayarlar üzerinden erişilebilir olacak. | Cevap 24 |
| D29 | Kabul | Claude Code kullanılacak; özel Git deposu ve ajan Markdown dosyaları isteniyor. | Cevap 25/27 |
| D30 | Kabul | Güncelleme modeli tercihi teknik değerlendirmeye bırakıldı. | Cevap 21 |
| D31 | Kabul | Paket motoru pivotu: `alp` (recipe/kaynaktan derleme + Flatpak sarmalayıcı + core `.tar.gz`) kabul edilen motor; pacman/libalpm + Discover/PackageKit alpm yaklaşımı (D11/P05) M02 testi geçmeden, kullanıcının doğrudan talimatıyla terk edildi. Paket motoru sahipliği Codex'ten Claude'a geçti. | Kullanıcı talimatı, 21 Eylül 2026 (\"bu bütün paket manajeri sende olsun\"); ayrıntı: [docs/handoffs/claude/001-alp-hybrid-pkg-proposal.md](handoffs/claude/001-alp-hybrid-pkg-proposal.md) |
| D32 | Kabul | alpbahOS ilk sürümünde 32-bit kullanıcı alanı/multilib desteği olmayacak; saf x86_64/64-bit devam edilecek. M03'ün ELF32/multilib kabul ölçütü bu ürün kararıyla kapsam dışıdır; 32-bit Steam/Wine uyumluluğu vaat edilmez. | Kullanıcı kararı, 22 Eylül 2026 |
| D33 | Teknik seçim | Mevcut doğrulanmış taban LFS 12.4-systemd olarak korunacak ve BLFS de 12.4-systemd ile eşleştirilecek. Ana plandaki 13.1 hedefinden sapma bilinçli sürüm sabitlemesidir: M1 rootfs, kernel/boot imajı ve tekrar kullanılacak mevcut sistem 12.4 ile üretildi; BLFS 13.1 paketlerini bu tabana karıştırmak kitap uyumluluğunu ve tekrarlanabilirliği zedeler. 13.1'e geçiş bu iş kapsamında tam temel sistemi yeniden üretmeyi gerektireceğinden, M2 için çalışan tabanı yeniden kurmak yerine uyumlu 12.4 BLFS seçildi. | Codex'in M2 sürüm uyumluluğu kararı, 22 Eylül 2026; uygulama kanıtı: `docs/M2_BLFS_MANIFEST.md`, M1/M2 kayıtları `docs/WORKLOG.md` |
| D34 | Kullanıcı kararı — M04 kısmi kabul; tam defter M09'a ertelendi | M04'ün kısmi kabul ölçütü: LFS 12.4 sürüm hedefleri doğrulanır; Gen1/BIOS ve Gen2/UEFI boot kanıtı bulunur; `alp` sahipsiz mevcut dosyanın üzerine yazmaz; bu karardan sonra `alp` ile kurulan her paket Alp sahiplik kaydına girer. M04, **“Kısmi kabul, ertelenen borç: tam sahiplik defteri, M09'da kapanacak”** olarak kalır; 79 paketlik tarihsel paket→dosya sahiplik defteri M09'un temiz, tekrarlanabilir imaj üretiminde kanıtlanıp kapatılır. Bu karar mevcut base rootfs'in tüm dosyalarını Alp DB'ye kaydettiği veya 79 geçmiş kurulumun gözlemlendiği anlamına gelmez. | Kullanıcı kararı, 24 Eylül 2026; sürüm matrisi `docs/verification/m04-lfs-12.4-package-coverage-2026-09-24.md`; boot kayıtları `docs/WORKLOG.md`; [Builder rootfs Alp SHA-256 ve test kanıtı](verification/m04-alp-rootfs-installed-code-audit-2026-09-24.log); Alp testleri `docs/handoffs/claude/alp-prototype/tests/test_alp.py` ve `test_base_adoption.py` |
| D35 | Kullanıcı kararı — yalnız 64-bit | D22/D32 çatışması D32 lehine çözüldü: alpbahOS host sistemi yalnız x86_64/64-bit kalır; multilib, lib32, 32-bit glibc ve 32-bit grafik yığını eklenmez. Sonuçları: (1) Valve'ın Linux Steam istemcisi 32-bit kullanıcı alanı istediği için desteklenmez ve vaat edilmez; (2) Wine yalnız 32-bit Unix kütüphanesi gerektirmeyen yeni WoW64 moduyla (Wine 11) kurulur; 32-bit Windows programlarının bu modda çalışması COMPAT-01 testinden önce vaat edilmez; (3) Word/Office testleri bu Wine yolunda yapılır (OFFICE-01); (4) D22'nin Steam kısmı kapsam dışıdır, Wine ve Word kısmı sürer. Kendi 32-bit çalışma zamanını kapsayıcı içinde getiren dağıtımlar (ör. Flatpak Steam) bu kararda değerlendirilmedi; kullanıcı ayrıca istemeden eklenmez. | Kullanıcı kararı, 26 Eylül 2026 ("sadece 64 bit") |
| D36 | Kabul (kullanıcı) | Test ortamı Fedora + QEMU/KVM. Hyper-V yolları planlardan çıkar; eski belgelerdeki Hyper-V notları tarihsel kayıt olarak kalır. | `CLAUDE.md`; `docs/handoffs/claude/021-plan-v1-2026-11-05.md`; kullanıcı onayı (6 Kasım 2026 karar gözden geçirmesi). |

## Teknik seçimler — uygulama/test durumu

| ID | Teknik seçim | Gerekçe / doğrulanması gereken |
|---|---|---|
| P01 | **Kapalı — kullanıcı kararı:** 32-bit desteği ve multilib yok; saf x86_64/64-bit devam. | Kullanıcı açıkça 32-bit/multilib istemedi. D32 ürün kararını, D33 LFS 12.4 + BLFS 12.4 sürüm eşleşmesinin gerekçesini kaydeder. M03 ELF32 ölçütü uygulanmayacak; bu karar kod veya build değişikliği gerektirmiyor. |
| P02 | KDE Plasma / KWin, Wayland öncelikli | X11/Xwayland kapalı build Wine/X11 uygulaması hedefleriyle uyuşmuyor (Steam D35 ile kapsam dışı). Karar açık; P02'nin X11 uyumluluk yolu kullanıcı yanıtı ve build maliyeti değerlendirmesi bekliyor. |
| P03 | Konsole + Zsh + autosuggestions + syntax-highlighting | Öneri kabulü ayrı, çalıştırma ayrı. |
| P04 | Varsayılan alpbah-solid, seçenek Glass ve deneysel Liquid | Üst panel/dock düzeni korunur; RAM bütçesi önce gelir. |
| P05 | **Terk edildi (21 Eylül 2026), bkz. D31/P13.** ~~pacman/libalpm + ince pkg arayüzü + Discover/PackageKit alpm~~ | ~~Tek veritabanı, kendi depo; entegrasyon testi geçmezse gerekçeli alternatif.~~ Kullanıcı M02 testini beklemeden `alp` lehine gerekçeli öncelik değiştirdi. |
| P06 | Hyper-V Gen2 builder; Gen1 BIOS ve Gen2 UEFI test kapsamı | Gen1 test VM kayıtları silindi; Gen1 sonuçları tarihsel kanıttır. Güncel canlı hedef Gen2'dir; ihtiyaç olursa Gen1 testi için yeni VM kaydı ayrıca oluşturulur. Gerçek Builder ayarı 4 vCPU, 3 GiB başlangıç/en az ve 6 GiB en çok RAM. Testler sırayla, 300 GB toplam bütçe. |
| P07 | Stable paket kümesi + yerel testing; kullanıcı başlatmalı güncelleme | Yeni kullanıcı ve sınırlı günlük bakım zamanı. |
| P08 | İlk düşük kaynak hedefi 4 GiB eski x86_64; idle bellek <=1 GiB tasarım hedefi | Ölçülmeden minimum gereksinim diye yayımlanmaz. |
| P09 | Hazır temel KDE uygulamaları, Firefox, LibreOffice, VLC, Wine (yalnız WoW64, D35) | Chrome kurulumu ayrı doğrulama; Office sürümleri ayrı test. Steam D35 ile kapsam dışı. |
| P10 | Calamares kurucu; önce sanal diskler | BIOS/UEFI, offline, dual-boot testleri; gerçek disk yazımı ayrı yetki gerektirir. |
| P11 | Codex altyapı/entegrasyon (LFS/BLFS, kernel, Hyper-V, ISO); Claude masaüstü/tema/terminal UX **+ paket motoru (`alp`, D31 ile 21 Eylül 2026'da eklendi)** | Ayrı branch ve worktree; paylaşılan rootfs tek yazıcı. `alp`'in recipes/index/core içeriği ayrı repoda ([alpbahOS-alp](https://github.com/Yoursel71/alpbahOS-alp)), bu reponun `recipes/`/`packaging/` dosya sınırıyla çakışmaz. |
| P12 | Türkçe Q, tr_TR.UTF-8; Europe/Istanbul değiştirilebilir varsayılan | Dil/klavye kullanıcı tercihi; saat dilimi mevcut bağlamdan seçildi. |
| P13 | `alp` (Python, stdlib-only; recipe, Flatpak sarmalayıcı, core arşivi). Sahip: Claude. | Motor kodu `docs/handoffs/claude/alp-prototype/alp.py` altında `46c58b1` commit'iyle main'e alındı; recipe/index/core içeriği [Yoursel71/alpbahOS-alp](https://github.com/Yoursel71/alpbahOS-alp) deposunda. Devir belgeleri Linux testlerini, Seviye 1/2 bağımlılık kontrollerini ve PackageKit backend taslağını kaydediyor. Rootfs'deki motor güncel değil ve kaynak hash'iyle eşleşmiyor; güvenli rootfs kurulumu/remove/upgrade ve Discover GUI entegrasyonu doğrulanmadı. |

## Açık — kullanıcı kararı gerekiyor

| Konu | Seçenekler ve maliyet | Çakışan hedef / durum |
|---|---|---|
| X11 uygulama uyumluluğu | QtBase XCB, Xwayland ve X11 kullanıcı alanını sonradan eklemek; ek kaynak/build alanı, bağımlılıklar, bakım ve test gerektirir. Alternatif: ilk sürümü yalnız Wayland uygulamalarıyla sınırlamak. | Mevcut QtBase XCB kapalı ve KWin X11 kapalı; P02 uyumluluk yolu ile Wine görsel gereksinimleri henüz karşılanmıyor. |
| KWin kilit ekranı | KScreenLocker'ı ve gereken Qt XCB/X11 greeter bağımlılıklarını geri getirmek; ek bağımlılık, derleme ve oturum testi gerekir. Alternatif: kilit ekranı olmadan devam etmek; D09'u karşılamaz ve oturum kilitlenemez. | `KWIN_BUILD_SCREENLOCKER=OFF`; D09 Atatürk temalı kilit ekranı isteğiyle çelişiyor. Kilit ekranını geri getirme işi BACKLOG'da açık. |
| Mesa renderer | LLVM etkinleştirip llvmpipe kurmak; LLVM toolchain'i derleme süresini, disk kullanımını ve RAM talebini artırır. Alternatif: daha hafif softpipe ile kalmak; animasyon/perf hedefi risk altında kalır. | Mevcut doğrulama softpipe. D25 akıcı animasyon hedefinin performans kanıtı yok. |

D35 gerekçesinin kaynakları: [Wine 11.0 WoW64 duyurusu](https://list.winehq.org/hyperkitty/list/wine-announce%40list.winehq.org/thread/MXULWEMXQ5C24UEJ2STHPIUHNOZ7AZPQ/), [Valve Steam for Linux gereksinimleri](https://github.com/ValveSoftware/steam-for-linux/blob/master/README.md).

## Yanıtlar ve kalan uygulama ayrıntıları

| ID | Soru | Durum |
|---|---|---|
| Q01 | Atatürk görselleri seçilebilir tema mı, varsayılan masaüstü/kilit mi, açılış dahil mi? | Yanıtlandı: varsayılan masaüstü ve kilit; D09 |
| Q02 | Gerçek apt komutları mı, paket komut ailesi mi, mağaza ağırlıklı deneyim mi? | Yanıtlandı: `alp` komut ailesi + mağaza hedefi; D11/D31 |
| Q03 | İlk dağıtılabilir sürüm: canlı USB mi; grafik kurucu da mı; Windows yanında kurulum da mı? | Yanıtlandı: VM + canlı USB; kurucu sonra; D12 |
| Q04 | Hedef tarih, günlük çalışma süresi, gece derleme imkânı? | 1–2 saat/gün; kesin tarih verilmedi, gece çalışması varsayılmaz |
| Q05 | Alan ve derleme ortamı? | Hyper-V, 300 GB; F: SATA HDD olarak tespit edildi |
| Q06 | Claude ortamı? | Claude Code; aynı makine için ayrı worktree hazırlanacak |
| Q07 | Uygulama ve oyunlar? | Steam, Wine, Word, temel araçlar istendi; Steam D35 (yalnız 64-bit) ile kapsam dışı |
| Q08 | Dil/klavye? | Türkçe, Türkçe Q; saat dilimi teknik seçim P12 |
| Q09 | Hedef cihazlar? | Seçim devredildi; eski/orta/RTX test sınıfları oluşturuldu |
| Q10 | Güncelleme/güvenlik? | Stable seçildi; ayarlardan erişim. Secure Boot ve şifreleme sonraki araştırma |
| Q11 | Repo ve bulut? | Private Git; build/paket/ISO yerel, bulut depolama yok |
| Q12 | Yerleşim? | Mevcut mockup aynen korunacak |

Uygulamaya geçişte kanıt gerektirenler: Hyper-V yönetim yetkisi, multilib sürüm eşleşmesi, PackageKit/alpm sürüm uyumu, gerçek GPU desteği ve Office tam sürüm/medya bilgisi. Bunlar kullanıcının cevaplamadığı genel tasarım soruları değil, ilgili teknik görevlerin girdileridir.

## Mevcut durum — salt okunur inceleme

- Proje belgeleri: `C:\alpbahOS`.
- CPU: AMD Ryzen 7 5700, 8 çekirdek / 16 mantıksal işlemci.
- Bellek: yaklaşık 23,9 GiB.
- GPU: NVIDIA GeForce RTX 5060.
- Ölçüm anında C: yaklaşık 57,1 GiB, D: 27,0 GiB, F: 350,3 GiB boş.
- WSL komutu sistemin kurulu olmadığını bildirdi.
- Hyper-V modülü bulundu; mevcut oturumdaki Get-VMHost kontrolü izin hatası verdi. Kurulu/etkin VM altyapısı yönetim yetkili kontrolde doğrulanacak.
- Henüz LFS derlemesi, ISO, kurulu masaüstü veya doğrulanmış Linux sürücüsü yok.
- F: disk bütçesi kabul edildi; sanal disk veya Linux kurulumu henüz başlatılmadı.

## Kaynaklar

- [LFS 12.4 systemd](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/)
- [BLFS 12.4](https://www.linuxfromscratch.org/blfs/view/12.4-systemd/)
- [Plasma derleme bölümü](https://www.linuxfromscratch.org/blfs/view/12.4-systemd/kde/plasma-all.html)
- [Zsh autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [KDE tema ve eklenti altyapısı](https://develop.kde.org/docs/plasma/)

## 5 Kasım 2026 — asistan kararları (kullanıcı "kendin karar ver" dedi)

Bu kararlar asistan tarafından verildi; geri alınabilir teknik seçimlerdir. Dışarıya dönük işler (push/sürüm) kullanıcı onayıyla yapıldı.

| ID | Durum | Karar | Dayanak |
|---|---|---|---|
| D37 | Teknik seçim | Konsole 25.08.3 BLFS planına eklendi (terminal). GPG imzası doğrulandı; sha256 `095a7ff1…6615`. | Proje hedefi "Konsole/Zsh" terminali; kanıt: `docs/verification/m07-m08-qemu-evidence-2026-11-05.md`. |
| D38 | Teknik seçim | Zsh 5.9 eklendi. GPG imzası doğrulandı; sha256 `9b8d1ecedd5b5e81fbf1918e876752a7dd948e05c1a0dba10ab863842d45acd5`. ncurses 6.5 çakışması için yalnız `termcap.c` içinde yerel yeniden adlandırma. | Aynı hedef; kanıt: aynı belge. |
| D39 | Geçici kabul | Sapmalar test/geliştirme imajı için geçici kabul edildi: Sonnet arka uç yok, kwalletd kapalı, About System KCM ve OpenGL yardımcısı kapalı, X11 input KCM'leri kapalı, ffmpeg x86asm'sız. Release öncesi yeniden değerlendirilecek. | `scripts/lfs-blfs/` ve `docs/verification/evidence-2026-11-05/DEVIATIONS.md`. |

## 5 Kasım 2026 — kullanıcı onayı: "herşeyi kabul onay"

| ID | Durum | Karar | Dayanak |
|---|---|---|---|
| D40 | Kabul (kullanıcı) | D39 sapmaları test ve geliştirme imajı için kabul edildi: Sonnet/kwalletd, About System KCM ve OpenGL yardımcısı, X11 input KCM'leri, ffmpeg x86asm'sız. Release öncesi yeniden değerlendirme sürer. | Kullanıcı mesajı, 5 Kasım 2026. |
| D41 | Kabul (kullanıcı) | Kısayollar için kglobalaccel yeniden yükleme ve tek oturum doğrulama onaylandı. | Kullanıcı mesajı, 5 Kasım 2026. |
| D42 | Kabul (kullanıcı) | LFS 12 test tekrarı yalnızca 1 saatten kısa testlerle sınırlı; uzun testler (Python, systemd, util-linux) bu turda yapılmayacak. | Kullanıcı mesajı ("1 saatten uzun süreli testler yapma"). |

## 5 Kasım 2026 — T2 kısayol kök nedeni (asistan kararları)

| ID | Durum | Karar | Dayanak |
|---|---|---|---|
| D43 | Teknik seçim **6 Kasım 2026 güncellemesi (kullanıcı onayı):** üretim yolu `/etc/xdg` değil, `install-desktop-profile.sh` ile `/etc/skel/.config/kglobalshortcutsrc` ve her `--user-home` için `~/.config/kglobalshortcutsrc`; üretim yolu VM'de henüz çalıştırılmadı, canlı doğrulama gerekir. | Kısayol profili test imajına doğrudan kuruldu: `~alpbah/.config/kglobalshortcutsrc` (kglobalacceld kullanıcı dosyasını okur, `/etc/xdg` okumaz). Eski dosya (upstream varsayılanları, çakışmalı) yedeklendi. Üretilmiş dosya `main` üzerinde `--check` ile güncel. Adım 8 `post_blfs_test_config.sh` içine eklendi; kullanıcı dosyası varsa ellenmez. Üretim gereksinimi: `alpbah-oturum-hazirla` KWin'den önce çalışmalı. | `022-t2-kisayol-2026-11-05.md`; kglobalacceld kaynak notu; yedek `scratch-lfs-bench/blfs-plan/t2-backup/`.  |
| D44 | Geçersiz (D49 ile) | ~~Dolphin BLFS planında yok, verifier `KAYITSIZ` döner.~~ Dolphin 25.08.3 D49 ile plana (satır 338) eklendi ve derlendi; Meta+E canlı doğrulaması geçti (VM oturumu 2, commit 8e674a4). `KAYITSIZ` artık kabul edilmiş bir sonuç değildir. | Plan 021 T2 ölçütü; D49; `docs/verification/vm-session-2026-11-05.md`. |

## 5 Kasım 2026 — T3 Zsh (asistan kararları)

| ID | Durum | Karar | Dayanak |
|---|---|---|---|
| D45 | Teknik seçim | LFS zsh 5.9, `configure` önbellek değişkenleri `zsh_cv_sys_sigsuspend`, `killesrch`, `link`, `tcsetpgrp` = yes ile yeniden derlendi. Önceki derlemede chroot içinde komut ikamesi kilitleniyordu. Derleme betiği güncellendi. | `docs/verification/t3-zsh-chroot-2026-11-05.md`; `337.log` configure çıktısı; strace. |
| D46 | Teknik seçim | zsh-autosuggestions v0.7.1 (`e52ee8ca…`) ve zsh-syntax-highlighting 0.8.0 (`db085e46…`) etiket commit'leriyle doğrulanıp `/usr/share/` altına kuruldu; `zshrc.alpbah` `/etc/alpbahos/` içine, `~alpbah/.zshrc` bunu source eder. | Aynı belge. |
| D47 | Geçici durum | §4.3 maddeleri 1, 2, 3, 5 yalnız chroot pty'de doğrulandı. Konsole içinde ve ISO'da doğrulama bekliyor. Madde 4 (`alp` tamamlama) ve 6 (logo) açık. | VM sınırı; `profiles/shell/README.md`. |

## 5 Kasım 2026 — T5 alp (asistan kararları)

| ID | Durum | Karar | Dayanak |
|---|---|---|---|
| D48 | Teknik seçim | `alp` motoru rootfs'e (`/usr/bin/alp`) kuruldu ve chroot içinde `--root /` ile htop kur/çalıştır/kaldır akışı çalıştırıldı. Kaynak sha256, upstream `.sha256` dosyasıyla doğrulandı. QEMU'da tekrar gerekiyor. | `docs/verification/t5-alp-htop-chroot-2026-11-05.md`. |

## 5 Kasım 2026 — Dolphin, T4 yolu ve VM oturumu (asistan kararları)

| ID | Durum | Karar | Dayanak |
|---|---|---|---|
| D49 | Kullanıcı onayı | Dolphin 25.08.3 BLFS planına (row 338) eklendi ve chroot'ta derlendi. Kaynak GPG (KDE anahtarı D81C0CB3…) ve sha256 ile doğrulandı. BalooWidgets ve PackageKit opsiyonel, derlenmedi (metadata özellikleri devre dışı). | Kullanıcı yanıtı: "BLFS'e ekle"; `338-dolphin-25.08.3.sh`. |
| D50 | Kullanıcı onayı | T4: mevcut kırpma/ölçekleme yolu (kaynak kırpılmaz, yalnız ölçeklenir) kabul. Paket rootfs ve imaja kuruldu; varsayılan ayar ve görsel kontrol VM'de yapılmadı. | Kullanıcı yanıtı: "Kırpma/ölçekleme"; `build_wallpaper.py --check` güncel. |
| D51 | Kullanıcı onayı (sapma) | VM: 2 açılış (plan 1). Geçici root şifresi test imajına yazıldı, repoya girmedi. SDDM autologin VM'de başarısız; T2 canlı doğrulama yapılamadı. | `docs/verification/vm-session-2026-11-05.md`. |

## 5 Kasım 2026 — T6 uygulamaları (asistan kararları)

| ID | Durum | Karar | Dayanak |
|---|---|---|---|
| D52 | Kabul (kullanıcı, kalıcı) | poppler 25.08.0 ve exiv2 0.28.9 için upstream sha256/imza yayınlanmamış (exiv2: GitHub etiket arşivi). Hash'ler indirilen dosyadan hesaplanıp `docs/verification/t6-apps-deps-2026-11-05.md` içinde sabitlendi (ilk-kullanımda-güven); sonraki indirmeler bu hash'e karşı doğrulanır. | AGENTS.md "kaynağı doğrulamadan derleme yok" kuralına bilinçli, belgelenmiş istisna; kullanıcı onayı (6 Kasım 2026). |
| D53 | Geçici kabul (kullanıcı) | Gwenview `GWENVIEW_IMAGEANNOTATOR=OFF` ile derlendi: kImageAnnotator-Qt6 (ksnip) derlenmedi, kaynak yamalanmadı; görüntü açıklama özelliği bu sürümde yok. Test imajında kabul; kImageAnnotator eklenmesi sonra değerlendirilir. | `docs/verification/t6-apps-deps-2026-11-05.md`; kullanıcı onayı (6 Kasım 2026). |
| D54 | Teknik seçim (sapma) | Okular PDF ile derlendi; PS/DjVu/ePub/Markdown/TIFF arka uçları isteğe bağlı kapatıldı (`FORCE_NOT_REQUIRED_DEPENDENCIES`). | `docs/verification/t6-apps-deps-2026-11-05.md`. |
| D55 | Açık sorun | `gio open` ile varsayılan uygulama açılışında DBus etkinleştirilen Okular Wayland ortamını almıyor (xcb hatası). Doğrudan başlatma çalışıyor. Çözüm adayı: oturum ortamını DBus'a aktarma. | `docs/verification/vm-session-3-t6-2026-11-05.md`. |

## 5 Kasım 2026 — M11 kurucu zinciri (asistan kararları)

| ID | Durum | Karar | Dayanak |
|---|---|---|---|
| D56 | Sapma (test) | M11 zinciri (yaml-cpp 0.9.0, GNU parted 3.6, kpmcore 25.08.3, Calamares 3.3.14) chroot'ta derlendi ve kuruldu. yaml-cpp, kpmcore ve Calamares için upstream sha256/imza yayınlanmamış (GitHub etiket arşivi sha256'sı kayıtlı). parted imzası geçerli ama anahtarın süresi dolmuş. parted'ta GCC 15 `incompatible-pointer-types` uyarısı kapatıldı. Calamares'te Python yapılandırma doğrulayıcısı atlandı. | `docs/verification/m11-calamares-chain-2026-11-05.md`. |
