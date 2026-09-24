# alpbahOS — LFS ana geliştirme planı

Sürüm: 1.0 — uygulamaya hazırlık ana planı, 21 Eylül 2026.

Bu belge kullanıcının cevaplarına göre ürün hedeflerini, seçilen başlangıç mimarisini, aşamaları ve tamamlanma ölçütlerini tanımlar. Çalışan bir sistemin raporu değildir. Kullanıcı tercihleri ve teknik seçimler [karar kaydında](DECISIONS.md), işlerin gerçek durumu [iş kaydında](WORKLOG.md) tutulur. Teknik prototip gerektiren seçimler ölçüm kapılarıyla sınırlandırılmıştır.

## 1. Ürün hedefi ve ilk sürüm sınırı

alpbahOS, Windows'tan geçen insanların günlük kullanabileceği, x86_64 mimarisinde, LFS tabanı kaynak koddan üretilen bir Linux masaüstüdür. Masaüstü ve uygulamalar hazır açık kaynak projelerden seçilip özelleştirilir.

Kullanıcının kabul ettiği deneyim:

- Yazarken terminalde soluk komut tahminleri, tamamlama ve yazım düzeltme yardımı.
- `pkg install`, `pkg remove`, `pkg update` etrafında basit komut ailesi ve grafik uygulama mağazası.
- Alt+Tab ve Win+D dahil Windows'a tanıdık kısayollar.
- Varsayılan masaüstü ve kilit ekranında Atatürk teması.
- alpbahOS dağ/terminal logosu ve koyu lacivert, cyan, turuncu marka renkleri.
- Uygun cihazlarda cam ve liquid glass görsel seçenekleri.
- İlk dağıtılabilir sürümde çalışan sanal makine masaüstü ve USB'den denenebilir canlı sistem.
- Diske grafik kurucu sonraki aşamada.
- Düşük RAM tüketimi ve eski x86_64 bilgisayarları kapsayan test matrisi.
- Türkçe arayüz, Türkçe Q klavye; mevcut mockup yerleşimi korunur.
- Premium, minimalist, opak temel profil; kişiselleştirilebilir akıcı animasyonlar.
- Steam ve Wine; Office 2016/2019/2021 ailesi için sürüm bazlı uyumluluk testleri.
- Legacy BIOS ve UEFI; daha sonraki kurucuda internetsiz kurulum ve Windows yanında kurulum.
- Yerel Hyper-V geliştirme, 300 GB depolama bütçesi; bulut derleme/depolama kullanılmaz. C: NVMe çalışma alanı, F: SATA HDD artifact/build-VM alanıdır.
- Günde 1–2 saat kullanıcı katkısı; Claude Code ve Codex için özel Git deposunda ayrı çalışma alanları.

Önceki canlı USB/VM tercihi ilk alfayı tanımlar. Sonraki “hepsi olsun” yanıtı grafik, çevrimdışı ve Windows yanında kurulum özelliklerini genel yol haritasına ekler; ilk alfa ile kurulabilir beta ayrı teslimlerdir.

İlk aşamanın kapsamına kendiliğinden girmeyenler: yeni kernel yazımı, yeni masaüstü compositor'ü, yeni tarayıcı, sıfırdan bağımlılık çözücü, tam Windows uygulama uyumluluğu ve tüm Windows kısayollarının her uygulamada birebir kopyalanması. Windows alışkanlıkları için ölçülebilir bir uyum listesi hazırlanır; uygulama ve güvenlik modeli kaynaklı farklar açıklanır.

## 2. Mevcut durum ve kaynaklar

Mevcut Windows bilgisayarı: Ryzen 7 5700, yaklaşık 24 GiB RAM, RTX 5060. Kullanıcının 23 Eylül 2026 tarihli disk düzeni bilgisine göre C: NVMe SSD, F: SATA HDD'dir. Bu oturumda `Get-Volume` ile C: 117,789,728,768 byte (~109.7 GiB), F: 182,085,091,328 byte (~169.5 GiB) boş okundu; değerler zamanla değişebilir. Kullanıcı 300 GB proje bütçesi ayırdı; fiziksel bölüm oluşturulmadı. F: üzerindeki HDD erişim süresi özellikle çok küçük dosyalı build'leri etkileyebilir; ölçüme göre iş sayısı ayarlanacak.

Hyper-V PowerShell modülü mevcut. Normal yerel PowerShell oturumu VM envanter yetkisine sahip değil; Windows hostun yerel OpenSSH yönetici hesabına public-key erişim sağlandı ve salt okunur `Get-VM` envanteri bu yoldan doğrulanabiliyor. Hyper-V değişiklik komutları yine yalnız görev gerektirip açıkça yetkilendirildiğinde kullanılmalı. Rootlu, SSH erişimli Mi 9 telefonu yardımcı cihaz olarak mevcut; x86_64 ana derleme hostu veya uyumluluk kanıtı olarak kullanılmayacak.

Mevcut dosyalar tasarım belgeleri ve logo varlıklarıdır. Linux host, rootfs, paket deposu, boot eden imaj veya ISO henüz yoktur. Tasarım mockup'ındaki sürümler, eski paket yöneticisi örnekleri, paket sayıları ve CPU/RAM değerleri örnek metindir.

Mevcut build tabanı [LFS 12.4-systemd](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/) ve eşleşen [BLFS 12.4-systemd](https://www.linuxfromscratch.org/blfs/view/12.4-systemd/) olarak D33 ile sabitlendi. Bu, önceki 13.1+multilib taslak tercihinin yerine geçti. D32 saf 64-bit kararı ile D22 Steam hedefi çelişiyor; kullanıcı kararı açık kalır.

## 3. Seçilen başlangıç mimarisi

Kullanıcı teknik seçimleri devrettiği için aşağıdaki başlangıç mimarisi seçildi. Her seçim, belirtilen entegrasyon testinden geçmek zorundadır; başarısız deneyde alternatif ve gerekçesi karar kaydına işlenir.

| Katman | Aday / yaklaşım | Doğrulama |
|---|---|---|
| Temel sistem | LFS 12.4-systemd + eşleşen BLFS 12.4-systemd (D33). D32 saf 64-bit kabulü kayıtlı; D22 Steam isteğiyle çelişki kullanıcı kararında açık. | Mevcut rootfs/build kayıtları; D22/D32 kararı netleşmeden Steam/multilib çıkış koşulu yok |
| Ek sistem bileşenleri | BLFS 12.4-systemd; ağ, TLS sertifikaları, ses, grafik, oturum | Gerçek işlev testleri |
| Masaüstü | KDE Plasma / KWin | İlk sanal masaüstü oturumu ve donanım testi |
| Görüntü protokolü | Wayland öncelikli. X11/Xwayland build tercihi açık kullanıcı kararı; Qt XCB ve Xwayland şu an kapalı. | P02 uyumluluk yolu kullanıcı yanıtı ve build sonrası test bekliyor |
| Terminal | Konsole + etkileşimli Zsh | Öneri, düzeltme, Unicode ve kısayol testleri |
| Paket deneyimi | `alp`: recipe/kaynaktan derleme, Flatpak sarmalayıcı ve alpbahOS core arşivi (D31/P13) | Kod `docs/handoffs/claude/alp-prototype/`; rootfs motoru commit ve SHA-256 ile eşleşmeli |
| Uygulama mağazası | `alp` PackageKit backend taslağı; Discover/GUI entegrasyonu doğrulanmış değil | Ortak veritabanı, işlem kilidi ve paket işlemleri uçtan uca test edilmeden hazır sayılmaz |
| Ses/ağ | PipeWire + WirePlumber; NetworkManager; Bluetooth için BlueZ | Ses, ağ geçişi ve cihaz testleri |
| Kurucu | Sonraki sürümde Calamares özelleştirmesi | Offline, BIOS/UEFI, boş disk ve dual-boot sanal disk senaryoları |
| Marka/tema | alpbahOS görünüm ve varsayılan ayar paketleri | Temiz kullanıcı hesabında görünüm doğrulaması |
| Dağıtım çıktısı | Sanal disk imajı ve canlı ISO | Boot, ağ, oturum, yeniden başlatma |

Plasma, tema ve efekt altyapısı nedeniyle uygun adaydır. BLFS'de [Plasma derleme bölümü](https://www.linuxfromscratch.org/blfs/view/12.4-systemd/kde/plasma-all.html) vardır; bu bölümün bulunması tek başına tüm alpbahOS entegrasyonlarının hazır olduğu anlamına gelmez.

Grafik uygulamalarda önce mevcut dosya yöneticisi, ayarlar, terminal, ağ ve ses bileşenleri kullanılır. GTK/Qt/Flatpak uygulamalarında tema kapsamı ayrı ayrı test edilir; tek tema paketinin tüm arayüzleri aynı şekilde değiştireceği varsayılmaz.

### 3.1 Steam/Wine ve x86_64 kapsam kararı

[Standart LFS x86_64](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/prologue/architecture.html) saf 64-bit sistem üretir. D22 Steam/Wine hedefini ister; D32 ilk sürüm için 32-bit kullanıcı alanı ve multilib'i kapsam dışı bırakır. Bu iki kararın Steam istemcisiyle uyumluluğu `docs/DECISIONS.md` içinde açık kullanıcı kararıdır.

M03'teki 32-bit/multilib ve ELF32 kabul ölçütleri D32 ile kapsam dışıdır; bu kapsam için toolchain derlemesi yapılmaz. Steam/Wine uyumluluğu, D22/D32 kararı netleşmeden vaat edilmez veya tamamlandı işaretlenmez.

### 3.2 Eski PC ve RAM bütçesi

Test hedefleri garanti edilmiş minimumlar değildir; ölçümden sonra yayımlanır:

| Profil | Test makinesi | Ölçülecek hedef |
|---|---|---|
| Düşük kaynak | 2 CPU, 4 GiB RAM, eski x86_64, Solid | Oturum açılışından 2 dk sonra `MemTotal - MemAvailable` <= 1 GiB hedefi; swap thrashing yok |
| Genel masaüstü | 4 CPU, 8 GiB RAM, iGPU | Günlük uygulamalar + Glass; düşük giriş gecikmesi |
| Güçlü cihaz | Mevcut Ryzen/RTX masaüstü | NVIDIA, Steam/Proton ve deneysel Liquid |
| 2 GiB deneysel | 2 CPU, 2 GiB RAM | Masaüstü açılışı incelenir; başlangıç destek garantisi yok |

Tarayıcı, Steam, Wine, dosya indeksleme ve mağaza arka planda otomatik başlatılmaz. Çok uygulamanın kurulu olması hepsinin RAM'de çalışması anlamına gelmez. Gereksiz sürekli servisler kapalı, erişilebilirlik bileşenleri talebe göre etkin olur. Kullanılan RAM/CPU, süreçlerin PSS toplamı ve bellek baskısı aynı yöntemle raporlanır. Solid bütçesi geçmezse önce servis/tema optimizasyonu yapılır; bu yetmezse ayrı hafif masaüstü profili ölçülmüş alternatif olarak ele alınır.

Genel taban için `-march=native` kullanılmaz; x86_64 uyumluluk tabanı korunur. Steam/Chrome gibi uygulamaların ek CPU talimat gereksinimleri ayrı kontrol edilir. Yalnız 32-bit çalışan CPU desteği D32/P01 kapsamında dışıdır; Mi 9 gibi ARM cihazlar ve desteği kesilmiş GPU'lar hedef dışı/ayrı test sınıfıdır; “hepsinde” isteği geniş x86_64 uyumluluk matrisi olarak uygulanır.

## 4. Terminal deneyimi

### 4.1 Kullanıcı davranışı

Kullanıcı yazarken önerilen devam metni imlecin arkasında soluk renkte görünür. Bu görünüm terminalin arka plan saydamlığından bağımsızdır; sade profilde de çalışır.

- Yerel geçmiş ve tamamlama bilgileri öneri kaynağıdır.
- Sağ ok veya End öneriyi komut satırına alır; ayrı Enter komutu çalıştırır.
- Tab komut, dosya ve desteklenen paket adlarını tamamlar.
- Ctrl+R geçmiş aramasına gider; ayrıntılı görünüm seçilen mevcut eklentiye bağlıdır.
- Tanınmayan komut için anlaşılır geri bildirim verilir.
- Yazım düzeltme kullanıcının kabul edeceği öneri olarak sunulur.
- Dosya adı ve tüm argümanları sessizce değiştiren davranış varsayılan yapılmaz.
- İnternet veya AI hesabı olmadan çalışır. Bulut tabanlı tahmin bu gereksinimin parçası değildir.

Teknik adaylar: [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), Zsh tamamlama sistemi ve komut düzeltme seçenekleri. Zsh'nin komut düzeltmesi ile tüm argüman düzeltmesi farklı seçeneklerdir; yapılandırma [resmî seçenek belgesine](https://zsh.sourceforge.io/Doc/Release/Options.html) göre sınanır.

### 4.2 Sistem shell'inden ayrım

Etkileşimli Zsh kullanımı build scriptlerinin yorumlayıcısını veya `/bin/sh` bağlantısını değiştirmez. Build tarifleri Bash/POSIX gereksinimlerini açıkça belirtir; kullanıcı eklentilerinden etkilenmeyen ortamda yürür.

### 4.3 Tamamlanma koşulları

1. Temiz kullanıcıda yazarken öneri görünür; ağ bağlantısı gerekmez.
2. Öneriyi kabul etme komutu çalıştırmaz; Enter gerekir.
3. Hatalı komut düzeltmesi açıklanır ve reddedilebilir.
4. Paket adı tamamlama seçilen paket indeksiyle çalışır; yazarken gereksiz root/ağ işlemi yapılmaz.
5. Terminalde Ctrl+C işlem kesme davranışını korur; kopyalama/yapıştırma görünür şekilde anlatılır.
6. Logo çıktısı gerçek terminalde doğru renklerle çizilir. Mevcut Python/ANSI önizleme varlıkları ayrıca doğrulanır; PNG önizlemesi çalışan terminal kanıtı sayılmaz.

## 5. Paket ve mağaza deneyimi

> **21 Eylül 2026 güncellemesi (D31/P13):** pacman/libalpm + Discover/PackageKit alpm altyapısı terk edildi ve `alp` motoru seçildi; sahipliği Claude'a geçti. Motor kodu bu repodaki `docs/handoffs/claude/alp-prototype/alp.py` ve yardımcı dosyalardadır. Ayrı [alpbahOS-alp tarif deposu](https://github.com/Yoursel71/alpbahOS-alp) tarif/index içeriğini taşır. Rootfs'ye kurulu motor, kaynak commit blob SHA-256'sı ile aynı değilse güncel kabul edilmez. Discover/PackageKit hazır entegrasyon gibi sunulmaz.

### 5.1 Kullanıcıya sunulacak komut ailesi (tarihsel — bkz. yukarıdaki güncelleme)

Aşağıdakiler planlanan arayüzdür; henüz çalışan komutlar değildir. `pkg` adı, D31 pivotundan sonra `alp` ile değiştirildi; tablo eski adla korunuyor.

| Komut (eski ad `pkg`, güncel ad `alp`) | Önerilen anlam |
|---|---|
| `pkg search <ad>` | Paketleri arar; kurulum yapmaz. |
| `pkg info <ad>` | Sürüm, kaynak, boyut, bağımlılık ve açıklamayı gösterir. |
| `pkg install <ad>` | İşlem planını gösterir, yetkilendirmeden sonra kurar. |
| `pkg remove <ad>` | Etkilenen paketleri gösterip kaldırır; kullanıcı belgelerini silmez. |
| `pkg update` | Depo indekslerini yeniler ve mevcut güncellemeleri listeler. |
| `pkg upgrade` | Güncelleme planını gösterip onaylanan paketleri günceller. |
| `pkg list` | Kurulu paketleri ve sürümlerini gösterir. |
| `pkg help` | Kısa, örnekli yardım sunar. |

`update` ile `upgrade` farkı yardımda ve mağazada açık olmalıdır. Kullanıcı bunların farklı anlamda birleşmesini isterse semantik karar kaydı güncellenir.

### 5.2 Altyapı seçimi (tarihsel — bkz. §5 başındaki 21 Eylül 2026 güncellemesi, D31/P13)

LFS belirli bir paket yöneticisi sağlamaz. [LFS 12.4 paket yönetimi bölümü](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/pkgmgt.html) temel yöntemleri açıklar. Sistem dosyaları ilk kurulduğunda sahiplik ve sürüm bilgisi yakalanmalıdır; bu yüzden motor/manifest yaklaşımı nihai LFS sistem kurulumundan önce seçilir.

Güncel paket motoru `alp`'tir (D31/P13). Kaynak motorun commit ve SHA-256 değeri rootfs'deki dosyayla eşleşmelidir. `alp` GUI yolu, veri tabanı, işlem kilidi ve güvenli kurulum/kaldırma testleri tamamlanmadan hazır sayılmaz.

- LFS üzerinde bootstrap ve paket üretim zorluğu.
- Bağımlılık çözümü, dosya sahipliği, yapılandırma korunması, imza ve transaction kilidi.
- Kendi depomuzu üretme ve sürümleme maliyeti.
- Kullanıcıya anlaşılır hata/ilerleme iletme yeteneği.
- Seçilecek hazır mağazayla gerçek entegrasyon yolu.
- Yarım kalan işlem, disk dolması ve eşzamanlı istemcilerde davranış.

`pkg` komutları motorun üzerine ince, testli bir arayüz olur; ikinci bir paket veri tabanı veya sıfırdan bağımlılık çözücü oluşturmaz. Debian/Ubuntu/Arch taban depoları alpbahOS sistem paketlerine doğrudan karıştırılmaz. APT gibi bir araç seçilmesi yabancı dağıtım paketleriyle otomatik uyumluluk sağlamaz.

Tek native paket motoru `alp`'tir; ikinci bir bağımsız sistem paket veritabanı eklenmez. Kolay kullanıcı arayüzü `pkg`/mağaza için tasarlanır, ancak gerçek GUI entegrasyonu ayrıca kanıtlanmalıdır.

İlk depo yerel `file://` kaynağı ve canlı/kurulum medyasındaki paket deposudur. İnternetten kendiliğinden güncellenen genel bir alpbahOS sunucusu varsayılmaz. Kullanıcı bulut depolama istemediğinden ISO/paketler yerelde tutulur; özel GitHub deposu yalnız kaynak/belge eşgüdümü içindir.

Sistem güncellemeleri kütüphane geçişlerini kısmi bırakmamalıdır. `alp update` ve kur/upgrade işlemlerinin güvenli, tutarlı işlem planı üretmesi ayrıca test edilmelidir; AppStream metadata ve paket manifestleri aynı sürüm kümesine bağlanır.

### 5.3 Mağaza sözleşmesi

- CLI ve mağaza aynı motoru, aynı veri tabanını ve aynı işlem kilidini kullanır.
- Root yetkisi tüm mağazaya verilmez; ayrı yetkili işlem mekanizması kullanılır.
- Kurulumdan önce toplam indirme, disk ihtiyacı, kaynak ve etkilenmiş paketler gösterilir.
- Uydurma puan, güvenlik rozeti veya indirme sayısı gösterilmez.
- Birden fazla paket kaynağı varsa kaynak ve kapsam kullanıcıya görünürdür.
- Flatpak gibi ek uygulama kanalları ayrıca seçilir; taban sistemin paket yönetiminin yerine geçmez.
- Discover/PackageKit alpm seçimi D31 ile terk edildi; mevcut mağaza entegrasyonu doğrulanmış değildir.

## 6. Windows'a tanıdık kısayol profili

`Win`, Linux üzerinde genellikle `Meta` adıyla görünen tuştur. Aşağıdaki tablo önerilen alpbahOS profilidir; upstream varsayılanları olduğu iddia edilmez. Alt+Tab ve Win+D kullanıcı tarafından açıkça istenmiştir.

| Tuş | Hedef davranış | Test kapsamı |
|---|---|---|
| Alt+Tab / Alt+Shift+Tab | Pencereler arasında ileri/geri geçiş | Çoklu pencere ve çoklu ekran |
| Win+D | Masaüstünü göster / geri dön | Minimize durumlarının korunması |
| Win+E | Dosya yöneticisi | Tekrarlı çağrı davranışı |
| Win+L | Oturumu kilitle | Kilit ekranından güvenli dönüş |
| Win+R | Komut/uygulama başlatıcı | Arama alanına doğru odak |
| Win | Uygulama menüsü | Diğer Win kombinasyonlarıyla çakışmama |
| Win+I | Ayarlar | Doğru ayarlar uygulaması |
| Win+Sol / Sağ | Pencereyi ekran kenarına yerleştir | Çoklu ekran ve ölçekleme |
| Win+Yukarı / Aşağı | Büyüt / geri yükle / küçült | Tutarlı durum sırası |
| Win+Tab | Pencere/masaüstü genel görünümü | Seçilen masaüstü eylemiyle eşleşme |
| Alt+F4 | Aktif pencereyi kapat | Kaydedilmemiş belge uyarısı |
| Ctrl+Shift+Esc | Sistem izleyicisi | Kısayol çakışması olmaması |
| Win+Shift+S | Bölge ekran görüntüsü | Wayland izin ve seçim akışı |
| Ctrl+C / V / X / Z | GUI uygulamasının kopyala/yapıştır/kes/geri al davranışı | Uygulama bağlamı; terminal istisnası |

Kısayollar tek tanım dosyasından üretilir; ayarlarda düzenlenebilir ve varsayılana dönebilir. VM hostunun yakaladığı Win kısayolları ile misafir sistemin davranışı ayrı kaydedilir. “Tüm Windows kısayolları çalışıyor” ifadesi ancak tanımlı kapsam ve test listesiyle kullanılabilir.

## 7. Marka, Atatürk teması ve cam profilleri

### 7.1 Varsayılan görsel kimlik

Atatürk görselleri masaüstü ve kilit ekranının varsayılanında yer alır. alpbahOS dağ/terminal logosu ürün kimliğini korur. Boot ekranının Atatürk temalı olması henüz istenmiş bir karar değildir.

Tema üretiminde:

- Kaynağı belli Atatürk görseli seçilir; dağıtım için kullanım bilgisi kaydedilir.
- Görsele uydurma imza veya söz eklenmez.
- 16:9, 16:10 ve ultrawide kırpımlarda yüz, logo ve metin güvenli alanda kalır.
- Kilit ekranında şifre alanı ve kullanıcı adı okunaklıdır.
- Masaüstü ikonları için düşük detaylı alan bırakılır.
- Kullanıcı arka planı ve temayı değiştirebilir.

Mevcut [tasarım dokümanı](alpbahOS-design-mockups.md) renk ve bileşen referansıdır. Önceki genel dağ duvar kâğıdı konsepti, yeni varsayılan Atatürk kararına göre revize edilecek; alternatif olarak korunabilir.

Kullanıcı mevcut mockup yerleşiminin tamamını sevdiğini belirtti: üst panel, dock ve pencere düzeni korunur. Windows kısayolları eklemek için düzen zorla Windows görev çubuğuna çevrilmez. Varsayılan ad `alpbah-solid`; arayüz dili `tr_TR.UTF-8`, klavye Türkçe Q, varsayılan saat dilimi mevcut kullanıcı bağlamıyla `Europe/Istanbul` seçildi ve değiştirilebilir.

### 7.2 Görünüm profilleri

| Profil | Görünüm | Hedef |
|---|---|---|
| Solid (varsayılan) | Premium minimalist opak yüzeyler, ölçülü animasyon | VM, eski PC ve genel kullanım |
| Glass | Kontrollü saydamlık, arka plan bulanıklığı, okunaklı yüzeyler | Donanım hızlandırmalı standart masaüstü |
| Liquid | Cam kenarı, ışık ve mümkünse kırılma davranışı | Güçlü cihazlarda ölçülmüş deneysel seçenek |

KWin'in [tema/efekt altyapısı](https://develop.kde.org/docs/plasma/) normal cam yaklaşımının ve özel efekt araştırmasının adayıdır. [KWin efekt belgeleri](https://develop.kde.org/docs/plasma/kwineffect/) özelleştirme altyapısını tarif eder; hazır, sorunsuz bir liquid glass çözümünü garanti etmez.

Liquid için önce küçük bir prototip hazırlanır. Ekran örnekleme/kırılma yöntemi, shader ihtiyacı ve seçilen KWin sürümündeki uygulanabilirlik değerlendirilir. Yalnız blur uygulanmışsa özellik Glass olarak adlandırılır. İlk sürümde normal cam kabul edilebilir; gerçek liquid etkisi prototip sonuçlarına bağlıdır.

### 7.3 Performans ve erişilebilirlik

- Profil yalnız GPU adına bakılarak seçilmez; renderer, sürücü, ekran ölçeği ve gerçek frame süreleri ölçülür.
- Yazılım rendering veya grafik hatasında sade görünüm kullanılabilir.
- 1080p/60 Hz için 16,7 ms kare süresi tasarım hedefidir; hedef donanım ve ölçüm yöntemi belirlenmeden başarı ilan edilmez.
- Efekt açık/kapalı karşılaştırmasında gecikme, GPU/bellek tüketimi ve okunabilirlik kaydedilir.
- Kullanıcı manuel profil seçebilir; azaltılmış hareket ve düşük saydamlık tercihi korunur.
- Metin için kontrast, klavye odağı ve hata durumlarının renkten bağımsız anlatımı kontrol edilir.

## 8. Derleme ortamı ve tekrar üretilebilirlik

Seçilen ortam Hyper-V'dir. Ubuntu 24.04 LTS amd64 Gen2 Builder ile Gen2/UEFI test hedefi kuruldu. Gen1/Legacy boot yolu tarihsel testlerle doğrulandı; kullanılan Gen1 alpbahOS VM kaydı silinmiştir. İleride canlı Gen1 tekrarı gerekirse yeni VM tanımı ve test diski gerekir. [Hyper-V Gen1/Gen2 ayrımı](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/should-i-create-a-generation-1-or-2-virtual-machine-in-hyper-v) iki boot yolunun ayrı testini gerektirir. WSL bu planın ana ortamı değildir.

Linux build ağacı Linux dosya sisteminde tutulur. Windows'taki `C:\alpbahOS` belgeleri ve repo kopyası doğrudan Linux rootfs kurulum hedefi değildir. VM disk dosyası NTFS üzerinde bulunabilir; VM içindeki rootfs yine Linux dosya sisteminde olur.

Builder'ın gerçek ayarı 4 vCPU, 3 GiB başlangıç/en az ve 6 GiB en çok RAM'dir (23 Eylül 2026 gözlemi; eski 6 vCPU/12 GiB planı geçersizdir). Build paralelliği RAM ve ölçüme göre belirlenir. Test VMs: 2 vCPU ve 4 GiB RAM, sırayla çalışır. Ağ için mevcut uygun Hyper-V sanal anahtarı seçilir; Windows ağını bozacak yeni köprü otomatik kurulmaz. Hostta editör/ajanlar için RAM bırakılır. Hyper-V framebuffer ile fiziksel NVIDIA GPU performansı eşit sayılmaz; GPU passthrough ilk kurulumun önkoşulu değildir.

Depolama kökü planı: `F:\alpbahOS-build`. Kullanıcının 300 GB sınırı decimal bütçe olarak ele alınır (yaklaşık 279 GiB). Plan: builder VHDX üst sınırı 210 GB; sırayla kullanılan test diskleri toplam 40 GB; ISO/çıktı 20 GB; checkpoint ve büyüme payı 30 GB. Kaynak cache'i builder alanına dahildir. Checkpoint'ler bu payı aşabilir; gerçek tüketim izlenir ve bütçeyi aşacak işlem durur. Sürekli snapshot biriktirilmez. NTFS üzerinde symlink/izin gerektiren Linux rootfs açılmaz.

Derleme girdileri:

- Kitap sürümü ve erişim tarihi.
- Host araç sürümleri ve LFS host kontrolü sonucu.
- Kaynak URL, checksum, upstream imza bilgisi varsa doğrulaması.
- Yama seti, tarif sürümü, bağımlılıklar ve derleyici seçenekleri.
- Locale, umask, kullanıcı, çalışma dizini ve job sınırı.
- Başlama/bitme zamanı, çıkış kodu, test raporu ve çıktı kimliği.

Tarif değişince bağımlı sonuçlar geçersiz sayılabilir; eski stamp dosyası tek başına devam etmek için yeterli değildir. Kaynak arşivleri ile build/staging/artifact dizinleri ayrı tutulur. Kesilen paket için temiz yeniden derleme yolu bulunur.

Bit düzeyinde yeniden üretilebilirlik ayrı hedef olarak ölçülür. Kaynakları ve tarifleri sabitlemek tek başına byte-for-byte aynı ISO çıktısını garanti etmez.

## 9. Önerilen repo düzeni

Aşağıdaki yeni dizinlerin çoğu henüz oluşturulmadı; görevler geldikçe eklenir.

```text
alpbahOS/
  AGENTS.md
  CLAUDE.md
  docs/
    MASTER_PLAN.md
    DECISIONS.md
    WORKLOG.md
    alpbahOS-design-mockups.md
    assets/
  manifests/           # kaynak, sürüm, checksum, bağımlılık
  recipes/
    bootstrap/
    base/
    desktop/
    applications/
  scripts/
    host-check/
    build/
    image/
    test/
  profiles/
    system/
    shell/
    shortcuts/
    desktop/
  branding/
    logo/
    wallpapers/
    themes/
  packaging/
    backend/
    pkg-cli/
    repository/
  live/
  tests/
  reports/
```

Kaynak cache'i, rootfs, derleme dizinleri, sanal diskler ve büyük ISO'lar Git dışında tutulur. Manifest, tarif, küçük test kanıtı ve yapılandırmalar sürümlenir. Özel anahtar, erişim token'ı veya kullanıcı parolası repoya girmez.

## 10. Aşamalar, bağımlılıklar ve çıkış koşulları

Aşamalar oturum planına bağlanır; gerçek derleme ölçümleri olmadan takvim günü taahhüt edilmez. Günlük kullanıcı zamanı 1–2 saattir.

| Aşama | İş ve çıktı | Önkoşul | Tamamlandı kanıtı |
|---|---|---|---|
| M00 | Gereksinimler, teknik seçimler, özel repo ve görev paylaşımı | Kullanıcı cevapları | Bu plan + ajan dosyaları + repo doğrulaması |
| M01 | Linux host, disk alanı, ağ, LFS araç kontrolü, log düzeni | Ortam ve alan tercihi | Host kontrolü geçer; kontrollü dosya sistemi ve build kökü |
| M02 | Kaynak manifesti, tarif şablonu, paket motoru/mağaza prototipi | M01 | Kısmi: `alp` başlangıç motoru; Windows Python 3.14.7 TTY test koşusunda 82 geçti, 10 POSIX-özelliği testi atlandı. htop install/list/run/remove bir Gen2 test imajında geçti. `update`, gerçek rootfs upgrade/rollback, sistem tabanı sahipliği ve GUI yolu açık. Kanıt: `docs/verification/m02-alp-tests-2026-09-24.md`. |
| M03 | ABI ve geçici araçlar | M01, M02 ABI kararı, sabit kaynaklar | Saf x86_64 kapsamı D32 ile sabit; 32-bit/multilib ve ELF32 ölçütleri kapsam dışı |
| M04 | Chroot ve nihai LFS temel sistemi | M02 kararları, M03 | Kısmi: 26/79 Chapter 8 paketinin stage manifesti var (8,532 kayıtlı yol). Man-pages 6.15 3,029/3,029 exact match; Flex 2.6.4 114 testi geçti, 47/99 eşleşti; Bc 7.0.3 testleri ve smoke geçti, 11/64 eşleşti; Iana-Etc 20250807'de paket dosyaları eşleşiyor, `/etc` dizin uid'si farklı. Önceki 22 manifestin çoğunda mevcut rootfs ile fark var; aşama envanteri tam değil ve bunlar tarihsel sahiplik kanıtı sayılmaz. Grep 3.12 `make check`: 368 PASS/73 SKIP/2 XFAIL/0 FAIL; smoke geçti, 52/147 match. Bash 5.3 LFS Expect `make tests` exited 0 with environment-sensitive output differences; 119/261 match. Libtool 2.5.4 `make check`: 144 expected/32 SKIP, gnulib 4 PASS/2 SKIP; 75/79 match. GDBM 1.26 `make check`: all 38 tests successful; 38/78 matches. Gperf 3.3 `make check` exited 0; 7/12 matches. Expat 2.7.1 `make check`: 2 PASS; `xmlwf` smoke passed; 25/31 matches. Inetutils 2.6 `make check`: 9 PASS/3 SKIP/0 FAIL; `ftp` smoke passed; 16/30 matches. Less 679 `make check`: 17 tests, 0 errors; `less --version` smoke passed; 8/11 matches. Perl 5.42.0 `TEST_JOBS=2 make test_harness`: 2,915 test files/1,350,925 tests PASS; staged thread smoke passed; 2,164/3,181 matches. Official LFS 12.4-systemd Chapter 8 has 79 package entries; exact per-package coverage is [here](verification/m04-lfs-12.4-package-coverage-2026-09-24.md). Expat version follows the pinned LFS 12.4 book; update to the version identified by current LFS advisories before release. Rootfs `/var/lib/alp/db.json` is empty and base-package removal safety is not verified; no mismatching stage was merged. [Değerlendirme](verification/m04-base-ownership-assessment-2026-09-23.md). |
| M05 | Kernel, init, bootloader ve ilk VM açılışı | M04 | BIOS ve UEFI yollarında hedef kernel'den giriş, ağ, yeniden başlatma doğrulandı. 24 Eyl canlı Gen2/UEFI tekrarında `6.16.1-alpbahOS`, PARTUUID+rootwait, online DHCP/DNS, key-only SSH, etkin getty/resolved/sshd, 0 failed unit ve host ping 4/4 görüldü; [WORKLOG kanıtı](WORKLOG.md). |
| M06 | BLFS altyapısı: grafik, ses, oturum, ağ ve sertifikalar | M05 | Kısmi: DNS/TLS, D-Bus user bus, iki yönlü ALSA `snd-aloop`, ayrıca açık `pro-audio` uçlarıyla 48 kHz sanal PipeWire playback→capture roundtrip'i geçti. Fiziksel audio ve grafik test oturumu açık. Kanıt: `docs/verification/m06-gen2-audio-2026-09-24.md` ve `docs/verification/m06-pipewire-proaudio-retest-2026-09-24.log`. |
| M07 | Hazır masaüstü ve temel uygulama profili | M06 | P0 KWin unit/Wayland-only kapısı geçti. Temiz yerel PAM/seat oturumu, gerçek Plasma, ayarlar ve dosya yöneticisi kanıtı bekliyor. Plasma başlatmak için önce tty1 `admin/admin` oturumu `loginctl` ile doğrulanmalı. |
| M08 | Terminal yardımı, pkg+mağaza, kısayollar ve Atatürk/Glass temaları | M02, M07 | İstenen özelliklerin kullanıcı senaryoları geçer |
| M09 | Canlı rootfs, initramfs, canlı ISO ve VM imajı paketleme | M08 | Canlı medyadan açılış ve oturum; kurulumsuz kullanım |
| M10 | Alfa doğrulaması, yayın adayının hazırlanması | M09 | Test matrisi, bilinen sorunlar, checksum ve kullanım yönergesi |
| M11 | Calamares grafik/offline kurucu, BIOS+UEFI ve Windows yanında kurulum | Canlı alfa M10 | Önce sanal disk kurulum/kurtarma testleri; sonra yetkilendirilmiş gerçek disk |
| M12 | Kurulabilir beta, bakım ve sürüm paketi | M11 | Donanım matrisi, güncelleme/kurtarma ve kullanıcı kabul testleri |

Bağımlılık zinciri korunur. Tasarım, terminal yapılandırma taslağı ve kısayol listesi M03 derlemesi sürerken ayrı ortamda geliştirilebilir. İki ajan aynı rootfs'ye eşzamanlı paket kuramaz. Masaüstü prototipinin başka dağıtımda çalışması LFS entegrasyon testinin yerine geçmez.

### 10.1 M03–M05 kritik kontrol noktaları

- Kitapta açıklanan cross-toolchain/temporary tools/chroot sınırları korunur.
- Host kütüphanelerine istenmeyen bağlantılar denetlenir.
- Geçici sistem tamamlandığında geri yüklenebilir kontrol noktası alınır.
- Nihai temel sistemde paket dosya sahipliği kaydı üretildiği doğrulanır.
- Kernel, rootfs sürücüsü, initramfs ihtiyacı ve bootloader yapılandırması birlikte test edilir.
- Boot testi host kernel altında chroot açmayı değil hedef kernel ile yeniden açılışı kapsar.

### 10.2 M09 canlı sistem davranışı

- Salt okunur sistem katmanı ve geçici yazılabilir katman için uygulama yöntemi seçilir; örneğin sıkıştırılmış rootfs + overlay.
- Legacy BIOS ve UEFI ikisi de kabul koşuludur. GRUB'un BIOS/EFI bileşenleri ve aynı ISO'nun iki boot yolu hazırlanır. Secure Boot ayrı imzalama işidir; ilk sürüm koşulu değildir.
- Secure Boot kapalı test edilen imaj destekliyormuş gibi etiketlenmez.
- İlk sürüm grafik kurucu içermez; USB'den deneme ile diske kurulum karıştırılmaz.
- Varsayılan canlı oturumun kimlik/yetki modeli açıkça belgelenir.
- Kalıcı veri bölümü/persistence ayrı seçimdir; var olduğu söylenmez.
- İç Windows disklerine otomatik yazma yapılmaz. Canlı oturumun açılması disk bölümleme tetiklemez.
- Her cihazın kimlikleri/anahtarları gerekiyorsa ilk açılışta oluşturulur; build makinesinin kimlikleri dağıtılmaz.

## 11. Uygulamalar, sürücüler ve Windows uyumluluğu

| İhtiyaç | Başlangıç seçimi | Kabul senaryosu |
|---|---|---|
| Dosyalar | Dolphin | Kopyala, geri al, arşiv aç, USB çıkar |
| Terminal | Konsole + Zsh | Öneri/düzeltme ve pkg tamamlama |
| Not Defteri | KWrite | Türkçe UTF-8 ve Windows satır sonlu dosya |
| PDF | Okular | PDF aç, ara, yazdır |
| Görseller | Gwenview | Yaygın biçimler, döndürme |
| Arşivler | Ark | ZIP/tar açma ve oluşturma |
| Ekran görüntüsü | Spectacle | Bölge/pencere/ekran, kısayol |
| Medya | VLC | Ses/video ve ses çıkışı seçimi |
| Hesap makinesi | KCalc | Günlük işlemler |
| Sistem ve disk | Plasma System Monitor, disk kullanım aracı | Süreç/bellek/disk bilgisi |
| Tarayıcı | Firefox hazır; Chrome için doğrulanmış kurulum seçeneği | İnternet/TLS, indirme, varsayılan ilişki |
| Ofis | LibreOffice Writer/Calc/Impress | DOCX/XLSX/PPTX örnekleri; birebir Word garantisi yok |
| Mağaza | `alp` ile bütünleşecek grafik arayüz | Kendi depomuzdan uygulama işlemi; GUI yolu doğrulanmalı |
| Windows uygulamaları | Wine + ayarlardan prefix/uyumluluk erişimi | 32/64-bit test programı; seçili Office sürümü |
| Oyun | Steam istemcisi ve Proton kullanım yolu | Giriş/indirme ve seçilmiş test oyunu |

“Google” isteği Chrome erişimi olarak yorumlandı; Chrome açık kaynak projesi değildir ve LFS resmî destek listesinde varsayılmaz. [Chrome gereksinimleri](https://support.google.com/chrome/answer/95346?co=GENIE.Platform%3DDesktop&hl=en) ve dağıtım koşulları doğrulanarak resmî kaynaktan kurulabilir; çevrimdışı varsayılan tarayıcı Firefox olur. Chrome'un ISO'ya gömülmesi doğrulanmadan vaat edilmez.

Wine kurulu gelir. Kullanıcı Office 2016/2019/2021 ailesini belirtti; tam sürüm, lisanslı kurulum medyası ve Click-to-Run/MSI ayrımı uyumluluk testi sırasında kaydedilecek. Her sürüm temiz ayrı Wine prefix'inde açma/kaydetme/yazdırma senaryolarıyla denenir. Hiçbiri çalıştırılmadan “Word çalışıyor” denmez. Microsoft Office ISO'ya gömülmez; kullanıcı lisanslı medyasıyla kurar. LibreOffice günlük belge işlerini ilk günden sağlar; Microsoft Word ile aynı uygulama diye sunulmaz.

Steam'in ilk kurulum/hesap ve oyun indirmesi internet gerektirir; offline sistem kurulumu bunu değiştirmez. D22/D32 kararı çözülmeden Steam istemcisi veya 32-bit grafik yığını uyumluluğu vaat edilmez; kapalı anti-cheat kullanan her oyunun çalışacağı iddia edilmez. Özel oyun listesi sonraki test genişletmesidir.

### 11.1 Sürücü matrisi

- Kernel'in Intel/AMD depolama, USB, HID, Ethernet, ses ve grafik modülleri + gerekli firmware sınıfları.
- Intel/AMD grafik için Mesa; NVIDIA için donanım ve kernel ile uyumlu vendor sürücü dalı, fallback ve kullanıcı alanı araçları.
- RTX 5060 gerçek donanım testi; Hyper-V sonucu bu testin yerine geçmez.
- Yaygın Wi-Fi/Bluetooth firmware, yazıcı için CUPS ve ihtiyaç varsa tarama entegrasyonu.
- `hv_vmbus`, depolama/ağ ve uygun Hyper-V framebuffer desteği; Gen1/Gen2 için gerekli boot sürücüleri.
- Eski GPU'larda vendor legacy sürücü ile yeni kernel çatışmaları ayrı uyumluluk satırlarıdır; bütün sürücü dalları aynı anda kurulmaz.

Sürücü seçimi, mevcut sürüm ve güncelleme durumu Ayarlar'dan erişilir. Başlangıçta mevcut sistem bileşenlerine bağlantı veren ince bir karşılama/ayar kısayolu tercih edilir. “Tüm sürücüler” donanım algılama + yaygın sürücü/firmware kapsamı + eksik cihaz raporu olarak uygulanır; her cihaz için evrensel destek garantisi değildir.

## 12. Güncelleme, bakım ve yayın

Seçim: sabitlenmiş stable paket kümesi + yerel testing kanalı. Sürekli rolling yerine test edilmiş sürümler ve güvenlik güncellemeleri. Otomatik arka plan kurulum yok; Ayarlar/mağazadan güncelleme bildirimi ve kullanıcı başlatmalı işlem. Geri dönüş için önce eski kernel ve kurtarma USB'si; atomik sistem güncellemesi sonraki araştırma konusu.

- Sistem paketi ve yapılandırma sürümleri birlikte izlenir.
- Paylaşılan kütüphane değişince etkilenen bağımlı paketler yeniden değerlendirilir.
- Paket kaldırma kullanıcı ayarlarını/belgelerini gelişigüzel silmez.
- Eski kernel veya kurtarma ortamı gibi geri dönüş yolları değerlendirilir.
- Snapshot/atomik geri dönüş vaat edilmeden önce dosya sistemi ve güncelleme mimarisi seçilir.
- ISO ve depo yayınında doğrulanabilir checksum/imza, kaynak manifesti ve bilinen sorunlar sağlanır.
- Dağıtılan yazılımlar ve görseller için kaynak/lisans kayıtları tutulur; seçilen lisansların gerektirdiği kaynak teslimi yayın kontrolüne dahil edilir.
- Bulut paket/ISO depolama ve ücretli sunucu yok. Kod/belgeler özel GitHub deposunda, build/ISO/paketler yerelde. Dış kullanıcılara güncelleme sunucusu kurmak gelecekte ayrı kapsam olur.

Gizlilik/sürücü/uyumluluk seçenekleri Ayarlar'dan erişilebilir. Telemetri ve bulut hesap zorunluluğu varsayılan kapalıdır; bu proje tercihi üçüncü taraf uygulamalarının kendi veri işleyişini değiştirmez. Şifreleme kurucu fazında seçenek olarak incelenir; Secure Boot kapalı test, Secure Boot desteği sayılmaz.

## 13. Kullanıcı senaryoları ve test matrisi

| Alan | Senaryo | Başarı kanıtı |
|---|---|---|
| Boot | ISO'dan başla, masaüstüne gir, yeniden başlat | Boot logu, oturum görüntüsü, kernel bilgisi |
| Ağ | Bağlan, HTTPS sayfası aç, bağlantıyı kes/geri getir | DNS/TLS ve masaüstü ağ durumu |
| Paket | CLI'den kur, mağazada gör, mağazadan kaldır | Aynı paket veri tabanı, log, dosya sahipliği |
| Paket hatası | Ağ kesintisi, disk dolması, ikinci işlem isteği | Anlaşılır hata ve kurtarılabilir işlem durumu |
| Terminal | Öneri göster, kabul et, ayrı çalıştır, düzeltmeyi reddet | Tekrarlanabilir etkileşim kaydı |
| Kısayol | Listedeki her tuş ve çakışma | Profil tablosunda tek tek geçti/kaldı |
| Görsel | Atatürk masaüstü/kilit; marka/kontrast; farklı ölçekler | 100/125/150/200% örnekleri ve bulgu listesi |
| Efekt | Sade/Glass/Liquid geçişi | Donanım ve sürücüyle birlikte performans ölçümü |
| Günlük kullanım | Dosya aç/kopyala/sil/geri al, ses çal, tarayıcı kullan | Kullanıcı senaryosu sonucu |
| Donanım | NVIDIA masaüstü; sonra seçilen diğer cihazlar | Ayrı cihaz listesi; denenmeyenler açıkça belirtilir |
| Canlı oturum | İç disklere kurmadan dene; yeniden başlat | Oturumun kalıcılık ve disk davranışı açıklaması |

Çıkış koşulları ilk sürüm kapsamına göre daraltılır; örneğin Liquid prototipi başarısızsa Glass ile alfa çıkışı mümkün olabilir. Bu durum bilinen sınırlama olarak yazılır, tamamlanmış Liquid özelliği gibi sunulmaz.

## 14. Codex ve Claude iş bölümü

Kullanıcının devrettiği rol seçimi: Codex build sistemi, LFS, ABI kapsamı, Hyper-V/ISO ve entegrasyon sahibi; Claude Code masaüstü profilleri, terminal kullanıcı deneyimi, kısayollar, tema, **paket motoru (`alp`, bkz. D31/P13, 21 Eylül 2026)** ve ikinci göz inceleme sahibi. Bu sahiplik planıdır.

**Not (21 Eylül 2026):** Önceki sürümde "paket entegrasyonu" Codex'in sahiplik alanındaydı (pacman/libalpm + PackageKit backend'i, PKG-01/PKG-02). Kullanıcı D31 ile bu kararı değiştirdi: motor artık `alp`, sahibi Claude. Codex'in rolü bu noktadan sonra LFS temel sistemine `alp`'i (saf Python, stdlib-only bir script; ek bağımlılık gerektirmez) yerleştirmek ve BLFS grafik/oturum zincirini ilerletmekle sınırlı; PackageKit/Discover backend'i artık bu planın kapsamında değildir (`alp`'in kendi GUI entegrasyon yolu ayrıca ele alınacak, proposal §6'da "Yok" olarak işaretli açık eksiklik).

Ana kaynak kökü `C:\alpbahOS`; Claude için ayrı Git worktree `C:\alpbahOS-claude`. Ortak `main` üzerinde eşzamanlı yazılmaz. Kod, küçük varlıklar ve Markdown dosyaları özel repoda; büyük çıktılar F: üzerinde. Claude aynı makinede değilse kendi clone/branch'inde aynı kuralları izler. İlk devir belgesi [CLAUDE_START.md](CLAUDE_START.md), görev listesi [BACKLOG.md](BACKLOG.md).

Her görevde: ID, sahip, dosya sınırı, girdi/çıktı, bağımlılık, test yöntemi ve devir notu bulunur. Ortak dosya veya rootfs için tek yazıcı olur. Aynı anda iki build motoru tek paket veri tabanını değiştirmez.

Önceden anlaşılacak entegrasyon sözleşmeleri:

- Tema token'ları, profil adları ve kurulum hedefleri.
- `alp` CLI semantiği (eski ad `pkg`), hata kodları ve mağaza erişim yöntemi.
- Kısayol tanımlarının tek kaynağı.
- Paket manifesti ve build artifact yolları.
- Test raporu, log ve görev devri biçimi.

Ortak kurallar [AGENTS.md](../AGENTS.md), Claude başlangıç talimatları [CLAUDE.md](../CLAUDE.md) içindedir. Bağlantı veya ortak repo kurulmadan Claude'a iş gönderildiği varsayılmaz.

## 15. Zaman ve kaynak tahmini yöntemi

Önceki konuşmadaki gün/token tahminleri teslim taahhüdü değildir. Plan şu ölçümlerle takvime çevrilir:

1. Host hazırlama ve ilk referans derleme süresi.
2. Kullanılabilir RAM altında güvenilir paralellik seviyesi.
3. Temel sistem, grafik yığını ve masaüstünün ayrı süreleri.
4. Kaynak indirme, test ve yeniden derleme payı.
5. Günlük makine erişimi ve insan test zamanı.

Token miktarı derleyicinin çalışma süresini azaltmaz. İki ajan tasarım, tarif hazırlama ve incelemede paralel ilerleyebilir; bağımlı toolchain adımları ve tek rootfs işlemleri sıralı kalır. Başarı için ilk odak M05 boot, sonra M07 masaüstü, ardından M09 canlı ISO'dur.

## 16. Günlük çalışma planı ve açık teknik kapılar

Her 1–2 saatlik kullanıcı oturumu: 10 dk devir/log inceleme, 40–75 dk tek görev veya entegrasyon, 15–25 dk test, 5–10 dk kayıt/sonraki adım. Derleyicinin makine zamanı ayrı ölçülür; bilgisayarın gece açık kalması henüz belirtilmediğinden gece derlemesi zorunlu varsayılmaz.

İlk beş oturumun hedef sırası:

1. Plan/repo/devir düzeni ve Hyper-V yetki kontrolü.
2. Builder hazırlığı, ağ/SSH ve LFS host-check.
3. Kaynak/kitap sabitleme, ABI kapsamı ve paket motoru küçük deneyleri.
4. Geçici toolchain başlatma; Claude tarafında tema/kısayol dosyalarının hazırlanması.
5. Sonuçları doğrulama ve ölçümlerle sonraki oturumları planlama.

Bu sıra bir günde bir aşamanın kesin biteceği anlamına gelmez. Uzun derleme/test adımları birden fazla oturuma yayılabilir.

Teknik kapılar: Hyper-V yönetim yetkisi; eşleşen multilib kaynak revizyonu; PackageKit/libalpm/Discover uyumu; Plasma düşük RAM hedefi; Hyper-V grafik oturumu; NVIDIA gerçek donanım; Office sürüm testleri. Bunlar genel planı bloke eden cevap bekleyen sorular değil, ilgili aşama başlamadan/bitmeden kanıtlanacak işlerdir.

İlk sürümler: `0.1-dev` boot eden taban, `0.2-alpha` VM masaüstü + BIOS/UEFI canlı ISO, `0.3-beta` grafik/offline/dual-boot kurucu, `1.0` uyumluluk ve güncelleme testleri tamamlanmış günlük kullanım adayı. İlk sürümün sistem sürüm numarası ile plan belgesinin 1.0 sürümü karıştırılmamalı.
