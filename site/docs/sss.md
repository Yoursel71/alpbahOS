# Sık sorulan sorular

## alpbahOS'u indirebilir miyim?

Evet. En yeni beta test ISO'su R53e, [Internet Archive'da](https://archive.org/details/alpbahos-beta-0.9-r53e) tek dosya olarak duruyor; önceki sürümler GitHub'da [ön sürüm](https://github.com/Yoursel71/alpbahOS/releases) olarak var. İndirme ve doğrulama adımları [Başlarken](/baslarken) sayfasında.

## Windows'un yanına kurabilir miyim?

Evet, UEFI/GPT disklerde kurulum programı "Windows'un yanına kur" seçeneğini sunar (R52'den beri). Koşullar uygun değilse seçenek pasif kalır ve nedenini yazar. Bu akış sanal makinede test edildi; gerçek bir bilgisayarda Windows'un yanına kurulum kaydı henüz yok, o yüzden önce verilerini yedekle.

## 4 GB RAM yeterli mi?

4 GiB RAM hedefleniyor. 4 GiB'lık sanal makinede masaüstü boştayken yaklaşık 900 MiB bellek kullanıyor. Ayrıntılar [sistem gereksinimlerinde](/gereksinimler).

## Steam ve oyunlar çalışır mı?

Steam, Flathub'dan (`alp install steam` Flathub uygulamasını önerir) kurulup gerçek bilgisayarda NVIDIA sürücüsüyle günlük olarak kullanılıyor.

## Wi-Fi, Bluetooth ve yazıcı çalışır mı?

Bluetooth ses (hoparlör, kulaklık) R53'te gerçek bilgisayarda çalışıyor. Ağ yazıcısı keşfi ve yazdırma sanal makine testlerinden geçiyor. Wi-Fi: USB Wi-Fi adaptörüyle (ASUS USB-N14, Ralink RT5372) gerçek bilgisayarda bağlantı kuruldu (27 Kasım 2026). Gerçek bir yazıcıyla test kaydı henüz yok; ayrıntılar [yazıcı ve ağ](/yazici-ag) sayfasında.

## Secure Boot destekleniyor mu?

Henüz değil. Kurmadan önce BIOS/UEFI ayarlarından Secure Boot'u kapat.

## Hata nasıl bildirilir?

[GitHub sorunlar sayfasında](https://github.com/Yoursel71/alpbahOS/issues) cihazını, kullandığın sürümü (örneğin R53d ve `alpbahos-update --check` çıktısı) ve sorunu yeniden oluşturma adımlarını yaz. Parola veya kişisel bilgileri ekleme.

## Canlı USB bilgisayarımın diskini değiştirir mi?

Hayır, canlı oturum iç diske yazmaz. USB'ye ISO yazmak USB'nin içeriğini siler; iç diske yalnız kurulum programında onayladığın işlemler yazılır. Ayrıntılar [Başlarken](/baslarken) ve [Kurulum](/kurulum) sayfalarında.

## alpbahOS hangi masaüstünü kullanıyor?

KDE Plasma (Wayland). Altta görev çubuğu ve Başlat menüsüne benzeyen bir uygulama menüsü var; tema ve görev çubuğu seçenekleri Hoş Geldin ekranında.

## Atatürk teması zorunlu mu?

Hayır. alpbahOS marka teması varsayılandır; Atatürk teması seçilebilir bir alternatiftir. Bkz. [Hoş Geldin ve temalar](/hos-geldin).

## `apt` komutunu kullanabilir miyim?

alpbahOS'un paket yöneticisi `alp`. `apt install ...` yazarsan sana aynı işi yapan `alp` komutunu gösterir. Bkz. [alp paket yöneticisi](/alp).

## NVIDIA ekran kartım çalışır mı?

Evet: `sudo alp install nvidia` ile ya da kurulumdaki sürücü sayfasından NVIDIA sürücüsü kurulur. RTX 5060 olan gerçek bir bilgisayarda Plasma Wayland, oyunlar ve uyku/uyanma bu sürücüyle çalışıyor. NVIDIA ile donanım video çözme (VA-API) henüz yok.

## Belgelerdeki bir bilgi eskimişse ne yapmalıyım?

Sayfayı ve kullandığın sürümü belirterek [GitHub'da sorun açabilirsin](https://github.com/Yoursel71/alpbahOS/issues).
