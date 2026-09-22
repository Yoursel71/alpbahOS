# alpbahOS — Uygulanabilir görev sırası

Plan sürümü 1.0. Roller: Codex altyapı/entegrasyon; Claude Code masaüstü/UX. `Sırada` fiilen çalıştırıldığı anlamına gelmez. Göreve başlayan ajan kendi devir kaydını günceller; ortak tabloyu entegratör birleştirir.

| ID | Sahip | Önkoşul | İş / teslim | Kabul ölçütü | Durum |
|---|---|---|---|---|---|
| PLAN-01 | Codex | Kullanıcı cevapları | Ana plan, kararlar, AGENTS/CLAUDE | Yanıtlar kapsanmış; açık teknik kapılar belli | Tamamlandı |
| REPO-01 | Codex | Git/GitHub erişimi | Private repo, main ve iki ayrı dal/worktree | Gizlilik ve uzak commit doğrulanır | Bu tur |
| HOST-01 | Codex | Hyper-V yönetim yetkisi | Salt okunur host raporu, kaynak bütçesi | Hyper-V etkinliği, alan, ağ ve Linux ISO checksum | Tamamlandı (builder VM/SSH doğrulandı) |
| HOST-02 | Codex | HOST-01 ve kurulum görevi | Gen2 builder + host-check | SSH/locale/toolchain gereksinimleri geçer | Tamamlandı (Ubuntu 24.04 builder, SSH ve LFS build kökü) |
| ABI-01 | Codex | Kaynak araştırması | Eşleşen LFS/multilib revizyon ve lib32 planı | Kaynaklar sabit; ELF32/64 test tasarımı | Sırada |
| PKG-01 | Claude | — (D31 ile motor değişti) | `alp` (recipe+flatpak+core) — prototip hazır, incelendi, 3 bulgu düzeltildi | Kur/kaldır, tek db+kilit, checksum zorunlu — **dürüst eksik:** bağımlılık çözümü, config koruma yok (proposal §6) | Prototip tamam (`claude/desktop-bootstrap`, ayrı repo [alpbahOS-alp](https://github.com/Yoursel71/alpbahOS-alp)); gerçek Linux ortamında uçtan uca **test edilmedi** |
| PKG-02 | Claude | PKG-01 | `alp` ve mağaza (Discover/PackageKit) sözleşmesi | CLI/GUI aynı veritabanında, güvenli güncelleme | **Başlamadı** — proposal §6'da açıkça "Yok" işaretli, PackageKit backend'i yazılmadı |
| BUILD-01 | Codex | ABI-01, HOST-02 | Kaynak manifesti, indir/doğrula/tarif runner | Temiz yeniden deneme ve loglar | LFS 12.4-systemd akışıyla ilerletildi |
| BUILD-02 | Codex | BUILD-01 | Geçici toolchain | Kitap sırası ve ELF/linker testleri | Tamamlandı (geçici araçlar ve final toolchain) |
| BUILD-03 | Codex | BUILD-02, PKG-01 | Chroot/temel LFS | Paket dosya sahipliği ve kritik testler | Tamamlandı (LFS 12.4-systemd temel rootfs) |
| BOOT-01 | Codex | BUILD-03 | Gen2 ve Gen1 boot | Hedef kernel ile giriş/ağ/reboot | M1/Gen2 geçti: giriş, DHCP/ping ve kontrollü yeniden açılış doğrulandı; Gen1 kolu bekliyor |
| BLFS-01 | Codex | BOOT-01 | Ağ/ses/grafik/oturum bağımlılıkları | TLS/ses/renderer testleri | Başlamadı |
| UI-01 | Claude | Belgeler | Tema token'ları ve mevcut mockup eşlemesi | Türkçe, Solid varsayılan, profil farkları | Sırada |
| UI-02 | Claude | UI-01 | Kısayol tanımları ve kullanıcı yardımı | Çakışma listesi; Alt+Tab/Win+D dahil | Başlamadı |
| SHELL-01 | Claude | Belgeler | Zsh/Konsole profil taslağı | Öneri kabul/çalıştır ayrımı, düzeltme, Türkçe | Sırada |
| UI-03 | Claude | UI-01 | Atatürk tema varlık planı ve kaynak kaydı | Görsel kaynağı, kırpım/kontrast, logo korunması | Başlamadı |
| DESKTOP-01 | Codex | BLFS-01, UI/SHELL girdileri | LFS içinde Plasma oturumu | Temiz kullanıcı, düşük kaynak ölçümü | Başlamadı |
| APPS-01 | Codex + Claude inceleme | DESKTOP-01 | Hazır temel uygulama profili | Dosya ilişkileri ve günlük senaryolar | Başlamadı |
| COMPAT-01 | Codex | Multilib + grafik | Wine/Steam/Proton doğrulaması | 32/64-bit grafik; bir test oyunu | Başlamadı |
| OFFICE-01 | Claude plan / Codex test | Wine + lisanslı medya | Office sürüm bazlı rapor | Kur/aç/kaydet/yazdır; bilinen sorunlar | Başlamadı |
| PERF-01 | Claude + Codex | DESKTOP-01 | RAM/frametime/efekt karşılaştırması | Solid bütçesi; Glass ölçümü; Liquid deney raporu | Başlamadı |
| LIVE-01 | Codex | BOOT/APPS/PERF | Hybrid canlı ISO | Gen1/Gen2, ağ ve kurulumsuz oturum | Başlamadı |
| ALPHA-01 | Codex + Claude inceleme | LIVE-01 | 0.2-alpha yerel paket | Test raporu/checksum/eksikler | Başlamadı |
| INSTALL-01 | Codex | ALPHA-01 | Calamares ve offline paketler | Boş sanal disk, BIOS/UEFI kurulumu | Başlamadı |
| INSTALL-02 | Codex | INSTALL-01 | Windows yanında kurulum/kurtarma | Sanal disklerde Windows korunur | Başlamadı |
| BETA-01 | Codex + kullanıcı | INSTALL-02 | Gerçek donanım beta | Cihaz listesi ve yetkili kurulum testleri | Başlamadı |

## Eşzamanlı çalışma sözleşmesi

- Codex: `recipes/` (LFS/BLFS build tarifleri — `alp`'in kendi tarifleriyle karıştırılmaz), `manifests/`, `scripts/`, `packaging/`, `live/`, kernel/ISO ve Linux ortamı.
- Claude: `profiles/desktop/`, `profiles/shortcuts/`, `profiles/shell/`, `branding/`, `docs/handoffs/claude/`, **paket motoru (`alp` — bu repoda `docs/handoffs/claude/alp-prototype/`, gerçek recipes/index/core içeriği ayrı repoda: [alpbahOS-alp](https://github.com/Yoursel71/alpbahOS-alp))**.
- Ana plan/kararlar/görev tablosu: entegratör sahipliğinde; Claude değişikliği kendi dalından önerir. **İstisna (21 Eylül 2026, D31):** paket motoru pivotu kullanıcının doğrudan talimatıyla main'e işlendi.
- `alp` CLI semantiği (eski ad `pkg`) artık Claude'un sahipliğinde; Codex'in görevi `alp`'i (saf Python, stdlib-only) LFS temel sistemine yerleştirmek ve BLFS grafik/oturum zincirini ilerletmek.
- Linux rootfs ve paket deposu tek yazıcı. Ayrı Git worktree bu kilidi ortadan kaldırmaz. `alp`'in recipes/index/core içeriği ayrı repoda olduğu için ana repodaki `recipes/`/`packaging/` (Codex) ile dosya çakışması yok.
- Mevcut konu plan/başlangıç paketi hazırlığıdır. Ajan süreçleri ve Linux kurulumları henüz başlatılmadı.
