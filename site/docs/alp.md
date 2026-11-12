# alp paket yöneticisi

`alp`, alpbahOS için geliştirilen paket yöneticisidir. Komutlar geliştirme aşamasındadır; örnekler arayüzü anlatır ve tüm paketlerin kurulabileceği garantisini vermez.

## Paket ara

```bash
alp search htop
```

`search`, katalogda paket aramak için tasarlanmıştır. Katalog içeriği ve sonuçlar kullanılan test sürümüne bağlıdır.

## Paket kur

```bash
alp install htop
```

Kurulumdan önce gösterilen işlemleri incele. `htop` kurma ve kaldırma akışı geliştirme ortamında denenmiştir; tüm paketlerde aynı sonucun alınacağı henüz doğrulanmadı.

## Paket kaldır

```bash
alp remove htop
```

Kaldırılacak paketleri gözden geçir. Kişisel belgeleri korumak tasarım hedefidir; işlemden önce yedeğini al.

## Güncellemeleri kontrol et

```bash
alp update
```

Bu komutun güncel sürümdeki tam davranışı ve yükseltme akışı son kullanıcı için henüz doğrulanmadı. Güncelleme veya kurtarma işlemlerini test ortamı dışında yaptığını varsayma.

## Komutları okumak

Yukarıdaki örneklerde `htop` bir paket adıdır. Başka bir paket ararken veya kurarken kendi ihtiyacına uygun paket adını yazman gerekir. Bir paketin katalogda görünmesi, her cihazda veya her test imajında kurulumun başarıyla tamamlanacağı anlamına gelmez.

Komutun çıktısında hata varsa metni dikkatle oku. Yönetici yetkisi isteyen işlemlerde yalnızca güvendiğin paketi ve kaynağı seç; ne yapılacağını anlamadığın bir işlem planını onaylama.

## Kurmadan önce işlemleri incele

Proje planına göre kurulumdan önce etkilenecek paketlerin, kaynağın, indirme boyutunun ve gereken disk alanının gösterilmesi hedefleniyor. Bir paketi kaldırırken diğer paketlerin de etkilenip etkilenmediğini kontrol et. Bu bilgiler her test sürümünde aynı biçimde gösterilmeyebilir.

::: warning Güncelleme ile yükseltme
Plan, `alp update` ve `alp upgrade` komutlarını ayrı kavramlar olarak ele alıyor; son arayüz ve bu iki komutun ayrılıp ayrılmayacağı kesinleşmiş değil. Özellikle uzak katalogla güncelleme akışının son kullanıcı doğrulaması tamamlanmadı.
:::

## Katalog ve güven

11 Kasım tarihli r36 sanal sistem testinde imzalı katalog kabul edildi; değiştirilmiş bir katalog reddedildi. Aynı testte `alp list`, `alp check` ve `alp search bash` komutları başarıyla çalıştı. Test görüntüsündeki anahtar geçiciydi; bir genel sürüm için kalıcı anahtar gerekliliği kayıtta ayrıca belirtiliyor. Bu test, tüm paket kurulumları veya güncellemelerin doğrulandığı anlamına gelmez.

## Grafik mağaza ve diğer kaynaklar

KDE Discover ile `alp` arasında grafik mağaza entegrasyonu planlanıyor. Flathub da ek uygulama kaynağı olarak düşünülüyor. Grafik mağazadan arama, kurma, açma ve kaldırma akışları tümüyle doğrulanmadan çalışıyor sayılmıyor. Paket veya uygulama kurarken kaynağını kontrol et.

## Bir komut başarısız olursa

Önce paket adını ve gördüğün hatayı kontrol et; aynı işlemi farklı yetkilerle sürekli tekrarlamak yerine hata metnini kaydet. Sistem güncellemesi yarım kaldıysa veya paket veritabanıyla ilgili bir uyarı çıktıysa, doğrulanmamış kurtarma komutları uygulama. Kullandığın sürümü ve hatayı [sorun bildiriminde](https://github.com/Yoursel71/alpbahOS/issues) paylaşabilirsin; özel bilgileri çıkar.
