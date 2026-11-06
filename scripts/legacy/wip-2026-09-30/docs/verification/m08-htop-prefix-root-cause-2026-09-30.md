# M08 htop recipe root cause — 30 Eylül 2026

## Bulgular

Salt okunur incelemede M09 ISO içindeki htop 3.3.0 tarifi `./configure --prefix=@PREFIX@` komutunu aynen veriyor. Aynı ISO'dan alınan Alp motorunda tarif adımlarında `@PREFIX@` yer tutucusunu çözen bir dönüşüm bulunmuyor; `install_recipe()` adımları subprocess'e doğrudan iletiyor.

ISO tarifindeki upstream htop 3.3.0 arşivi `/tmp/alpbahos-htop-prefix.oiroKx` altında indirildi ve yayımlanmış SHA-256 (`a69acf9b42ff592c4861010fce7d8006805f0d6ef0e8ee647a6ee6e59b743d5c`) doğrulandı. Tam bu kaynakta `./configure --prefix=@PREFIX@` exit 1 ile `expected an absolute directory name for --prefix: @PREFIX@` hatası verdi. `./configure --prefix=/usr` ise başarılı tamamlandı.

Bu, önceki M08 QEMU kurulum denemesindeki Alp rollback hatasının htop tarifi için nedenini kanıtlar: literal `@PREFIX@` geçersizdir; recipe build adımı başarısız olur ve Alp değişiklikleri geri alır. Kurulumun bu aşamaya kadar başarısız olması nedeniyle Polkit/install/remove akışı hâlâ doğrulanmış değildir.

## Kapsam ve durum

- ISO, squashfs, katalog ve motor yalnızca okundu; Alp motoru veya Claude'a ait katalog değiştirilmedi.
- Kaynak probe'u geçici `/tmp` dizininde yapıldı; mevcut ISO ve VM artifact'leri değiştirilmedi.
- Bu bulgu M08'i kapatmaz. Tarif düzeltmesi sahibi tarafından yapıldıktan sonra yeni ISO gerekir; Discover üzerinden install → launch → remove ve yetki akışı tekrar doğrulanmalıdır.
- Önceki QEMU kanıtları ve sınırlar: [M08 transaction probe](m08-package-store-transaction-failure-2026-09-29.md).
