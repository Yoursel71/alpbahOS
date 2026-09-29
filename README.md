# alpbahOS

![alpbahOS logosu](docs/assets/alpbahOS-logo.png)

Windows'tan geçenler için kolay, Türkçe, kişiselleştirilebilir ve kaynak kullanımına dikkat eden LFS tabanlı x86_64 masaüstü projesi.

**Durum (29 Eylül 2026):** M1 temel sistem tamamlandı: LFS 12.4-systemd tabanı BIOS/UEFI emülasyonunda ve Hyper-V Gen2 üzerinde gerçek kernel, giriş istemi, DHCP ağı ve kontrollü yeniden başlatmayla doğrulandı (Gen1 sonuçları tarihsel kanıttır). M07'de Gen2 test imajında gerçek Plasma Wayland masaüstü ve paneli görsel olarak doğrulandı (25 Eylül). M08 (tema, Atatürk duvar kâğıdı, Windows kısayolları, Glass, uygulama profili) dosya düzeyinde hazır; gerçek oturum düzeltmeleri sürüyor. M09 için önyüklenebilir bir test ISO'su üretildi (QEMU BIOS/UEFI'de login istemine kadar); kabulü açık. M10 (alfa) başladı. Kurucu (Calamares) ve gerçek donanım testi henüz yok. Aşama aşama durum ve kanıt sınırları: [CURRENT.md](CURRENT.md). Ana geliştirme/test ortamı 29 Eylül 2026'dan itibaren Fedora + QEMU/KVM'dir (D36); Hyper-V kanıtları tarihsel kalır.

Özel kaynak deposu: [Yoursel71/alpbahOS](https://github.com/Yoursel71/alpbahOS).

## Belgeler

- [Güncel durum](CURRENT.md) ve [yeni oturum devri](docs/NEW_SESSION_HANDOFF.md)
- [Ana plan](docs/MASTER_PLAN.md)
- [Kullanıcı kararları ve teknik seçimler](docs/DECISIONS.md)
- [Görev sırası ve sahiplik](docs/BACKLOG.md)
- [Hyper-V ortam planı](docs/HYPERV_PLAN.md)
- [Ortak ajan kuralları](AGENTS.md)
- [Claude talimatları](CLAUDE.md) ve [ilk görev](docs/CLAUDE_START.md)
- [İş kaydı](docs/WORKLOG.md) ve [Claude devir belgeleri](docs/handoffs/claude/)
- [M01 önyükleme doğrulaması](docs/M1_BOOT_VERIFICATION.md)
- [Tasarım referansı](docs/alpbahOS-design-mockups.md)

Başlangıç seçimleri: LFS/BLFS, KDE Plasma/KWin, Konsole/Zsh, `alp` paket motoru, grafik mağaza, Solid/Glass profilleri, Atatürk masaüstü/kilit ekranı, Türkçe Q. Sistem yalnız 64-bit'tir (D32, D35): 32-bit kullanıcı alanı/multilib kapsam dışı, Steam istemcisi desteklenmez, Wine yalnız WoW64 moduyla değerlendirilir.

Önce Hyper-V masaüstü ve Legacy+UEFI canlı ISO; sonra Calamares ile grafik/offline/Windows yanında kurulum. Düşük RAM bütçesi ve sürücü uyumluluğu test kapılarıdır.

Kaynak ve belgeler Git'te; ISO, VHDX, rootfs ve build cache'i yerelde tutulur. Bulut build/depolama kullanılmaz. Üçüncü taraf bileşenler kendi lisanslarını korur; proje özgün kodunun yayın lisansı genel dağıtım öncesinde belirlenecek.
