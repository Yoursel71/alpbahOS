# alpbahOS — Hyper-V builder başlangıcı

Bu belge, LFS derlemesinin yapılacağı Ubuntu builder sanal makinesini tekrar üretilebilir biçimde hazırlamak içindir. Hedef işletim sistemi alpbahOS'tur; Ubuntu yalnızca temiz ve sabitlenmiş derleme hostudur.

## Sabit kaynak

- ISO: Ubuntu Server 24.04.5 LTS amd64
- Yerel konum: `F:\alpbahOS-build\iso\ubuntu-24.04.5-live-server-amd64.iso`
- Beklenen SHA256: `97f3d7ffb032c3eb3b23d2c8be9cc76e60c2c1f2c0146ba5ba9fe01cafae0fd8`
- Makine tanımı: `manifests/host/ubuntu-builder.json`

ISO, sanal makine oluşturulmadan önce SHA256 ile doğrulanır. `New-AlpbahBuilder.ps1` hash uyuşmazsa hiçbir VM/VHDX oluşturmaz.

## Kaynak bütçesi

| Kaynak | Değer |
|---|---:|
| Hyper-V nesli | Gen 2 / UEFI |
| İşlemci | 6 sanal çekirdek |
| Bellek | 12 GiB, dinamik bellek kapalı |
| Disk | 210 GiB dinamik VHDX |
| Derleme paralelliği | İlk ölçüm için `-j4` |
| Otomatik checkpoint | Kapalı |

Gen 2 yalnızca builder içindir. alpbahOS canlı medyası daha sonra ayrı Gen 2 UEFI ve Gen 1 legacy BIOS test makinelerinde sınanacaktır.

## Sıra

1. Normal PowerShell oturumunda host raporunu üret:

   ```powershell
   & C:\alpbahOS\scripts\host-check\Test-AlpbahHost.ps1
   ```

2. ISO hash'ini doğrula:

   ```powershell
   (Get-FileHash F:\alpbahOS-build\iso\ubuntu-24.04.5-live-server-amd64.iso -Algorithm SHA256).Hash
   ```

3. Hyper-V Manager'da kullanılacak sanal anahtarın adını öğren. VM oluşturma komutunu **yönetici PowerShell** içinde ve doğru anahtar adıyla çalıştır:

   ```powershell
   & C:\alpbahOS\scripts\hyperv\New-AlpbahBuilder.ps1 `
     -UbuntuIso F:\alpbahOS-build\iso\ubuntu-24.04.5-live-server-amd64.iso `
     -UbuntuIsoSha256 97f3d7ffb032c3eb3b23d2c8be9cc76e60c2c1f2c0146ba5ba9fe01cafae0fd8 `
     -SwitchName 'Default Switch' `
     -Confirm:$false
   ```

4. Betik VM'yi otomatik başlatmaz. Hyper-V Manager'da ilk açılışı yap ve Ubuntu'yu yalnızca builder VHDX'e kur.
5. Ubuntu içinde repoyu klonla ve `scripts/host-check/lfs-version-check.sh` çalıştır. Bütün satırlar `OK`, hata sayısı `0` olmalıdır.
6. LFS kaynaklarını yalnızca builder içinde indir ve resmi checksum ile doğrula:

   ```bash
   sudo mkdir -p /sources
   sudo chown "$USER" /sources
   /path/to/alpbahOS/scripts/sources/fetch-lfs-sources.sh /sources
   ```

   Kaynak sürümü ve doğrulama politikası `manifests/sources/lfs-13.1-systemd.json` dosyasındadır.

## Kurulum tercihleri

- Minimum Ubuntu Server kurulumu; masaüstü paketi kurulmaz.
- OpenSSH Server etkinleştirilir.
- Saat dilimi `Europe/Istanbul`; builder komut çıktılarında tekrar üretilebilirlik için `LC_ALL=C` kullanılır.
- LFS çalışma alanı ayrı bir dosya sistemi veya loopback build diski olarak hazırlanır; host kök dizini doğrudan LFS hedefi yapılmaz.
- Checkpoint yalnızca bilinçli kilometre taşlarında alınır ve 300 GB bütçesi nedeniyle iş bitince temizlenir.

## Güvenlik ve geri dönüş

- Betik aynı adlı VM veya VHDX varsa üzerine yazmaz.
- ISO hash'i yanlışsa işlem durur.
- Oluşturma sırasında yarım kalırsa betik olası hedef yollarını bildirir; otomatik silme yapmaz.
- VM içindeki LFS rootfs tek yazarlıdır. Codex ve Claude aynı rootfs üzerinde eşzamanlı paket derlemez.
