# Hyper-V ve yerel kaynak planı

Durum: Plan. VM oluşturulmadı, fiziksel disk bölümleme yapılmadı.

## Ortam

- Windows: mevcut çalışma hostu.
- Builder: minimal Ubuntu 24.04 LTS amd64, Hyper-V Gen2; ISO sürümü ve checksum kurulumda kaydedilecek.
- LFS host koşulları kitap scriptiyle doğrulanacak; gerekli sh/awk/yacc bağlantıları yalnız builder içinde düzenlenecek.
- Builder: 6 vCPU, 12 GiB sabit RAM, başlangıç 4 build işi; ölçüme göre ayarlanır.
- Hedef testleri: Gen1 Legacy ve Gen2 UEFI, 2 vCPU/4 GiB; test VMs aynı anda açılmaz.
- Grafik: VM renderer bilgisi kaydedilir. VM performansı RTX performansı gibi raporlanmaz.
- Hyper-V modülü mevcut; yönetim sorgusu mevcut oturumda yetki hatası verdi. Kurulum öncesi uygun yönetim erişimi gerekir.

## 300 GB fiziksel tüketim bütçesi

Planlanan kök `F:\alpbahOS-build`. Kullanıcının 300 GB talebi decimal; yaklaşık 279 GiB. F: SATA HDD'dir. Aşağıdaki üst sınırlar toplam gerçek tüketimi yönetmek içindir; dinamik diskler boş alanı şimdiden tüketmez.

| Alan | Bütçe |
|---|---:|
| Builder VHDX: host, kaynak cache'i, Linux ext4 build/rootfs | 210 GB |
| Gen1/Gen2 test diskleri, sırayla yeniden kullanım | 40 GB |
| Son ISO ve teslim çıktıları | 20 GB |
| Checkpoint/geçici büyüme payı | 30 GB |
| Toplam | 300 GB |

Checkpoint boyutu gerçek yazma miktarıyla büyür. Otomatik günlük sonsuz snapshot yok; yalnız aşama dönüm noktaları ve ölçülen boş alanla alınır. İmaj/ISO sayısı sınırlı tutulur; temizleme açık hedef ve geri kazanım bilgisiyle yapılır. Kullanıcı dosyalarını silerek yer açılmaz. C: ve D: boşluğu otomatik ek cache'e dönüştürülmez.

## Hazırlık sırası

1. Hyper-V etkinliği/yönetim yetkisi, F: boşluğu ve mevcut sanal anahtarları oku.
2. Ubuntu ISO kaynağını ve doğrulama bilgisini sabitle.
3. Yalnız proje klasöründe builder sanal disk/VM oluştur; fiziksel disk passthrough kullanma.
4. Minimal Linux ve SSH hazırla; kullanıcı anahtarlarını repo dışında sakla.
5. Host-check, dosya sistemi semantiği, saat, ağ/TLS ve izin testleri yap.
6. LFS/multilib manifestlerini sabitle, referans derlemeyi ölç.
7. Hedef rootfs'den Gen1/Gen2 test imajı üret; kendi kernel'iyle boot et.

Gen2'de Secure Boot sertifika şablonu ve imzalanmış boot zinciri ayrı konudur. Kendi imzasız LFS imajı için ilk testte yalnız ilgili test VM'sinin Secure Boot ayarı ele alınır; Windows host ayarı değiştirilmez. Gen1 BIOS testiyle Gen2 UEFI testi aynı kabul sonucu sayılmaz.

## Hyper-V kernel kontrol listesi

Seçilen kernel dokümantasyonuna göre VMBus, Hyper-V storage/network, framebuffer/input ve kök dosya sistemi sürücüleri doğrulanır. Gen1 IDE/legacy cihazları ile Gen2 sentetik/SCSI yolu farklı olabilir. Root mount için gereken sürücü built-in veya initramfs içinde olmalıdır.

İlk alfa için GPU passthrough, Mi 9 üzerinde cross-compile ve bulut runner gerekmez. Mi 9 yalnız kullanıcı isterse SSH terminali/test istemcisi olarak yardımcı olabilir.

## Gün sonu devri

Host/VM adı, aşama, çalışan PID, log yolu, devam komutu, disk/RAM durumu ve güvenli durdurma yöntemi kaydedilir. Kullanıcının bilgisayarı gece açık tutacağı varsayılmaz; tamamlanmış paket/aşama üzerinden devam edilebilir olmalıdır.

Kaynak: [Microsoft Hyper-V Gen1/Gen2 rehberi](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/should-i-create-a-generation-1-or-2-virtual-machine-in-hyper-v).
