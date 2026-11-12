# Sürüm durumu ve yol haritası

alpbahOS geliştirme aşamasında. Henüz genel kullanıma sunulmuş bir sürüm yok. Aşağıdaki bilgiler proje ana planı ve 12 Kasım 2026 tarihli doğrulama kayıtlarından derlendi.

## Denenenler

| Alan | Sonuç ve sınır |
| --- | --- |
| Canlı masaüstü | BIOS ve UEFI sanal makinelerinde açıldı. Bir UEFI gerçek bilgisayarda USB ve canlı masaüstü de denendi. |
| Kurulum | BIOS ve UEFI sanal disk kurulumları geçti. Bir gerçek bilgisayarda UEFI kurulum denendi; Windows ile çift önyükleme doğrulanmadı. |
| 4 GiB RAM | Sanal makinede çalışma denendi; 4 GiB gerçek cihaz performansı henüz doğrulanmadı. |
| Hoş Geldin | Test imajında tema ve yerleşim akışları denendi; yeni ekranın son tasarımı seçilmedi. |
| Ağ | Gerçek bilgisayarda kablolu ağ ve sanal ortamda HTTPS denendi. Gerçek Wi-Fi testi açık. |
| Yazıcı | r44'te ağ keşfi ve yazıcı yönetimi testi başarısız; sorun araştırılıyor. |

## Planlanan ve henüz doğrulanmayanlar

- **Secure Boot:** İmzalama daha sonraki çalışma; şu an desteklenmiyor.
- **Steam ve Bottles:** Planlanıyor; geçerli uçtan uca testleri henüz yok.
- **LUKS ve Windows ile çift önyükleme:** Kurulum hedefleri; henüz doğrulanmadı.
- **Paket güncelleme ve kurtarma:** Genel kullanıma uygun uçtan uca doğrulama tamamlanmadı.
- **Gerçek donanım kapsamı:** Wi-Fi, yazıcı ve farklı cihazlar için testler açık.

## Kaynaklar

Ana plan ve geliştirme kayıtları proje deposundadır: [MASTER_PLAN.md](https://github.com/Yoursel71/alpbahOS/blob/main/docs/MASTER_PLAN.md), [doğrulama kayıtları](https://github.com/Yoursel71/alpbahOS/tree/main/docs/verification). Depodaki `main` dalı yerel test kayıtlarından daha eski olabilir.

## Geliştirme adımları ne anlama geliyor?

### Temel sistem ve masaüstü

Sistem LFS/BLFS 13.1 temeli üzerinde kaynak koddan oluşturuluyor. Plasma masaüstünün açılması ve test uygulamalarının başlatılması belirli imajlarda kontrol edildi. Bir uygulamanın açılması, tüm dosya türleri ve donanımlarda sorunsuz çalıştığını tek başına kanıtlamaz.

### Canlı USB ve kurulum

Canlı imajın açılması, yükleyicinin sanal diske yazması ve kurulan sistemin açılması ayrı testlerdir. 11 Kasım'da bir UEFI gerçek bilgisayarda USB açılışı ve kurulum da yapıldı. Windows ile aynı sistemde çift önyükleme ve şifreli kurulum ise ayrıca doğrulanmayı bekliyor.

### Uygulamalar ve paketler

Firefox, LibreOffice ve VLC ilk gerçek cihaz testinde açıldı; aynı testte Firefox'un görsel seçerken kapanması gibi sorunlar da kaydedildi ve ilgili düzeltmeler daha sonra test görüntülerine taşındı. `alp` katalog doğrulaması ve bazı temel komutlar r36'da denendi; Discover ve uzak katalogdan güncelleme için uçtan uca testler açık.

### Çevre birimleri

Kablolu ağ gerçek cihazda, ağ yazdırma bileşenleri ise sanal makinede denendi. r44'te ağ yazıcısı keşfi başarısız olduğundan gerçek yazıcı desteği tamamlanmış sayılmıyor. Gerçek Wi-Fi testi de açık.

## Sürüm yayımlanmadan önce

Bir test imajının bulunması ile herkesin kullanabileceği bir sürümün yayımlanması farklı durumlardır. Projenin açık işleri; cihaz çeşitliliğini artırmak, kurulumu ve kurtarmayı doğrulamak, paket ve sürücü akışlarını sınamak ve sonuçları kaydetmektir. Sürüm duyurusu ve resmî ISO bağlantısı hazır olduğunda ayrıca paylaşılacaktır.
