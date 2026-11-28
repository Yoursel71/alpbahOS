# Kurulum

alpbahOS grafik kurulum için Calamares kullanır. Canlı oturumda masaüstündeki **alpbahOS'u Kur** simgesiyle başlar.

::: danger Disk uyarısı
Kurulum diske yazar; yanlış disk seçimi veri kaybına yol açar. Başlamadan önce önemli dosyalarını yedekle ve özet ekranında hedef diski kontrol et.
:::

## Dil, bölge ve klavye

Türkçe ve Türkçe Q klavye varsayılan olarak seçilidir. Parolanda Türkçe karakter kullanacaksan klavye düzeninin doğru olduğundan emin ol.

## Kullanıcı ve bilgisayar adı

Adını, kullanıcı adını, bilgisayar adını ve parolanı yaz. Bilgisayar adı kurulan sisteme yazılır (R53).

## Sürücüler

Sürücü sayfasında açık kaynak sürücüler ve NVIDIA kapalı kaynak sürücüsü seçilebilir. NVIDIA sürücüsü kurulumdan sonra da `sudo alp install nvidia` ile kurulabilir.

![Kurulumda sürücü seçimi](/images/screens/08-kurulum-suruculer.webp)

## Disk seçimi

- **Diski sil:** seçilen diskin tamamı alpbahOS'a verilir.
- **Windows'un yanına kur:** UEFI/GPT diskte Windows varsa ve yer uygunsa sunulur (R52). Koşullar sağlanmazsa seçenek pasif kalır ve nedenini yazar.
- **Elle bölümleme:** bölümleri kendin seçersin.
- **Şifreleme:** diski LUKS ile şifreleyebilirsin; açılışta Türkçe parola ekranı çıkar.

Disk adlarının sırasına değil, boyut ve model bilgisine bak; USB bellek de listede görünebilir.

![Kurulum özeti ve disk bölümleme bilgileri](/images/screens/09-kurulum-ozet.webp)

## Kurulumu tamamla

Özeti onayladıktan sonra dosyalar kopyalanır. Tamamlandı ekranından sonra bilgisayarı yeniden başlat ve USB'yi çıkar.

![Kurulumun tamamlandığını bildiren ekran](/images/screens/10-kurulum-bitti.webp)

## Test durumu

BIOS ve UEFI kurulumları, Windows'un yanına kurulum ve şifreli kurulum her turda sanal makinede test ediliyor. Gerçek bilgisayarda (Ryzen 7 5700, RTX 5060) tüm diske kurulum yapıldı ve günlük kullanılıyor. Windows'un yanına gerçek bir bilgisayarda kurulum kaydı henüz yok.

## Sorun olursa

Hangi adımda kaldığını, ekrandaki hata metnini, bilgisayar modelini ve BIOS/UEFI modunu not edip [bildir](https://github.com/Yoursel71/alpbahOS/issues). Parola gibi özel bilgileri paylaşma.
