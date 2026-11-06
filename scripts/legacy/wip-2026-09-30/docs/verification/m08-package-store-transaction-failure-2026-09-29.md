# M08 Discover install transaction probe — 29 Eylül 2026

## Test kapsamı

Son live ISO, geçici QEMU/KVM guest'inde Discover arama ve `htop` install eylemi için denendi. Amaç, UI eyleminin gerçek sonuç ve yetkilendirme akışını gözlemekti. Guest'e yazılabilir disk bağlanmadı; ISO CD-ROM salt okunurdu. Alp motoru/kataloğu değiştirilmedi.

- ISO: `/mnt/lfs/mnt/alpbahos-builds/m09-live-iso-20260929T153622Z/alpbahOS-live-m09.iso`
- QEMU: KVM, 4 vCPU, 4 GiB RAM, 1920×1080 VNC, NAT `virtio-net-pci`; sanal disk yok.
- Çalışma ve kanıtlar: `/mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/m08-discover-install-auth-20260929/`

## Sonuç

1. `plasma-discover --mode browse` ilk görüntüde 35 saniye sonunda hâlâ `Loading…` gösterdi. Sonraki aramada `htop` bulundu; detay sayfasında 3.3.0 sürümü, `Install from alpbahOS` eylemi ve hatalı `16.0 EiB` boyutu göründü.
2. `Install from alpbahOS` düğmesine basılınca Polkit kimlik/yetki penceresi açılmadı. Discover önce genel `Update Issue` gösterdi.
3. `See Technical Details` hata metni: `Internal error: alp: hata nedeniyle htop için yapılan dosya değişiklikleri geri alındı.` UI, paket işleminin başarısız olduğunu ve değişiklikleri geri aldığını bildirdi. htop kurulmuş sayılmaz; install → launch → remove kabulü geçmedi.
4. Hata metnini kopyalama düğmesi yalnız bu aynı metni verdi; daha ayrıntılı backend/build logu Discover içinden alınamadı. Dolayısıyla gerçek root cause bu probe ile belirlenmedi. Var olan htop `@PREFIX@` recipe bulgusu olası ilişkidir, fakat bu run bunu kanıtlamaz.
5. QMP ile guest'e kapatma gönderildi. QEMU exit 0 ile kapandı. Live guest shutdown sırasında `/run/iso` loop mount'unun busy kalması tekrarlandı; sistem kapanmayı tamamladı. Guest RAM overlay'i kapanışta atıldı.

## Kanıt ve sınırlar

- `/mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/m08-discover-install-auth-20260929/screenshots/discover-home.png`: 35 saniye sonraki Loading görünümü.
- `/mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/m08-discover-install-auth-20260929/screenshots/discover-htop-search.png`: htop arama sonucu.
- `/mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/m08-discover-install-auth-20260929/screenshots/discover-htop-details.png`: sürüm ve 16 EiB boyutu.
- `/mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/m08-discover-install-auth-20260929/screenshots/discover-install-prompt.png`: Install eyleminden sonra Update Issue.
- `/mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/m08-discover-install-auth-20260929/screenshots/discover-install-error-details.png`: Alp geri alma mesajı.
- `/mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/m08-discover-install-auth-20260929/screenshots/alp-error-clipboard.png`: hata kopyasının Konsole'a yapıştırıldığı görünüm.
- Serial log `/mnt/alpbahOS-data/alpbahOS-build/m06-m10-progress-20260929/m08-discover-install-auth-20260929/serial.log` içinde guest'in Power Off'a ulaştığı ve busy `/run/iso` detach uyarısı görülür. QEMU process exit code 0'dır.

Bu sonuç M08 mağaza akışının şu an çalışmadığını gösterir; auth diyaloğunun nasıl davranacağına dair kanıt değildir, çünkü backend hatası daha önce geldi. No writable disk ve canlı ISO'nun RAM overlay'i nedeniyle install denemesi kalıcı host/rootfs/ISO değişikliği oluşturmadı. M08 ve dolayısıyla M10 alfa onayı açık kalır.
