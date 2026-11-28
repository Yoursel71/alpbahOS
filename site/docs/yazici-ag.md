# Yazıcı ve ağ

## Ağa bağlanma

Görev çubuğundaki ağ simgesinden bağlantıları yönet. Kablolu ağ gerçek bilgisayarda çalışıyor; DNS ve HTTPS her turda kontrol ediliyor.

Kablosuz ağ bileşenleri (NetworkManager, wpa_supplicant ve yaygın kartların ürün yazılımları) sistemde var. USB Wi-Fi adaptörüyle (ASUS USB-N14, Ralink RT5372) gerçek bilgisayarda bağlantı kuruldu (27 Kasım 2026). Bir USB adaptör sık sık kopuyorsa onu kasanın arkasındaki başka bir USB girişine tak (yetersiz güç `error -71`/`-110` hatası verir). Bir sorunla karşılaşırsan kart modelini yazarak bildir.

## Yazıcılar

Yazdırma için CUPS ve ağda yazıcı bulmak için Avahi hazır gelir. Ağ yazıcısını bulma, ekleme ve test sayfası yazdırma sanal makine testlerinden geçiyor (R45'ten beri). Yazıcıyı **Sistem Ayarları > Yazıcılar** bölümünden ekleyebilirsin.

Gerçek bir yazıcıyla test kaydı henüz yok. Yazıcın görünmezse modelini ve USB mi ağ mı kullandığını yazarak bildir.

## Kablolu bağlantıyı kontrol etme

1. Ağ kablosunun bilgisayara ve modeme takılı olduğunu kontrol et.
2. Görev çubuğundaki ağ simgesinde bağlantı durumuna bak.
3. Bir web sayfası açarak bağlantıyı dene.
4. Bağlantı yoksa kullandığın sürümü, cihaz modelini ve hata mesajını not edip [bildir](https://github.com/Yoursel71/alpbahOS/issues).

## Uzaktan bağlanma

`ssh` ve `scp` R53'ten beri hazır gelir.
