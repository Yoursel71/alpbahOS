# Hyper-V ve yerel kaynak planı

> Durum notu (24 Eylül 2026): BIOS/Gen1 kabul testleri tarihsel olarak tamamlandı; `alpbahOS-M2-SSH-Gen1` test VM kaydı sonradan silindi. Güncel canlı VM test hedefi Gen2/UEFI'dir. Gen1 VHDX dosyalarının son bilinen durumu için `docs/NEW_SESSION_HANDOFF.md`'ye bakın.

Durum: Builder VM'i ve build diski mevcut; fiziksel disk bölümleme yapılmadı. 23 Eylül 2026'da SSH salt okunur incelemesi yapıldı.

## Ortam

- Windows: mevcut çalışma hostu.
- Builder: Ubuntu 24.04 LTS amd64, Hyper-V Gen2. Builder SSH bağlantısı doğrulandı; Hyper-V PowerShell sorgusu mevcut token'da yönetici izni reddediyor.
- LFS host koşulları kitap scriptiyle doğrulanacak; gerekli sh/awk/yacc bağlantıları yalnız builder içinde düzenlenecek.
- Builder (gerçek): 4 vCPU; 3 GiB başlangıç/en az ve 6 GiB en çok dynamic RAM. Build paralelliği kullanılabilir RAM'e göre seçilir. Eski 6 vCPU / 12 GiB planı geçersizdir.
- Kabul kapsamı Gen1 Legacy ve Gen2 UEFI'dir; önceki Gen1 test VM kayıtları silinmiştir ve sonuçları tarihsel kanıt olarak tutulur. Şu anki canlı test hedefi Gen2 UEFI'dir. Yeni Gen1 testi gerektiğinde ayrı VM kaydı ve test diski oluşturulmalıdır. Test VM'leri 2 vCPU/4 GiB hedefler; aynı anda açılmaz.
- Grafik: VM renderer bilgisi kaydedilir. VM performansı RTX performansı gibi raporlanmaz.
- Hyper-V modülü mevcut; yönetim sorgusu mevcut oturumda yetki hatası verdi. Kurulum öncesi uygun yönetim erişimi gerekir.

### Builder disk gözlemi — 23 Eylül 2026

- Builder VHDX sanal kapasitesi 210 GiB; guest `lsblk` `/dev/sda3` LVM PV'yi 206.9 GiB, root LV'yi 100 GiB gösterdi.
- Guest `df -h /`: 98 GiB toplam, 69 GiB kullanılmış, 25 GiB boş, %74 kullanım.
- `sudo -n vgs` ve `sudo -n lvs` parola istedi; VG'deki gerçek boş extent miktarı ölçülemedi. LV/VHDX boyutu değiştirilmedi. Komut ve çıktı: [P0/P1/P2 audit logu](verification/p0-p2-audit-2026-09-23.log).

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
6. LFS 12.4 kaynak manifestini ve saf x86_64 ABI kapsamını sabitle; referans derlemeyi ölç.
7. Hedef rootfs'den Gen1/Gen2 test imajı üret; kendi kernel'iyle boot et.

Gen2'de Secure Boot sertifika şablonu ve imzalanmış boot zinciri ayrı konudur. Kendi imzasız LFS imajı için ilk testte yalnız ilgili test VM'sinin Secure Boot ayarı ele alınır; Windows host ayarı değiştirilmez. Gen1 BIOS testiyle Gen2 UEFI testi aynı kabul sonucu sayılmaz.

## Hyper-V kernel kontrol listesi

Seçilen kernel dokümantasyonuna göre VMBus, Hyper-V storage/network, framebuffer/input ve kök dosya sistemi sürücüleri doğrulanır. Gen1 IDE/legacy cihazları ile Gen2 sentetik/SCSI yolu farklı olabilir. Root mount için gereken sürücü built-in veya initramfs içinde olmalıdır.

İlk alfa için GPU passthrough, Mi 9 üzerinde cross-compile ve bulut runner gerekmez. Mi 9 yalnız kullanıcı isterse SSH terminali/test istemcisi olarak yardımcı olabilir.

## Gün sonu devri

Host/VM adı, aşama, çalışan PID, log yolu, devam komutu, disk/RAM durumu ve güvenli durdurma yöntemi kaydedilir. Kullanıcının bilgisayarı gece açık tutacağı varsayılmaz; tamamlanmış paket/aşama üzerinden devam edilebilir olmalıdır.

Kaynak: [Microsoft Hyper-V Gen1/Gen2 rehberi](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/should-i-create-a-generation-1-or-2-virtual-machine-in-hyper-v).
