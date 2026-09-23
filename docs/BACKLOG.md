# alpbahOS — Uygulanabilir görev sırası

Plan sürümü 1.0. Roller: Codex altyapı/entegrasyon; Claude Code masaüstü/UX. `Sırada` fiilen çalıştırıldığı anlamına gelmez. Göreve başlayan ajan kendi devir kaydını günceller; ortak tabloyu entegratör birleştirir.

| ID | Sahip | Önkoşul | İş / teslim | Kabul ölçütü | Durum |
|---|---|---|---|---|---|
| PLAN-01 | Codex | Kullanıcı cevapları | Ana plan, kararlar, AGENTS/CLAUDE | Yanıtlar kapsanmış; açık teknik kapılar belli | Tamamlandı |
| REPO-01 | Codex | Git/GitHub erişimi | Private repo, main ve iki ayrı dal/worktree | Gizlilik ve uzak commit doğrulanır | Bu tur |
| HOST-01 | Codex | Hyper-V yönetim yetkisi | Salt okunur host raporu, kaynak bütçesi | Hyper-V etkinliği, alan, ağ ve Linux ISO checksum | Tamamlandı (builder VM/SSH doğrulandı) |
| HOST-02 | Codex | HOST-01 ve kurulum görevi | Gen2 builder + host-check | SSH/locale/toolchain gereksinimleri geçer | Tamamlandı (Ubuntu 24.04 builder, SSH ve LFS build kökü) |
| VM-SSH-01 | Codex | Geliştirme/test imajı | OpenSSH server ve anahtar tabanlı erişimi imaja ekle | `sshd` enabled/active; kullanıcı public key'i ile dış hosttan login doğrulanır | **Kısmi:** `/mnt/lfs` rootfs'sinde OpenSSH 10.0p1 PAM ile derlendi/kuruldu; key-only yapılandırma parse edildi, `sshd.service` enabled, `sa` public key provision edildi. Test host key'leri imajda bırakılmadı; ilk boot unit'i `ssh-keygen -A` çalıştıracak. Dış host SSH doğrulaması için Gen2 VHDX/VM henüz yok; Gen1 adresi timeout. M09+ dağıtım çıktıları gömülü kullanıcı anahtarı/parolası olmadan kalmalı.
| ABI-01 | Codex | Kaynak araştırması | Eşleşen LFS/multilib revizyon ve lib32 planı | Kaynaklar sabit; ELF32/64 test tasarımı | D32/P01 kullanıcı kararıyla kapsam dışı; hiçbir 32-bit kod/build yapılmadı |
| PKG-01 | Claude | — (D31 ile motor değişti) | `alp` recipe+Flatpak+core motoru | Kur/kaldır/güncelle, bağımlılık ön kontrolü, güvenli dosya merge ve checksum | **Prototip dalı `e8b0376` ile main'e merge edildi.** Seviye 1/2 kontroller ve ortak install/upgrade merge yolu kodda mevcut. Builder rootfs'deki motor SHA-256 `d06c72…` yeni commit `e8b0376`'nın SHA-256'sı `7b2998…` ile eşleşmiyor; eski rootfs motorunda remove/upgrade kullanımı kapalı. Güncel kurulum ve rootfs testi açık. |
| PKG-02 | Claude | PKG-01 | `alp` ve mağaza işlem sözleşmesi | CLI/GUI aynı veritabanı ve kilit; güvenli güncelleme | PackageKit backend taslağı dal ile main'e geldi; gerçek Discover entegrasyonu ve rootfs GUI işlem testi doğrulanmadı. |
| BUILD-01 | Codex | ABI-01, HOST-02 | Kaynak manifesti, indir/doğrula/tarif runner | Temiz yeniden deneme ve loglar | LFS 12.4-systemd akışıyla ilerletildi |
| BUILD-02 | Codex | BUILD-01 | Geçici toolchain | Kitap sırası ve ELF/linker testleri | Tamamlandı (geçici araçlar ve final toolchain) |
| BUILD-03 | Codex | BUILD-02, PKG-01 | Chroot/temel LFS | Paket dosya sahipliği ve kritik testler | LFS 12.4-systemd rootfs hazır; M1 doğrulamaları mevcut, ancak `/mnt/lfs/var/lib/alp/db.json` boş olduğundan ana plan §10.1 paket sahipliği çıkışı tamamlanmamış |
| BOOT-01 | Codex | BUILD-03 | Gen2 ve Gen1 boot | Güncel hedef kernel ile BIOS/UEFI giriş/ağ/reboot | M1 eski kernel Gen2 geçti; M1 Gen1 DHCP/ping/reboot geçti; M2 adayı Gen1 login/DHCP/kontrollü reboot geçti. M2'nin yeni `CONFIG_DRM_HYPERV=y` kernel'i Gen2/UEFI'de açılmadı; BOOT-01/M05 bu kernel kapsamı için açık. |
| BLFS-01 | Codex | BOOT-01 | Ağ/ses/grafik/oturum bağımlılıkları | TLS/ses/renderer testleri | Ağ/TLS, PAM/logind, pkexec e2e, Mesa softpipe EGL readback, ALSA loopback, PipeWire null-sink graph, QtBase/QML, QtWayland ve KWin/Plasma bileşen build'leri geçti. Fiziksel audio ve gerçek Wayland oturumu yok; BLFS-01 kısmi |
| UI-01 | Claude | Belgeler | Tema token'ları ve mevcut mockup eşlemesi | Türkçe, Solid varsayılan, profil farkları | Statik taslak tamamlandı; kurulu Plasma'da tema doğrulanmadı (`001-desktop-bootstrap.md`). |
| UI-02 | Claude | UI-01 | Kısayol tanımları ve kullanıcı yardımı | Çakışma listesi; Alt+Tab/Win+D dahil | Statik kısayol analizi ve yardım taslağı tamamlandı; KWin kısayol kaydı/Hyper-V tuş aktarımı gerçek oturumda doğrulanmadı (`002-ui02-ui03.md`). |
| SHELL-01 | Claude | Belgeler | Zsh/Konsole profil taslağı | Öneri kabul/çalıştır ayrımı, düzeltme, Türkçe | Statik taslak tamamlandı (`001-desktop-bootstrap.md`); Zsh paketi ve oturum senaryosu test edilmedi. |
| UI-03 | Claude | UI-01 | Atatürk tema varlık planı ve kaynak kaydı | Lisans/kaynak, kırpım/kontrast, logo korunması | Taslak ve kaynak notu var; fotoğraf dalda eklendi, fakat görselin çözünürlük/kırpım/kontrast ve lisans kabulü ürün testinde doğrulanmadı. |
| DESKTOP-01 | Codex | BLFS-01, UI/SHELL girdileri | LFS içinde Plasma oturumu | Temiz kullanıcı, PAM/logind, DRM-seat ve KWin başlangıç yolu | **P0 açık; Plasma testi duraklatıldı.** Rootfs'de PAM/Shadow/login, `sa`, `pam_systemd` ve KWin Wayland-only drop-in kuruldu. SSH server ve key provision edildi; `alp --help`/`alp list` geçti fakat `alp.py` hash uyuşmazlığı açık. Guest SSH timeout ve Hyper-V yönetim izni reddi nedeniyle Gen2 VHDX/boot testi yapılamadı. TTY1/PAM live guest kanıtı ve gerçek DRM-seat Plasma oturumu olmadan Plasma testi başlatılmayacak.
| APPS-01 | Codex + Claude inceleme | DESKTOP-01 | Hazır temel uygulama profili | Dosya ilişkileri ve günlük senaryolar | Başlamadı |
| COMPAT-01 | Codex | D22/D32 kullanıcı kararı + grafik | Wine/Steam/Proton doğrulaması | Steam istemcisi ve Windows 32/64-bit testleri | **Açık kullanıcı sorusu:** D22 Steam/Wine isteği D32 multilib'siz saf 64-bit kararıyla çelişiyor. Wine 11 yeni WoW64 ile 32-bit Windows uygulamalarını 32-bit Unix kütüphaneleri olmadan çalıştırabilir; Valve Steam Linux istemcisi hâlâ 32-bit glibc/grafik sürücüleri istiyor. Kullanıcı kararı olmadan uyumluluk iddiası/test planı sabitlenmeyecek. |
| SCREENLOCK-01 | Codex | P0 masaüstü zinciri + kullanıcı build tercihi | KScreenLocker'ı Wayland oturumuna geri getir | Ekran kilitleme/geri açma, Atatürk varsayılan kilit teması | `KWIN_BUILD_SCREENLOCKER=OFF`; Qt XCB/X11 greeter bağımlılıkları ve gerçek test henüz yok. D09 ile uyumsuz; DECISIONS'ta seçenek/maliyet açık. |
| IMAGE-01 | Codex | M09 dağıtım imajı | Dağıtım hijyeni/provisioning | İlk boot'ta benzersiz machine-id ve SSH host keys; gömülü public key/parola yok | Açık. Şimdiki `fa29d476…` yalnız geliştirme/test imajı olarak işaretlenmeli; M09+ dağıtım kapsamı. |
| OFFICE-01 | Claude plan / Codex test | Wine + lisanslı medya | Office sürüm bazlı rapor | Kur/aç/kaydet/yazdır; bilinen sorunlar | Başlamadı |
| PERF-01 | Claude + Codex | DESKTOP-01 | RAM/frametime/efekt karşılaştırması | Solid bütçesi; Glass ölçümü; Liquid deney raporu | Başlamadı |
| LIVE-01 | Codex | BOOT/APPS/PERF | Hybrid canlı ISO | Gen1/Gen2, ağ ve kurulumsuz oturum | Başlamadı |
| ALPHA-01 | Codex + Claude inceleme | LIVE-01 | 0.2-alpha yerel paket | Test raporu/checksum/eksikler | Başlamadı |
| INSTALL-01 | Codex | ALPHA-01 | Calamares ve offline paketler | Boş sanal disk, BIOS/UEFI kurulumu | Başlamadı |
| INSTALL-02 | Codex | INSTALL-01 | Windows yanında kurulum/kurtarma | Sanal disklerde Windows korunur | Başlamadı |
| BETA-01 | Codex + kullanıcı | INSTALL-02 | Gerçek donanım beta | Cihaz listesi ve yetkili kurulum testleri | Başlamadı |

## Eşzamanlı çalışma sözleşmesi

`F:\alpbahOS-build\artifacts\alpbahOS-m2-ssh-gen1.vhdx` (SHA-256 `fa29d47608a4444e043a3cbfa26753fd32a3c7e0b2078179dbcd852eab322c78`) eskidir; Claude'un karşılaştırmasına göre rootfs'de bulunan PAM `login`/Shadow ve Plasma başlatma düzeltmelerini içermez. Bu turda salt okunur disk karşılaştırması için Hyper-V izni alınamadı. Bu yalnız geliştirme/test VHDX'idir; yeni imaj yalnız doğrulanmış `/mnt/lfs` rootfs'sinden üretilir.

- Codex: `recipes/` (LFS/BLFS build tarifleri — `alp`'in kendi tarifleriyle karıştırılmaz), `manifests/`, `scripts/`, `packaging/`, `live/`, kernel/ISO ve Linux ortamı.
- Claude: `profiles/desktop/`, `profiles/shortcuts/`, `profiles/shell/`, `branding/`, `docs/handoffs/claude/`, **paket motoru (`alp` — bu repoda `docs/handoffs/claude/alp-prototype/`, gerçek recipes/index/core içeriği ayrı repoda: [alpbahOS-alp](https://github.com/Yoursel71/alpbahOS-alp))**.
- Ana plan/kararlar/görev tablosu: entegratör sahipliğinde; Claude değişikliği kendi dalından önerir. **İstisna (21 Eylül 2026, D31):** paket motoru pivotu kullanıcının doğrudan talimatıyla main'e işlendi.
- `alp` CLI semantiği (eski ad `pkg`) artık Claude'un sahipliğinde; Codex'in görevi `alp`'i (saf Python, stdlib-only) LFS temel sistemine yerleştirmek ve BLFS grafik/oturum zincirini ilerletmek.
- Linux rootfs ve paket deposu tek yazıcı. Ayrı Git worktree bu kilidi ortadan kaldırmaz. `alp`'in recipes/index/core içeriği ayrı repoda olduğu için ana repodaki `recipes/`/`packaging/` (Codex) ile dosya çakışması yok.
- Mevcut konu plan/başlangıç paketi hazırlığıdır. Ajan süreçleri ve Linux kurulumları henüz başlatılmadı.
