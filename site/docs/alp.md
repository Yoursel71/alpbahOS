# alp paket yöneticisi

`alp`, alpbahOS'un paket yöneticisidir. Sistem paketlerini kurar ve kaldırır; katalogda olmayan uygulamalar için Flathub'daki karşılığını ya da Debian kutusundaki paketi önerir. Komutları Türkçe de yazabilirsin: `alp kur`, `alp ara`, `alp kaldır`, `alp güncelle`, `alp bilgi`.

## Paket ara

```bash
alp search htop
```

Sonuçlar üç başlıkta gelir: alp kataloğu, Flathub ve (varsa) Debian kutusu. Kurulu olanların yanında `[kurulu]` yazar. Aynı aramayı bir gün içinde tekrar yaparsan sonuç hemen gelir. Yalnız alp kataloğunda aramak için `alp search --katalog htop`.

## Paket bilgisi

```bash
alp info nvidia
```

Sürümü, kurulu olup olmadığını, bağımlılıkları ve dosyaları Türkçe gösterir. Betikler için `alp info --json nvidia`.

## Paket kur

```bash
sudo alp install htop
```

Kurulumdan önce yapılacak işlemler gösterilir. Paket alp kataloğunda yoksa `alp install` aynı adlı Flathub uygulamasını önerir (örneğin `alp install steam`). Sistemin güncellenmesi gereken bir uygulamada (örneğin Steam) önce uyarır ve güncellemeyi önerir.

## Paket kaldır

```bash
sudo alp remove htop
```

## Güncellemeler

```bash
sudo alp upgrade
```

Tek komutla her şeyi sırayla günceller, her adımı ayrıca sorar:

1. alpbahOS sistem güncellemesi (imzalı, sorun çıkarsa geri alınabilir)
2. alp paketleri
3. Flatpak uygulamaları
4. Debian kutusu (apt)

Sonunda bir özet gösterir. Yalnız bakmak için `alp upgrade --dry-run`. Yalnız bir paketi yükseltmek için `sudo alp upgrade <paket>`, yalnız Debian kutusu için `alp upgrade --kutu`.

Sistem güncellemeleri **alpbahOS Güncelleme** uygulamasından da kurulabilir; oturum açılınca yeni güncelleme varsa bildirim gelir.

## NVIDIA sürücüsü

```bash
sudo alp install nvidia
```

## `apt` yazarsan

alpbahOS Debian tabanlı değildir. `apt install ...` yazarsan aynı işi yapan `alp` komutunu gösterir.

## Katalog ve güven

alp kataloğu imzalıdır: imzası tutmayan ya da değiştirilmiş bir katalog reddedilir. Paketler kum havuzunda (sandbox) derlenir.

## Flathub

Uygulamalar Flathub'dan gelir: `alp install <ad>` ya da doğrudan `flatpak install flathub <uygulama>`. Grafik bir uygulama mağazası henüz yok.

## Bir komut başarısız olursa

Hata metnini kaydet ve kullandığın sürümle birlikte [sorun bildiriminde](https://github.com/Yoursel71/alpbahOS/issues) paylaş; özel bilgileri çıkar.
