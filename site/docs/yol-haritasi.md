# Sürüm durumu ve yol haritası

alpbahOS **Beta 0.9** aşamasında. En yeni test ISO'su **R53e** (28 Kasım 2026): [Internet Archive](https://archive.org/details/alpbahos-beta-0.9-r53e). Sürüm notları GitHub'da: [R53e](https://github.com/Yoursel71/alpbahOS/releases/tag/beta-0.9-r53e-20261128). Küçük düzeltmeler artık yeni ISO beklemeden imzalı güncellemelerle gelir. Kararlı sürüm henüz yok. Her turun test kaydı depodaki [docs/verification](https://github.com/Yoursel71/alpbahOS/tree/main/docs/verification) klasöründe.

## Çalışanlar

| Alan | Durum |
| --- | --- |
| Canlı USB ve kurulum | BIOS ve UEFI, MSDOS ve GPT disklerde kurulum her turda sanal makinede test ediliyor. Gerçek bilgisayarda (Ryzen 7 5700, RTX 5060) USB açılışı ve kurulum yapıldı; sahibi bu kurulumu günlük kullanıyor. |
| Windows'un yanına kurulum | UEFI/GPT disklerde kurulum programında var (R52); sanal makinede test edildi. |
| Disk şifreleme (LUKS) | Kurulum programında şifreleme sayfası, açılışta Türkçe parola ekranı; sanal makinede test edildi. |
| NVIDIA | `alp install nvidia` ile kapalı kaynak sürücü; gerçek RTX 5060'ta Plasma Wayland, oyunlar, uyku/uyanma. |
| Wi-Fi | USB Wi-Fi adaptörüyle (ASUS USB-N14, Ralink RT5372) gerçek bilgisayarda bağlantı kuruldu (27 Kasım 2026). |
| Ses ve Bluetooth | Ses, Bluetooth hoparlör ve kulaklık (R53) gerçek bilgisayarda çalışıyor. |
| Uygulamalar | Firefox, LibreOffice, VLC hazır gelir; diğer uygulamalar Flathub'dan (`alp install` önerir). Steam gerçek bilgisayarda kullanılıyor. |
| Sistem güncellemeleri | İmzalı ve geri alınabilir sistem güncelleyicisi (R52). |
| Yazdırma | Ağ yazıcısı keşfi ve yazdırma sanal makine testlerinden geçiyor. |
| Bellek | 4 GiB sanal makinede masaüstü boştayken yaklaşık 900 MiB. |

## Sıradaki işler

- **Secure Boot:** imzalama henüz yok; Secure Boot kapalı açılmalı.
- **Gerçek donanım:** gerçek yazıcı, Windows'un yanına gerçek kurulum ve farklı Wi-Fi kartları (bir USB Wi-Fi adaptörü çalışıyor).
- **Medya:** NVIDIA ile donanım video çözme, ekran kaydı için H.264 kodlayıcı.
- **Dosyalar:** Dolphin'de telefon (MTP), Windows paylaşımları (SMB) ve SFTP.
- **Paketler:** R53'ün ek dosyalarının `alp` paketlerine dönüşmesi.

Ayrıntılı iş listesi: [BACKLOG.md](https://github.com/Yoursel71/alpbahOS/blob/main/docs/BACKLOG.md). Ana plan: [MASTER_PLAN.md](https://github.com/Yoursel71/alpbahOS/blob/main/docs/MASTER_PLAN.md).
