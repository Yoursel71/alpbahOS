# alpbahOS — İş kaydı

## Durum: 21 Eylül 2026

Kullanıcı cevapları ana plan 1.0'a işlendi. Özel repo ve ayrı Codex/Claude çalışma kolları kuruldu. Hyper-V builder VM oluşturuldu; Ubuntu Server Minimal kurulumu ve OpenSSH kurulumu sürüyor. SSH ve LFS derlemesi henüz doğrulanmadı.

| İş | Sahip | Durum | Kanıt / sonraki adım |
|---|---|---|---|
| PLAN-01: Kullanıcı hedeflerini toplama | Codex | Tamamlandı | DECISIONS.md |
| PLAN-02: Ana plan | Codex | 1.0 hazır | MASTER_PLAN.md |
| PLAN-03: Ortak ajan ve Claude talimatları | Codex | Hazır | AGENTS.md, CLAUDE.md, CLAUDE_START.md |
| REPO-01: Özel Git deposu | Codex | Tamamlandı | https://github.com/Yoursel71/alpbahOS; `main`, `codex/integration`, `claude/desktop-bootstrap` uzak dalları doğrulandı |
| HOST-01: Windows/Hyper-V ön kontrolü | Codex | Ön kontrol geçti | Hyper-V ve servisler açık; 23,9 GiB RAM; F: üzerinde yaklaşık 350 GiB boş alan; JSON raporu üretildi |
| HOST-02: Linux builder | Codex | Ubuntu kurulumu sürüyor | `alpbah-builder` Gen2 VM oluşturuldu; 6 vCPU, 4 GiB RAM, 210 GiB VHDX, `Default Switch`; Ubuntu Minimal/OpenSSH kurulumu devam ediyor |
| ABI-01: Steam multilib tasarımı | Codex | İlke kararı alındı | ADR 0002 hazır; LFS 13.1 ile eşleşen kaynak revizyonu sabitlenecek |
| DESKTOP-01: Masaüstü prototipi | Claude rol planı / Codex entegrasyon | Bekliyor | Claude Code kuruldu ve hesap doğrulandı; haftalık kullanım sınırı 20:00'a kadar yeni çalışmayı engelliyor |

## Ortam sahipliği

- LFS rootfs: henüz yok; Ubuntu builder kurulup SSH doğrulanınca Codex tek yazarı olacak.
- Tema prototip ortamı: henüz yok.
- Claude Code için `C:\alpbahOS-claude` ayrı Git worktree ve `claude/desktop-bootstrap` dalı hazırlandı.
- Eşzamanlı derleme veya ortak dosya değişikliği başlatılmadı.

## Bu turdaki kontrol

- Mevcut proje dosyaları ve ilgili kök talimat dosyaları incelendi.
- Kullanıcı tarafından kabul edilen tercihler ile devredilmiş teknik seçimler ayrıldı.
- LFS/BLFS, KDE, Zsh, Valve, Microsoft ve paket altyapısının birincil kaynakları incelendi.
- Standart LFS'nin saf 64-bit oluşu ve Steam'in 32-bit kullanıcı alanı ihtiyacı planlandı.
- F: sürücüsünün SATA HDD olduğu tespit edildi. Hyper-V özelliği, komutları ve üç gerekli servis doğrulandı. VM oluşturma mevcut oturum yönetici olmadığı için bilerek başlatılmadı.
- GitHub repo görünürlüğü private olarak doğrulandı. Kimlik bilgileri repoya yazılmadı.
- Host raporu `F:\alpbahOS-build\reports\host-preflight.json` konumuna yazıldı; engelleyici kontrol hatası yok.
- Resmi Ubuntu Server 24.04.5 amd64 ISO adresi ve SHA256 değeri manifestte sabitlendi.
- Ubuntu ISO indirildi ve tam SHA256 doğrulaması geçti: `97f3d7ffb032c3eb3b23d2c8be9cc76e60c2c1f2c0146ba5ba9fe01cafae0fd8`.
- Claude Code 2.1.278 kuruldu ve Claude hesabı doğrulandı. UI-01/SHELL-01 oturumu kullanım sınırı nedeniyle kod üretmeden beklemeye geçti.
- `alpbah-builder` VM'si oluşturuldu. 12 GiB RAM ile başlatma host kaynakları nedeniyle başarısız olunca VM 4 GiB RAM'a ayarlandı ve yeniden başlatıldı.
- VMConnect'in `YRSLF` hostuna bağlandığı görüldü. Ubuntu Server Minimal kurulum ekranı açıldı; featured snap seçilmedi, OpenSSH Server kurulumu seçildi.
- SSH bağlantısı, Linux boot, LFS kaynak checksum'ı, paket işlemleri ve GPU testleri henüz doğrulanmadı.

## Sonraki adım

Ubuntu kurulumu bitince SSH adresini doğrula. Ubuntu host içinde LFS 13.1 sürüm kontrolünü, sonra resmi kaynak indirme/doğrulamasını çalıştır. Claude sınırı sıfırlandığında mevcut ayrı worktree'de UI-01/SHELL-01 yeniden başlatılabilir.
