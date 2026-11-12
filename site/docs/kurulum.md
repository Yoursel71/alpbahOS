# Kurulum

alpbahOS grafik kurulum için Calamares kullanır. Aşağıdaki ekranlar geliştirme sürümünden alınmıştır; son sürümde adımlar değişebilir.

::: danger Disk uyarısı
Kurulum diske yazabilir ve yanlış disk veya bölüm seçimi veri kaybına neden olabilir. Başlamadan önce önemli dosyalarını ayrı bir aygıta yedekle; seçtiğin diski ve bölümleme özetini dikkatle doğrula.
:::

## Kurulum öncesi

Önce canlı ortamı başlat, ardından masaüstündeki kurulum simgesini aç. Dil, klavye, kullanıcı ve disk ayarlarını ekrandaki açıklamalara göre gözden geçir. Test görüntüleri genel kullanıma sunulmuş bir sürüm değildir.

## Sürücüler

Sürücü sayfası test imajında ek sürücü seçeneği sunar. NVIDIA seçimi sanal kurulumda işaretlenip kuruluma aktarılmıştır; bu sonuç her ekran kartında hızlandırmanın çalıştığı anlamına gelmez.

![Kurulumda sürücü durumlarını gösteren sayfa](/images/screens/08-kurulum-suruculer.webp)

## Diski seç ve özeti incele

Hedef diski ve önerilen işlemleri dikkatle oku. Emin değilsen kurulumu durdur. Windows ile çift önyükleme ve LUKS şifreleme planlanıyor; henüz doğrulanmadı.

![Kurulum özeti ve disk bölümleme bilgileri](/images/screens/09-kurulum-ozet.webp)

## Kurulumu tamamla

Onaydan sonra kurulum dosyaları diske kopyalar. Tamamlandı ekranını gördüğünde yükleyicinin yeniden başlatma yönergelerini izle.

![Kurulumun tamamlandığını bildiren ekran](/images/screens/10-kurulum-bitti.webp)

BIOS ve UEFI kurulumları sanal disklerde sınanmıştır. Bir UEFI gerçek bilgisayarda da test kurulumu yapılmıştır; bu, tüm donanımlarda uyumluluk garantisi değildir.

## Adım adım neleri gözden geçirmeli?

### Dil, bölge ve klavye

Kurulum ekranında gösterilen dil ve klavye seçeneklerini kontrol et. Türkçe Q projenin varsayılan hedefidir. Parolanda Türkçe karakter veya noktalama kullanacaksan tuşların beklediğin karakterleri ürettiğinden emin ol; yanlış klavye seçimi daha sonra oturum açmayı zorlaştırabilir.

### Kullanıcı hesabı

Kullanıcı adı, bilgisayar adı ve parola alanlarını doldur. Parolanı güvenli bir yerde sakla ve başka kişilerle paylaşma. Otomatik oturum açma gibi seçenekler ekranda sunuluyorsa, özellikle paylaşılan okul bilgisayarlarında seçimlerini cihazın kullanım şekline göre değerlendir.

### Bölümleme seçenekleri

Kurulum ekranındaki bir disk adı, USB belleğini veya bilgisayarındaki başka bir diski gösterebilir. Kapasite ve model bilgilerini karşılaştır; yalnızca disk adının sırasına güvenme. Var olan bölümleri silme, biçimlendirme veya yeniden boyutlandırma seçenekleri veri kaybına yol açabilir. Ekrandaki açıklamayı anlamıyorsan kurulumu iptal et ve önce yedeğini doğrula.

::: warning Windows bölümleri
Windows'un yanına güvenli kurulum henüz test edilmedi. Bu nedenle bu belgede bölüm boyutlandırma veya önyükleme onarımı için doğrulanmış bir yol tarif edilmiyor.
:::

### Son onay ve yeniden başlatma

Özette hedef disk, oluşturulacak veya değişecek bölümler ve kullanıcı bilgileri gösterilir. Özet beklediğin gibi değilse geri dön; işlem başladıktan sonra geri almak kolay olmayabilir. Kurulum tamamlandığında ekrandaki yönergeye göre yeniden başlat ve gerekiyorsa USB'yi çıkar.

## Kurulum sırasında sorun olursa

Hangi adımda kaldığını, ekranda görünen hata metnini, bilgisayarın modelini ve BIOS/UEFI modunu not et. Disk veya parolayla ilgili özel bilgileri paylaşma. Bilinmeyen bir hatayı gidermek için rastgele disk komutları çalıştırma; [sorun bildiriminde](https://github.com/Yoursel71/alpbahOS/issues) açıklama isteyebilirsin.

## Test sonuçlarının sınırları

12 Kasım tarihli r44 kaydında BIOS ve UEFI sanal disk kurulumları geçti; NVIDIA seçimi yapılan sanal kurulumda ilgili işaret ve hizmetin etkinleştirildiği gözlendi. Bu, NVIDIA sürücüsünün bütün gerçek donanımlarda kurulduğunun veya grafik hızlandırmasının çalıştığının kanıtı değildir.
