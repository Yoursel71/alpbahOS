# Eski infra overlay temizliği — 5 Ekim 2026

SSD boş alanı canlı base-run sırasında %15 durma sınırına yaklaşınca, derlemeyi etkilemeyen eski qcow2 snapshot'ları denetledim. Etkin Builder QEMU PID 494050 yalnızca `builder-active.qcow2` ve `lfs-active.qcow2` kullanıyordu; ikisinin de kaynak backing'i `checkpoint-toolchain` idi. Silinecek eski kopyalarda her klasör yalnızca bu iki qcow2 imajını içeriyordu, her iki backing yolu da `checkpoint-toolchain` altındaydı ve etkin QEMU komut satırında silinecek klasörlerden hiçbiri yoktu.

Kullanılmayan `preserved-overlays-1791087673692209770`, `preserved-overlays-1791104739364229219`, `preserved-overlays-1791151017815589134` ve `preserved-overlays-1791155989033719820` klasörleri silindi. Son üç korunan klasör (`1791184739684835829`, `1791207400397850271`, `1791213103526691123`), araç zinciri kontrol noktası ve aktif diskler yerinde bırakıldı. Makbuz `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-infra-overlays-20261005.json` dosyasında önce/sonra kapasiteyi, dosya boyutlarını ve backing yollarını kaydeder.

İşlem 30,64 GiB boş alan kazandırdı. `/mnt/alpbahOS-ssd` boş alanı 20,35 GiB'den 50,99 GiB'ye çıktı (`df -h`: 112 GiB toplam, 58 GiB kullanılmış, 51 GiB boş). Bu repo temizliği bir ürün/build kabulü değildir; LFS temel sisteminin şu anki durumu glibc `make check` testidir.

Silme sonrasında canlı run `8c3fa34507986406be0298fb269a26c7` devam etti. Host telemetry'de `errors=[]`, `kernel_faults=[]`, Tctl 57,875°C görüldü; glibc `printf` testleri sürüyordu. Expect aşaması, base acceptance ve checkpoint henüz üretilmedi.
