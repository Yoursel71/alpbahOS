# alpbahOS — Güncel durum

Güncelleme: 21 Eylül 2026

## Şu anda neredeyiz?

alpbahOS için özel Git deposu, LFS build planı ve Hyper-V builder hazırlandı. Ubuntu Server Minimal kurulumu `alpbah-builder` VM'sinde devam ediyor. SSH bağlantısı henüz doğrulanmadı; LFS derlemesi henüz başlamadı.

## Tamamlanan işler

- x86_64 alpbahOS hedefi ve Windows'tan geçen kullanıcı deneyimi kararlaştırıldı.
- Solid varsayılan, Glass/Liquid seçilebilir tema yaklaşımı belirlendi.
- Türkçe arayüz, Türkçe Q klavye, Windows kısayolları, Atatürk masaüstü/kilit ekranı ve kaynak dostu tasarım kaydedildi.
- Private GitHub deposu ve `codex/integration` dalı hazırlandı.
- `AGENTS.md`, `CLAUDE.md`, ana plan, karar kayıtları, backlog ve tasarım dokümanları yazıldı.
- Ubuntu Server 24.04.5 amd64 ISO'su indirildi ve SHA256 doğrulandı.
- Hyper-V Gen2 builder VM oluşturuldu:
  - VM: `alpbah-builder`
  - Host: `YRSLF`
  - Ağ: `Default Switch`
  - CPU: 6 vCPU
  - RAM: önce 12 GiB planlandı; host kaynak hatası nedeniyle 4 GiB'a düşürüldü
  - Disk: 210 GiB dinamik VHDX
  - ISO: Ubuntu Server 24.04.5
- VMConnect doğru hosta bağlandı.
- Ubuntu Server Minimal kurulum ekranına ulaşıldı.
- Featured server snaps ekranında snap seçilmemesi kararlaştırıldı.
- Kullanıcı OpenSSH Server kurulumunu seçiyor.

## SSH bağlandıktan sonra yapacağımız sıra

1. Ubuntu'nun gerçekten açıldığını, hostname, kernel, RAM, CPU, disk ve ağ durumunu doğrulayacağız.
2. `lfsbuild` kullanıcısı ve SSH erişimini kontrol edeceğiz; root ile bütün build'i çalıştırmayacağız.
3. Saat dilimini `Europe/Istanbul`, locale/build locale'ını tekrar üretilebilir biçimde ayarlayacağız.
4. LFS 13.1-systemd host gereksinimlerini ve `scripts/host-check/lfs-version-check.sh` sonucunu çalıştıracağız.
5. Ubuntu builder'a yalnız gerekli geliştirme araçlarını kuracağız; masaüstü kurmayacağız.
6. alpbahOS deposunu builder'a klonlayıp commit/branch bilgisini kaydedeceğiz.
7. LFS kaynaklarını resmi `wget-list` ile `/sources` altına indirip checksum doğrulayacağız.
8. LFS çalışma alanını Ubuntu'nun sistem dosyalarından ayrı bir hedef olarak hazırlayacağız; yanlışlıkla host kökünü LFS hedefi yapmayacağız.
9. Önce saf 64-bit toolchain'i, sonra Steam/Wine için multilib kapısını ve 32-bit ELF testlerini çalıştıracağız.
10. 4 GiB RAM nedeniyle ilk build'i düşük paralellikle başlatacağız; paket bazlı süre, RAM ve hata loglarını ölçeceğiz.
11. Temel sistem boot ettikten sonra ağ, ses, grafik, Plasma/KWin, Konsole/Zsh ve Türkçe ayarlarını ekleyeceğiz.
12. `pacman/libalpm` + `pkg` prototipini, ardından Discover/PackageKit entegrasyonunu tek veritabanı ile test edeceğiz.
13. Live ISO, Gen2 UEFI ve Gen1 legacy BIOS testlerini ancak boot edilebilir temel sistem kanıtlandıktan sonra yapacağız.

## Açık durumlar

- Ubuntu kurulumu bitmeden SSH IP adresi ve bağlantısı bilinmiyor.
- 4 GiB builder ile derleme mümkün olabilir fakat yavaş olacaktır; toolchain ölçümünden sonra RAM artırma kararı verilecek.
- Claude Code ayrı worktree'de hazır, fakat önceki oturum haftalık kullanım sınırında bekliyor; değişiklik yapmış sayılmıyor.
- Gerçek NVIDIA sürücüsü, Steam, Wine, Office ve eski donanım uyumluluğu henüz test edilmedi.

## Ajan sahipliği

- Codex: Ubuntu/LFS host, toolchain, multilib, paketleme, ISO, Hyper-V ve entegrasyon.
- Claude Code: masaüstü tema token'ları, KDE/uygulama UX, kısayollar, Konsole/Zsh profili ve Windows geçiş deneyimi.
- Aynı rootfs, mount alanı ve paket veritabanına iki ajan aynı anda yazmayacak.

## Doğruluk kuralı

Kurulum ekranına ulaşmak, Ubuntu'nun kurulduğu anlamına gelmez. SSH bağlantısı, host kontrolü, LFS kaynak checksum'ı, toolchain testleri ve boot sonuçları ayrı ayrı kanıtlanacak.
