# alpbahOS — Uygulanabilir görev sırası

Plan sürümü 1.0. Roller: Codex altyapı/entegrasyon; Claude Code masaüstü/UX. `Sırada` fiilen çalıştırıldığı anlamına gelmez. Göreve başlayan ajan kendi devir kaydını günceller; ortak tabloyu entegratör birleştirir.

| ID | Sahip | Önkoşul | İş / teslim | Kabul ölçütü | Durum |
|---|---|---|---|---|---|
| PLAN-01 | Codex | Kullanıcı cevapları | Ana plan, kararlar, AGENTS/CLAUDE | Yanıtlar kapsanmış; açık teknik kapılar belli | Tamamlandı |
| REPO-01 | Codex | Git/GitHub erişimi | Private repo, main ve iki ayrı dal/worktree | Gizlilik ve uzak commit doğrulanır | Bu tur |
| HOST-01 | Codex | Hyper-V yönetim yetkisi | Salt okunur host raporu, kaynak bütçesi | Hyper-V etkinliği, alan, ağ ve Linux ISO checksum | Tamamlandı (builder VM/SSH doğrulandı) |
| HOST-02 | Codex | HOST-01 ve kurulum görevi | Gen2 builder + host-check | SSH/locale/toolchain gereksinimleri geçer | Tamamlandı (Ubuntu 24.04 builder, SSH ve LFS build kökü) |
| VM-SSH-01 | Codex | Gen2 test imajı | OpenSSH server ve anahtar tabanlı erişimi imaja ekle | `sshd` enabled/active; kullanıcı public key’i ile dış hosttan login doğrulanır | **Gen2 test akışı geçti:** rootfs’de PAM OpenSSH/key-only policy ve `sa` authorized key var; v3 rootfs imajı boot etti, dış hosttan SSH public-key ile `sa` girişi doğrulandı. Release kapsamı değildir; dağıtım imajında gömülü anahtar/parola bulunmamalı. |
| ABI-01 | Codex | Kaynak araştırması | Eşleşen LFS/multilib revizyon ve lib32 planı | Kaynaklar sabit; ELF32/64 test tasarımı | D32/P01 kullanıcı kararıyla kapsam dışı; hiçbir 32-bit kod/build yapılmadı |
| PKG-01 | Claude | — (D31 ile motor değişti) | `alp` recipe+Flatpak+core motoru | Kur/kaldır/güncelle, bağımlılık ön kontrolü, güvenli dosya merge ve checksum | **Kod `e8b0376` main’de; rootfs’ye kuruldu.** Live Gen2 `/usr/lib/alp/alp.py` SHA-256 `7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132` beklenenle eşleşti. Htop install/remove e2e daha önce Claude’un Gen2 test imajında geçti; bu rootfs’ten üretilen v3’te yeniden çalıştırılmadı. Upgrade, bağımlılık, concurrency ve rollback testleri açık. |
| PKG-02 | Claude | PKG-01 | `alp` ve mağaza işlem sözleşmesi | CLI/GUI aynı veritabanı ve kilit; güvenli güncelleme | D31 ile Discover/PackageKit alpm yolu terk edildi; gerçek `alp` GUI işlem yolu ve rootfs GUI testi doğrulanmadı. |
| BUILD-01 | Codex | ABI-01, HOST-02 | Kaynak manifesti, indir/doğrula/tarif runner | Temiz yeniden deneme ve loglar | LFS 12.4-systemd akışıyla ilerletildi |
| BUILD-02 | Codex | BUILD-01 | Geçici toolchain | Kitap sırası ve ELF/linker testleri | Tamamlandı (geçici araçlar ve final toolchain) |
| BUILD-03 | Codex | BUILD-02, PKG-01 | Chroot/temel LFS | Paket dosya sahipliği ve kritik testler | LFS 12.4-systemd rootfs ve boot doğrulamaları mevcut; M04’ün temel paket→dosya sahipliği kaydı yok. `alp` DB tabanı boş; kurulu dosyalardan paket sahipliği çıkarsamak kanıtlanmadı. M04 kapanışından önce temel kurulum için güvenilir paket envanteri yöntemi belirlenip kayıt üretilecek. |
| BOOT-01 | Codex | BUILD-03 | BIOS/UEFI boot | BIOS ve UEFI giriş/ağ/reboot kanıtı | **Tamamlandı (M05):** BIOS/Gen1 ile UEFI/Gen2 boot, DHCP, SSH ve kontrollü reboot kanıtları kaydedildi. Gen1 test VM'i sonradan silindi; bu sonuçlar tarihsel kanıttır. Güncel VM testleri Gen2'de sürüyor. |
| BLFS-01 | Codex | BOOT-01 | Ağ/ses/grafik/oturum bağımlılıkları | TLS/ses/renderer testleri | Ağ/TLS, PAM/logind, pkexec e2e, Mesa softpipe EGL readback, ALSA loopback ve PipeWire null-sink PCM kanıtı var. Gen2’de getty/resolved ve KWin user unit/drop-in görünürlüğü doğrulandı. Gerçek grafik oturumu ve fiziksel ses aygıtı yok; BLFS-01 kısmi. |
| UI-01 | Claude | Belgeler | Tema token'ları ve mevcut mockup eşlemesi | Türkçe, Solid varsayılan, profil farkları | Statik taslak tamamlandı; kurulu Plasma'da tema doğrulanmadı (`001-desktop-bootstrap.md`). |
| UI-02 | Claude | UI-01 | Kısayol tanımları ve kullanıcı yardımı | Çakışma listesi; Alt+Tab/Win+D dahil | Statik kısayol analizi ve yardım taslağı tamamlandı; KWin kısayol kaydı/Hyper-V tuş aktarımı gerçek oturumda doğrulanmadı (`002-ui02-ui03.md`). |
| SHELL-01 | Claude | Belgeler | Zsh/Konsole profil taslağı | Öneri kabul/çalıştır ayrımı, düzeltme, Türkçe | Statik taslak tamamlandı (`001-desktop-bootstrap.md`); Zsh paketi ve oturum senaryosu test edilmedi. |
| UI-03 | Claude | UI-01 | Atatürk tema varlık planı ve kaynak kaydı | Lisans/kaynak, kırpım/kontrast, logo korunması | Taslak ve kaynak notu var; fotoğraf dalda eklendi, fakat görselin çözünürlük/kırpım/kontrast ve lisans kabulü ürün testinde doğrulanmadı. |
| DESKTOP-01 | Codex | BLFS-01, UI/SHELL girdileri | LFS içinde Plasma oturumu | Temiz kullanıcı, PAM/logind, DRM-seat ve KWin başlangıç yolu | **KWin P0 unit gate geçti; Plasma henüz başlatılmadı.** Rootfs PAM/Shadow/login/sa ve key-only SSH mevcut. Gen2 v3’de `systemctl --user cat/show plasma-kwin_wayland.service` etkin ExecStart’ın `--xwayland` olmadan çalışacağını gösterdi. tty1’de admin login ve `loginctl` seat0/PAM kanıtı kullanıcıdan bekleniyor; gerçek DRM-seat Plasma testi bundan sonra. |
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
