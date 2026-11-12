# Başlarken

alpbahOS'un ilk sürümü, bilgisayarı USB'den başlatıp diske kurmadan masaüstünü denemeyi ve ardından grafik yükleyiciyle kurulumu hedefliyor.

::: warning Henüz indirmeye hazır değil
Test ISO'ları geliştirme için kullanılıyor. Yayımlanmış bir alpbahOS ISO'su henüz yok; indirme adresi ve son kullanıcıya yönelik USB yazma yöntemi yayınlandığında buraya eklenecek.
:::

## Canlı USB hazırlama

Yayımlanmış bir ISO ve resmî doğrulama bilgisi sağlandığında, indirdiğin dosyanın doğruluğunu kontrol et ve güvenilir bir USB yazma aracı kullan. USB'ye imaj yazmak **USB içeriğini siler**; önce doğru aygıtı seçtiğinden ve içindekileri yedeklediğinden emin ol. Bu proje için son kullanıcıya yönelik yazma adımları henüz doğrulanmadı.

## BIOS veya UEFI ile başlatma

1. Hazırlanan USB'yi tak ve bilgisayarı yeniden başlat.
2. Cihazının açılış menüsünü kullanarak USB aygıtını seç. Menü tuşu bilgisayar üreticisine göre değişir.
3. Canlı ortam açılırsa masaüstünü inceleyebilirsin. İç diske kurulum ayrı bir işlemdir.

BIOS ve UEFI açılışı sanal makinelerde denenmiştir. Bir UEFI gerçek bilgisayarda USB açılışı da test edilmiştir; donanımlar arasında sonuç değişebilir. Secure Boot şu anda desteklenmiyor; imzalama daha sonraki işlerden biridir.

## Sonraki adım

İç diske yüklemeyi düşünüyorsan önce [kurulum ve disk seçimi](/kurulum) bölümünü oku.

## Başlamadan önce kontrol listesi

- **Bilgisayarın mimarisini öğren:** Proje x86_64 bilgisayarları hedefler. Başka mimariler için destek belirtilmedi.
- **Dosyalarını yedekle:** Canlı ortamı yalnızca incelemek ile disk kurulumu farklı işlemlerdir; yine de kurulum düşünüyorsan yedeği önceden hazırla.
- **USB'deki verileri taşı:** İmaj yazma işlemi USB belleğin önceki içeriğini silebilir.
- **Güvenilir imajı bekle:** Resmî sürüm ve doğrulama yönergeleri yayımlanmadan üçüncü kişilerce paylaşılan test imajlarını resmî sürüm olarak kabul etme.

### ISO doğrulaması neden gerekir?

İmajın sağlama değerini resmî yayımlanan değerle karşılaştırmak, dosyanın aktarım sırasında değişip değişmediğini anlamaya yardımcı olur. Resmî imza ve doğrulama yöntemi henüz duyurulmadı. Bu nedenle burada bir sağlama değeri veya indirme bağlantısı verilmiyor.

## Canlı ortamda neye bakabilirim?

Geliştirme hedefi, iç diskte değişiklik yapmadan Plasma masaüstünü inceleyebilmektir. Ekran çözünürlüğünü, klavyeni, fareyi ve varsa ağ bağlantısını kontrol etmek iyi bir başlangıçtır. Donanım farklılıkları nedeniyle bir özelliğin sanal makinede çalışması senin cihazında da çalışacağını göstermez.

::: tip Canlı oturum ve kalıcılık
Canlı oturumda yapılan kişisel değişikliklerin USB'de saklanıp saklanmayacağı bu dokümantasyonda doğrulanmadı. Önemli dosyalarının yalnızca canlı oturumda bulunan bir kopyasına güvenme.
:::

## USB açılmazsa

Önce cihazın açılış menüsünde doğru USB aygıtını seçtiğini kontrol et. Gerekirse üreticinin BIOS/UEFI yönergelerine bak. Secure Boot desteği henüz hazır olmadığından, test ortamındaki durum resmî sürüm duyurusunda ayrıca açıklanmalıdır. Sorunu bildirirken cihaz modelini, hangi açılış modunu kullandığını ve gördüğün hata mesajını kaydet; parola veya kişisel verileri paylaşma.
