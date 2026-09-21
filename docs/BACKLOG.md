# alpbahOS — Uygulanabilir görev sırası

Plan sürümü 1.0. Roller: Codex altyapı/entegrasyon; Claude Code masaüstü/UX. `Sırada` fiilen çalıştırıldığı anlamına gelmez. Göreve başlayan ajan kendi devir kaydını günceller; ortak tabloyu entegratör birleştirir.

| ID | Sahip | Önkoşul | İş / teslim | Kabul ölçütü | Durum |
|---|---|---|---|---|---|
| PLAN-01 | Codex | Kullanıcı cevapları | Ana plan, kararlar, AGENTS/CLAUDE | Yanıtlar kapsanmış; açık teknik kapılar belli | Tamamlandı |
| REPO-01 | Codex | Git/GitHub erişimi | Private repo, main ve iki ayrı dal/worktree | Gizlilik ve uzak commit doğrulanır | Tamamlandı |
| HOST-01 | Codex | Hyper-V erişimi | Salt okunur host raporu, kaynak bütçesi, ISO manifesti | Hyper-V etkinliği, alan ve sabit ISO checksum | Tamamlandı |
| HOST-02 | Codex | HOST-01 ve yönetici VM oluşturma adımı | Gen2 builder + Linux host-check | SSH/locale/toolchain gereksinimleri geçer | Devam ediyor |
| ABI-01 | Codex | Kaynak araştırması | Eşleşen LFS/multilib revizyon ve lib32 planı | Kaynaklar sabit; ELF32/64 test tasarımı | Sırada |
| PKG-01 | Codex | HOST-02 | pacman/libalpm + test paketi ve yerel depo | Kur/güncelle/kaldır, config koruma, kilit | Başlamadı |
| PKG-02 | Codex | PKG-01 | pkg ve PackageKit/Discover sözleşmesi | CLI/GUI aynı veritabanında, güvenli güncelleme | Başlamadı |
| BUILD-01 | Codex | ABI-01, HOST-02 | Kaynak manifesti, indir/doğrula/tarif runner | Temiz yeniden deneme ve loglar | Başlamadı |
| BUILD-02 | Codex | BUILD-01 | Geçici toolchain | Kitap sırası ve ELF/linker testleri | Başlamadı |
| BUILD-03 | Codex | BUILD-02, PKG-01 | Chroot/temel LFS | Paket dosya sahipliği ve kritik testler | Başlamadı |
| BOOT-01 | Codex | BUILD-03 | Gen2 ve Gen1 boot | Hedef kernel ile giriş/ağ/reboot | Başlamadı |
| BLFS-01 | Codex | BOOT-01 | Ağ/ses/grafik/oturum bağımlılıkları | TLS/ses/renderer testleri | Başlamadı |
| UI-01 | Claude | Belgeler ve kullanım limiti sıfırlanması | Tema token'ları ve mevcut mockup eşlemesi | Türkçe, Solid varsayılan, profil farkları | Bekliyor |
| UI-02 | Claude | UI-01 | Kısayol tanımları ve kullanıcı yardımı | Çakışma listesi; Alt+Tab/Win+D dahil | Başlamadı |
| SHELL-01 | Claude | Belgeler ve kullanım limiti sıfırlanması | Zsh/Konsole profil taslağı | Öneri kabul/çalıştır ayrımı, düzeltme, Türkçe | Bekliyor |
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

- Codex: `recipes/`, `manifests/`, `scripts/`, `packaging/`, `live/`, kernel/ISO ve Linux ortamı.
- Claude: `profiles/desktop/`, `profiles/shortcuts/`, `profiles/shell/`, `branding/`, `docs/handoffs/claude/`.
- Ana plan/kararlar/görev tablosu: entegratör sahipliğinde; Claude değişikliği kendi dalından önerir.
- `pkg` tamamlama/shell profili arayüzü konusunda iki taraf yazılı sözleşme kullanır; backend'i Claude yeniden yazmaz.
- Linux rootfs ve paket deposu tek yazıcı. Ayrı Git worktree bu kilidi ortadan kaldırmaz.
- Claude ajanı ayrı worktree'de başlatıldı fakat haftalık kullanım sınırı nedeniyle değişiklik üretmedi; sınır sıfırlanınca aynı görev sürdürülecek.
- Linux kurulumu başlamadı; builder ISO'su indirme ve hash doğrulama aşamasında.
