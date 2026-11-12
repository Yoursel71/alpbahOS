# Yazıcı ve ağ

## Ağa bağlanma

Masaüstündeki ağ simgesinden kullanılabilir bağlantıları gözden geçir. Kablolu ağ, test edilen gerçek bilgisayarda çalıştı. NetworkManager ile DNS ve HTTPS sanal makinede kontrol edildi.

Wi-Fi gerçek donanım üzerinde henüz doğrulanmadı. Ağ bağdaştırıcısına ve gerekli ürün yazılımına göre sonuç değişebilir.

## Yazıcılar

Yazdırma için CUPS ve ağ üzerinden keşif bileşenleri üzerinde çalışılıyor. 12 Kasım tarihli r44 sanal makine testinde ağ yazıcısı keşfi ve yönetimi başarısız oldu. Bir hata ayıklama ortamında test yazıcısına çıktı gönderildi, ancak bu genel bir başarı testi değildir.

::: warning Henüz doğrulanmadı
Gerçek bir yazıcıyla kurulum ve yazdırma henüz test edilmedi. Ağda yazıcının otomatik bulunacağını veya belirli bir modelin çalışacağını varsayma.
:::

## Kablolu bağlantıyı kontrol etme

1. Ağ kablosunun bilgisayara ve ağ cihazına takılı olduğunu kontrol et.
2. Masaüstündeki ağ göstergesinde bağlantı durumuna bak.
3. Ağ açılmış görünüyorsa bir web sayfasını açarak bağlantıyı dene.
4. Bağlantı yoksa kullanılan test sürümünü, cihaz modelini ve varsa ekrandaki hata mesajını not et.

Tek bir bilgisayarda kablolu ağın çalışması, her ağ kartının ya da kurum ağının doğrulandığı anlamına gelmez. Proxy, özel kimlik doğrulama veya okul ağı kurulumları için doğrulanmış proje yönergeleri henüz yok.

## Kablosuz ağ için beklenti

NetworkManager ve kablosuz ağ bileşenleri test imajına eklenmiştir. Yine de gerçek bir Wi-Fi bağdaştırıcısıyla uçtan uca bağlantı testi kayıtlarda tamamlanmış değildir. Ağ adı görünmüyorsa veya bağlantı kurulamıyorsa donanım modeli ve kullanılan sürüm önemlidir; parola gibi bilgileri hata raporuna ekleme.

## Ağ yazıcısı testinde ne oldu?

r44 kaydında CUPS, Avahi ve ilgili hizmetlerin çalıştığı görüldü. Buna rağmen normal testte yönetim yetkisi sorunu yaşandı ve ağda servis keşfi başarılı olmadı. Ayrı bir hata ayıklama kopyasında yapılan değişiklikle test yazıcısına çıktı gönderildi; bu, normal imajın veya gerçek bir yazıcının doğrulandığı anlamına gelmez.

### Sorun bildirmek için

Gerçek donanım testleri başladığında yazıcı modeli, USB mi ağ mı kullanıldığı, kullanılan alpbahOS sürümü ve hata mesajı yararlı bilgiler olacaktır. Ağ adı, adresler, parola ve kişisel belge içerikleri gibi bilgileri paylaşmadan önce çıkar.
