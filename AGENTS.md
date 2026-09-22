# alpbahOS — Ortak ajan çalışma talimatları

Bu dosya projede çalışan tüm ajanların ortak talimatıdır. Kullanıcının yeni açık kararları önceliklidir; bunları karar kaydına yansıt. Ana plan 1.0 ve M1 LFS temel boot imajı hazırdır; güncel çalışma durumu `CURRENT.md` içindedir. Bu belge tek başına fiziksel disk değiştirme görevi değildir. Kullanıcının mevcut görev yetkisini ve kabul edilmiş tercihlerini tekrar sormadan kullan.

## Başlangıç

1. Bu dosyayı, `docs/DECISIONS.md` ve `docs/MASTER_PLAN.md` dosyalarını oku.
2. `CURRENT.md` ile `docs/WORKLOG.md` içindeki son durum ve sahipliği kontrol et.
3. Görsel işlerde `docs/alpbahOS-design-mockups.md` ve mevcut logo referansını incele.
4. Çalışma ağacındaki kullanıcı değişikliklerini koru. Git deposu yoksa varmış gibi davranma.
5. Görev kapsamını, kullanılacak ortamı ve doğrulama yöntemini belirle; yalnız ilgili işe başla.

## Ürün ilkeleri

- İsim tam olarak `alpbahOS`; mimari hedef x86_64.
- Windows'tan geçen genel masaüstü kullanıcılarını hedefle.
- LFS tabanını kaynak koddan oluştur; masaüstü ve uygulamalarda hazır açık kaynak projelerini özelleştir.
- Sıfırdan kernel, compositor, tarayıcı veya bağımlılık çözücü geliştirmeyi bu hedefin kendiliğinden parçası sayma.
- Soluk terminal önerileri, kolay paket işlemleri, Windows'a tanıdık kısayollar, Atatürk görselleri ve donanıma uygun cam efektlerini gereksinim olarak koru.
- Kullanıcı teknik seçimleri devretti: planın teknik seçimleriyle ilerle; başarısız deneyde gerekçeli revizyon yap. Test edilmemiş seçimi çalışan özellik gibi sunma.
- Hyper-V, 300 GB yerel bütçe, Türkçe/Türkçe Q, Legacy+UEFI ve mevcut mockup düzeni sabittir. Bulut build/ISO depolaması kullanma; özel kaynak Git deposu istisnadır.
- Eski x86_64 donanım ve düşük RAM önceliklidir. Solid varsayılan, Glass/Liquid seçenektir; hedefleri MASTER_PLAN.md'den al.
- Wine/Steam istenir; multilib kararını toolchain'den sonraya erteleme. Word/oyun ve tüm sürücü desteğini test olmadan garanti etme.

## Doğruluk ve kayıt

- Mockuplardaki kernel, RAM, paket sayısı, `pacman`, `alba` ve masaüstü adları çalışan sistem kanıtı değildir.
- Yapılmamış derleme, test, donanım doğrulaması veya Claude incelemesi yapılmış gibi raporlanamaz.
- Test sonucu yanında ortam, komut/işlem, sonuç ve log/artifact yolu ver.
- Kitap sürümü, kaynak URL'si, checksum, yamalar, yapılandırma ve bağımlılıklar kayıtlı olmalı.
- Günlük tahminleri ilk gerçek derleme ölçümlerinden sonra güncelle; token bütçesinden teslim tarihi çıkarma.

## Kod, derleme ve dosya sistemi

- Windows belge kökü ile Linux derleme kökünü ayır. Linux derleme kökü, seçilen VM/WSL içindeki Linux dosya sistemi olmalı; proje belgelerinin C: üzerinde olması bunu değiştirmez.
- Komutun Windows host, Linux host, geçici toolchain, chroot veya hedef sistem için olduğunu açıkça belirt.
- `$LFS` için boş olmayan, çözümlenmiş doğru hedefi ve beklenen mount'u doğrula; host köküne yanlış kurulum yapma.
- LFS'nin kullanıcı/izin sırasını koru. Gerekli root işlemlerini açıkça sınırla; bütün akışı root yapma.
- Her paket için ayrı temiz build/staging alanı, sürüm bilgisi, log ve durum kaydı tut.
- Kaynağı doğrulamadan derleme yapma. Ağdan indirilen betikleri körlemesine shell'e aktarma.
- Temel paketlerin hangi dosyalara sahip olduğunu izleyecek yöntem LFS nihai sistem kurulumundan önce seçilmiş olmalı.
- Kaldığı yerden devam etme, sadece stamp dosyasına değil girdiler ve çıktılarının doğrulanmasına dayanmalı.
- Kritik toolchain test hatalarını bastırma; bilinen istisnaları kitap/errata ve log ile açıklayıp kayıt altına al.
- Paralellik seviyesini RAM ve ölçümlere göre belirle. Kitabın paket bazlı kısıtlarını koru.
- Disk imajını açık hedefle kullan; fiziksel disk bölümleme, biçimlendirme, bootloader yazımı veya Windows boot değişikliği için ilgili açık kullanıcı yetkisini doğrula.

## Paket ve terminal davranışı

- Tek paket veri tabanı ve tek yazıcı/işlem kilidi kullan. CLI ve mağaza aynı işlem motorunu çağırmalı.
- D31 ile seçilen başlangıç motoru `alp`tir; recipe, Flatpak sarmalayıcı ve core arşiv yolları tek veritabanı/kilit kullanır. Bağımlılık çözümü ve grafik mağaza entegrasyonu test edilmeden hazır sayılmaz. Başka native paket motorunu aynı rootfs'de bağımsız kurma.
- Depo tutarlılığını koru; kısmi güncelleme üretme. Kendi paketlerimiz ve kendi manifestimiz kullanılmalı.
- `apt` benzeri komut adı, Debian/Ubuntu depolarıyla ikili uyumluluk anlamına gelmez. Dış dağıtımın taban depolarını karıştırma.
- Sistem paketleri için kaynak ve depo güvenini doğrula; ayrı uygulama formatları varsa kullanıcıya kaynaklarını göster.
- Önizleme önerisi hiçbir zaman kendiliğinden çalışmaz. Kabul etmek ve çalıştırmak ayrı kullanıcı adımlarıdır.
- Yazım yardımı argümanları/dosya adlarını sessizce yeniden yazmaz; etkileşimli shell ayarları build scriptlerine sızmaz.
- Kullanıcı shell tercihi için `/bin/sh` hedefini değiştirme; betikler gerekli yorumlayıcıyı açıkça seçer.

## Masaüstü ve görsel kalite

- Logo ve renklerin mevcut kimliğini koru; ortak tema token'larından yararlan.
- Pencere/shell temasıyla GTK, Qt ve üçüncü taraf uygulamalarının tamamının birebir aynı görüneceğini varsayma; test edilen kapsamı belirt.
- Glass, Liquid ve sade görünüm ayrımını ölçülebilir yap. Gerçek kırılma efekti varsa teknik kanıt ve performans ölçümü olmadan hazır sayma.
- Efekt kapatma, kontrast ve azaltılmış hareket davranışları erişilebilir kalmalı.
- Varsayılan masaüstü ve kilit ekranı Atatürk temalıdır. Belirli görsel veya söz uydurma; dağıtılacak varlıklarda kaynak/izin bilgisini tut. Boot ekranının kapsamını ayrıca belirle.
- Kısayolları tek merkezde tanımla. Aynı tuşa iki sistem eylemi bağlama; terminal Ctrl+C gibi bağlamsal farkları koru.

## İki ajanla çalışma

- Aynı dosya grubunu ve aynı rootfs'yi eşzamanlı değiştirme. Dosya işi için görev sahipliği; build/mount/paket işlemleri için ortam kilidi kullan.
- Rol planı: Codex altyapı/entegrasyon, Claude Code masaüstü/tema/terminal UX. Göreve gerçek başlama durumu BACKLOG.md ve devir kayıtlarıyla izlenir; Claude başlatılmış varsayılmaz.
- Ana çalışma ağacı `C:\alpbahOS`; Claude çalışma ağacı `C:\alpbahOS-claude`. Her ajan kendi dalında çalışır; main'e entegrasyon sahibi birleştirir. Paralellik yeni bir AI sürecini kendiliğinden başlatma yetkisi değildir.
- Ayrı Git dalları/worktree'ler uygunsa kullan; test edilen commit ve birleştirme sorumlusu kaydedilsin.
- İşe başlamadan `docs/WORKLOG.md` içinde görev, sahip, dosya sınırı ve bağımlılığı kaydet; başka ajanla ortak kaydı eşzamanlı değiştirmek yerine entegratör üzerinden güncelle.
- Görev devrinde değişiklik, dosyalar, ortam, testler, hatalar ve sıradaki tek eylemi yaz.
- Claude'a erişim yoksa ona görev gönderilmiş veya inceleme yaptırılmış gibi davranma; kullanıcıya aktarılabilir görev metni hazırla.
- Entegrasyon öncesi kritik build, paket ve kurulum değişikliklerini diğer ajanın incelemesine sunma imkânı varsa kullan; inceleme yoksa bunu açıkça kaydet.

## Tamamlanma ve raporlama

- Bir aşama yalnız ana plandaki çıkış koşulları kanıtlandığında tamamlanır.
- “Script hazır”, “derleme geçti”, “boot etti”, “gerçek donanımda çalıştı” farklı durumlardır.
- Türkçe, kısa ve somut rapor ver. Kullanıcıya çıktıları bağla; uzun logları dosyada tut.
- Her 1–2 saatlik kullanıcı oturumu sonunda sürdürülebilir devir notu bırak. Teknik plan/komutları Türkçe arayüz tercihinden bağımsız, açık yorumlayıcı ve locale ile yaz.
- Kapsam dışı yayın, uzak depoya push, fiziksel kurulum veya ücretli kaynak kullanımı için mevcut yetkiyi kontrol et.
