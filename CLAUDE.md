# alpbahOS — Claude çalışma başlangıcı

Önce kökteki `AGENTS.md` dosyasını oku ve uygula. Ortak ürün ve çalışma kuralları oradadır; burada ikinci, çelişen bir kural seti oluşturma.

## Okuma sırası

1. `AGENTS.md`
2. `docs/DECISIONS.md`
3. `docs/MASTER_PLAN.md`
4. `docs/WORKLOG.md`
5. Görsel bir görev için `docs/alpbahOS-design-mockups.md` ve `docs/assets/alpbahOS-logo.png`

## Güncel bağlam

- Ana plan 1.0 hazır. Hyper-V builder VM oluşturuldu; Ubuntu Server Minimal kurulumu ve OpenSSH kurulumu sürüyor. Çalışır alpbahOS dağıtımı veya tamamlanmış toolchain yok.
- LFS tabanı derlenecek, hazır açık kaynak masaüstü/uygulamalar özelleştirilecek.
- Kullanıcı Windows'tan geçenler için kolay masaüstü, terminal önerileri, basit paket işlemleri, Windows kısayolları, Atatürk görselleri ve güçlü cihazlarda cam görünümü istiyor.
- Başlangıç stack'i KDE/KWin, Konsole/Zsh, pacman/libalpm + pkg + Discover/PackageKit. Entegrasyon deneyi geçmeden çalışan kabul etme.
- Claude Code kullanılacak; ayrı çalışma ağacı `C:\alpbahOS-claude`, dal `claude/desktop-bootstrap`. Başka hostta clone ve aynı görev sözleşmeleri kullanılır.
- Hyper-V, 300 GB yerel alan, Türkçe Q, düşük RAM ve BIOS+UEFI hedefleri sabittir. Kullanıcı günde 1–2 saat ayırır.

## Güncel yürütme özeti

Güncel durumun tek referansı kökteki `CURRENT.md` dosyasıdır. Aşağıdaki özet, Claude oturumunun gerçek bağlamını korumak için burada da tutulur.

- `alpbahOS` x86_64 LFS projesi için private repo, `codex/integration` dalı ve `C:\alpbahOS-claude` worktree hazırlandı.
- Ubuntu Server 24.04.5 amd64 ISO'su indirildi ve SHA256 doğrulandı.
- `alpbah-builder` Hyper-V Gen2 VM'si `YRSLF` hostunda `Default Switch` ile oluşturuldu. VM 6 vCPU, 4 GiB RAM ve 210 GiB dinamik VHDX kullanıyor.
- Başlangıçtaki 12 GiB RAM isteği host kaynakları nedeniyle başarısız oldu; VM 4 GiB'a indirildi. Derleme sırasında düşük paralellik ve ölçüm şart.
- VMConnect doğru hosta bağlandı. Ubuntu Server Minimal kurulum ekranı görüldü; Featured server snaps seçilmiyor ve OpenSSH Server kuruluyor.
- SSH henüz doğrulanmadı. LFS, rootfs, Plasma, tema, terminal profili ve uygulama testleri tamamlanmış sayılmıyor.

SSH bağlandıktan sonra Codex'in yapacağı sıra: Ubuntu/SSH/host doğrulaması; locale ve saat; LFS host gereksinimleri; resmi kaynak checksum'ı; ayrı LFS hedefi; toolchain ve multilib kapısı; temel sistem boot'u; BLFS masaüstü ve paketleme. Claude'ın ilk gerçek görevi, SSH/build durumu kaydedildikten sonra UI-01 ve SHELL-01 kapsamındaki tema token'ları, kısayollar, Konsole/Zsh profili ve uygulama UX taslaklarını ayrı dosyalarda hazırlamaktır.

Kurulum ekranına ulaşmak kurulumun bittiği anlamına gelmez. Claude erişmediği dosyaları okumuş, komutları çalıştırmış veya testleri geçmiş gibi raporlamaz; her teslim commit, doğrulama ve açık sorunlarla yazılır.

## Rol ve ilk görev

İş bölümü: Codex LFS/build/multilib/paket/ISO ve entegrasyon; Claude masaüstü teması, terminal UX, uygulama profilleri ve Windows geçiş deneyimi. Her iki ajan diğerinin kritik değişikliklerini inceleyebilir. İlk görevin ayrıntıları `docs/CLAUDE_START.md`, görev sırası `docs/BACKLOG.md` içindedir. İşe başlama kaydı olmadan görev yürütülüyor sayılmaz.

Bir görev üstlenildiğinde yalnız o görevin dosya sınırında çalış. Ortak kernel, paket manifesti, build sürümleri, rootfs veya mount işlemlerini koordinasyonsuz değiştirme.

## Claude için çalışma biçimi

- Claude Code kullanılıyorsa önce gerçek çalışma dizinini ve değişiklikleri kontrol et; buradaki `C:\alpbahOS` yolu başka hostta mevcutmuş gibi davranma.
- Sohbet üzerinden çalışılıyorsa erişmediğin dosyaları okumuş, komutları çalıştırmış veya testleri geçmiş sayma. Öneriyi patch/metin ve doğrulama adımlarıyla teslim et.
- Tasarım uygulamasında hazır KDE/Qt/GTK mekanizmalarını araştır; sırf mockup özel görünüyor diye yeni masaüstü kabuğu icat etme.
- Paket motorunun API'si netleşmeden mağaza işlem mantığı yazma. Önce entegrasyon sözleşmesini belirle.
- CLI önerisini kabul etmek ile komutu çalıştırmayı ayır. Bulut/LLM tabanlı terminal tahmini onaylanmış gereksinim değil.
- Liquid glass'ı sıradan saydamlık olarak sunma; deneysel prototip ve ölçüm gerekliliğini koru.
- Varsayılan masaüstü ve kilit ekranının Atatürk temalı olacağı kabul edildi. Boot ekranını ayrıca kesinleştirilmeden bu kapsama katma.

## Görev devri şablonu

```text
Görev ID / durum:
Çalışılan host ve branch/commit (varsa):
Değişen dosyalar:
Gerçekleştirilen davranış:
Çalıştırılan doğrulama ve sonuç:
Log / ekran görüntüsü / artifact:
Bilinen sorun ve açık karar:
Entegrasyon için gereken:
Sonraki eylem:
```

Son raporu Türkçe yaz. Yapılmamış testleri açıkça “çalıştırılmadı” olarak işaretle.
