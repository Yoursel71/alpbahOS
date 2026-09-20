# alpbahOS — Claude çalışma başlangıcı

Önce kökteki `AGENTS.md` dosyasını oku ve uygula. Ortak ürün ve çalışma kuralları oradadır; burada ikinci, çelişen bir kural seti oluşturma.

## Okuma sırası

1. `AGENTS.md`
2. `docs/DECISIONS.md`
3. `docs/MASTER_PLAN.md`
4. `docs/WORKLOG.md`
5. Görsel bir görev için `docs/alpbahOS-design-mockups.md` ve `docs/assets/alpbahOS-logo.png`

## Güncel bağlam

- Ana plan 1.0 hazır. Çalışır dağıtım veya tamamlanmış toolchain yok.
- LFS tabanı derlenecek, hazır açık kaynak masaüstü/uygulamalar özelleştirilecek.
- Kullanıcı Windows'tan geçenler için kolay masaüstü, terminal önerileri, basit paket işlemleri, Windows kısayolları, Atatürk görselleri ve güçlü cihazlarda cam görünümü istiyor.
- Başlangıç stack'i KDE/KWin, Konsole/Zsh, pacman/libalpm + pkg + Discover/PackageKit. Entegrasyon deneyi geçmeden çalışan kabul etme.
- Claude Code kullanılacak; ayrı çalışma ağacı `C:\alpbahOS-claude`, dal `claude/desktop-bootstrap`. Başka hostta clone ve aynı görev sözleşmeleri kullanılır.
- Hyper-V, 300 GB yerel alan, Türkçe Q, düşük RAM ve BIOS+UEFI hedefleri sabittir. Kullanıcı günde 1–2 saat ayırır.

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
