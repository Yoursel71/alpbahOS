# Sistem gereksinimleri

alpbahOS, daha eski x86_64 bilgisayarları da hedefler. Kesin son kullanıcı gereksinimleri donanım testleri tamamlandığında yayımlanacaktır.

## İşlemci ve bellek

- **İşlemci:** x86_64 mimarisi hedefleniyor.
- **Bellek:** 4 GiB RAM tasarım hedefidir. 4 GiB ayrılmış bir sanal makinede masaüstü ve kurulum testleri çalıştı.
- **Depolama ve USB:** Kesin minimum kapasite henüz belirlenmedi; ISO ve kullanılacak uygulamalar alan ihtiyacını etkiler.

::: tip 4 GiB hakkında
Sanal makine sonucu, 4 GiB RAM'li her gerçek bilgisayarda yeterli performans alınacağını kanıtlamaz. Gerçek donanımda düşük bellek testi henüz tamamlanmadı.
:::

## Açılış ve grafik

BIOS ve UEFI hedefleniyor; Secure Boot imzalama henüz uygulanmadı. Ekran kartı, ağ ve diğer sürücüler donanıma göre farklı davranabilir. Örneğin gerçek bilgisayar testindeki RTX 5060 görüntü verdi, fakat o testte GPU hızlandırması çalışmadı.

## Testte görülen değerler

12 Kasım tarihli r44 testinde 4 GiB bellek ayrılmış bir QEMU sanal makinesi ile canlı ve kurulu sistem kontrolleri yapıldı. B2 testinde boşta kullanılan bellek yaklaşık 944 MiB olarak kaydedildi. Bu yalnızca ilgili ölçümün ve test ortamının sonucudur; tarayıcı, açık belgeler, grafik efektleri ve farklı donanımlar toplam bellek ihtiyacını değiştirir.

Proje planında boşta 1 GiB veya daha az bellek kullanımı hedefi bulunur. Bazı test ölçümleri bu hedefin üzerine çıktığı için bunu her durumda karşılanan bir garanti olarak değerlendirme.

## Gerçek cihazlarda dikkat edilmesi gerekenler

- **Grafik:** Çözünürlük ve hızlandırma ekran kartı ile sürücüye bağlıdır. İlk gerçek bilgisayar denemesinde görüntü alınmasına rağmen RTX 5060 üzerinde GPU hızlandırması çalışmadı.
- **Ağ:** Kablolu bağlantı bir gerçek bilgisayarda denendi; gerçek Wi-Fi testi açık.
- **Depolama:** Kurulumun sığacağı asgari disk alanı henüz yayımlanmadı. Mevcut veriler için yedek alanını da planla.
- **Açılış:** BIOS ve UEFI sanal makine testleri vardır; Secure Boot imzalama henüz hazır değil.

## Okul bilgisayarları için değerlendirme

Birden çok kullanıcı hesabı, oturum kilidi ve belge açıp kaydetme akışları proje test planında yer alır. Bir okul laboratuvarında kullanıma karar vermeden önce kendi donanımında, ağında ve ihtiyaç duyduğun çevre birimleriyle test edilmesi gerekir. Merkezi yönetim ve belirli okul yazılımlarına uyumluluk bu belgelerde doğrulanmadı.
